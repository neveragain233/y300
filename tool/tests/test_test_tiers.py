import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import test_tiers


def _write(path: Path, content: str = "") -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


class TierManifestTest(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = Path(tempfile.mkdtemp()).resolve()
        self.addCleanup(lambda: __import__("shutil").rmtree(self.repo))
        self.tests_root = self.repo / "test"
        _write(self.tests_root / "features/novel/presentation/novel_page_test.dart")
        _write(self.tests_root / "features/novel/data/novel_repository_test.dart")
        _write(self.tests_root / "features/novel/data/novel_api_test.dart")
        self.patcher = mock.patch.multiple(
            test_tiers,
            REPO_ROOT=self.repo,
            TESTS_ROOT=self.tests_root,
            MANIFEST_PATH=self.repo / "tool/test_tiers.json",
        )
        self.patcher.start()
        self.addCleanup(self.patcher.stop)

    def _manifest(self, **overrides: object) -> dict:
        manifest = {
            "version": 1,
            "defaultTier": "fast",
            "rules": [
                {
                    "tier": "ui",
                    "patterns": [
                        "test/features/*/presentation/*_page_test.dart",
                    ],
                }
            ],
            "overrides": {},
            "packages": [],
        }
        manifest.update(overrides)
        return manifest

    def test_rule_and_override_select_exact_tier(self) -> None:
        manifest = self._manifest(
            overrides={
                "test/features/novel/data/novel_api_test.dart": "visual",
            }
        )
        classification = test_tiers.classify(manifest)

        self.assertEqual(
            classification["test/features/novel/presentation/novel_page_test.dart"],
            "ui",
        )
        self.assertEqual(
            classification["test/features/novel/data/novel_repository_test.dart"],
            "fast",
        )
        self.assertEqual(
            classification["test/features/novel/data/novel_api_test.dart"],
            "visual",
        )

    def test_rule_matching_no_file_is_drift(self) -> None:
        manifest = self._manifest(
            rules=[
                {
                    "tier": "perf",
                    "patterns": [
                        "test/features/novel/presentation/*performance_test.dart"
                    ],
                }
            ]
        )

        with self.assertRaises(test_tiers.ManifestError) as context:
            test_tiers.classify(manifest)
        self.assertIn("match no test file", str(context.exception))

    def test_override_for_missing_file_is_drift(self) -> None:
        manifest = self._manifest(
            overrides={"test/features/novel/data/deleted_test.dart": "fast"}
        )

        with self.assertRaises(test_tiers.ManifestError) as context:
            test_tiers.classify(manifest)
        self.assertIn("missing test files", str(context.exception))

    def test_feature_filter_rejects_unknown_feature(self) -> None:
        with self.assertRaises(test_tiers.ManifestError):
            test_tiers.filter_feature(
                ["test/features/novel/data/novel_api_test.dart"], "missing"
            )

    def test_feature_filter_uses_feature_directory(self) -> None:
        selected = test_tiers.filter_feature(
            [
                "test/features/novel/data/novel_api_test.dart",
                "test/core/network_test.dart",
            ],
            "novel",
        )

        self.assertEqual(
            selected, ["test/features/novel/data/novel_api_test.dart"]
        )


class ShardTest(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = Path(tempfile.mkdtemp()).resolve()
        self.addCleanup(lambda: __import__("shutil").rmtree(self.repo))
        self.files = {
            "big_test.dart": 100,
            "medium_test.dart": 50,
            "small_test.dart": 10,
            "tiny_test.dart": 5,
        }
        for name, lines in self.files.items():
            _write(self.repo / "test" / name, "line\n" * lines)
        self.patcher = mock.patch.multiple(
            test_tiers,
            REPO_ROOT=self.repo,
            _line_count_cache={},
        )
        self.patcher.start()
        self.addCleanup(self.patcher.stop)

    def _rel(self, name: str) -> str:
        return f"test/{name}"

    def test_shards_are_disjoint_and_complete(self) -> None:
        paths = [self._rel(name) for name in self.files]
        shards = [
            test_tiers.shard_files(paths, "1/3"),
            test_tiers.shard_files(paths, "2/3"),
            test_tiers.shard_files(paths, "3/3"),
        ]

        flattened = [path for shard in shards for path in shard]
        self.assertCountEqual(flattened, paths)
        self.assertEqual(len(flattened), len(set(flattened)))

    def test_heaviest_file_and_runner_up_are_split(self) -> None:
        paths = [self._rel(name) for name in self.files]
        first = test_tiers.shard_files(paths, "1/3")
        second = test_tiers.shard_files(paths, "2/3")
        third = test_tiers.shard_files(paths, "3/3")

        self.assertIn(self._rel("big_test.dart"), first)
        self.assertIn(self._rel("medium_test.dart"), second)
        self.assertNotIn(self._rel("big_test.dart"), second + third)

    def test_invalid_shard_is_rejected(self) -> None:
        paths = [self._rel(name) for name in self.files]
        for invalid in ("0/2", "3/2", "1", "x/2"):
            with self.subTest(shard=invalid):
                with self.assertRaises(ValueError):
                    test_tiers.shard_files(paths, invalid)


class LibraryWeightTest(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = Path(tempfile.mkdtemp()).resolve()
        self.addCleanup(lambda: __import__("shutil").rmtree(self.repo))
        self.patcher = mock.patch.multiple(
            test_tiers,
            REPO_ROOT=self.repo,
            _line_count_cache={},
        )
        self.patcher.start()
        self.addCleanup(self.patcher.stop)

    def test_part_files_count_toward_the_parent_library(self) -> None:
        _write(
            self.repo / "test/page_test.dart",
            "import 'package:flutter_test/flutter_test.dart';\n"
            "part 'page_cases.dart';\n"
            "void main() {}\n",
        )
        _write(
            self.repo / "test/page_cases.dart",
            "part of 'page_test.dart';\n" + "line\n" * 99,
        )

        self.assertEqual(test_tiers.line_count("test/page_test.dart"), 103)

    def test_part_like_text_after_main_is_ignored(self) -> None:
        _write(
            self.repo / "test/boundary_test.dart",
            "void main() {\n"
            "  const source = \'\'\'\n"
            "part \'test/host.dart\';\n"
            "\'\'\';\n"
            "}\n",
        )

        self.assertEqual(test_tiers.line_count("test/boundary_test.dart"), 5)


class TimingReportTest(unittest.TestCase):
    def _write_report(self, directory: Path) -> Path:
        report = directory / "timings.json"
        events = [
            {"type": "start", "time": 0},
            {
                "type": "suite",
                "suite": {"id": 0, "path": str(directory / "a_test.dart")},
                "time": 1,
            },
            {
                "type": "testStart",
                "test": {
                    "id": 1,
                    "name": "loading a_test.dart",
                    "suiteID": 0,
                },
                "time": 2,
            },
            {
                "type": "testDone",
                "testID": 1,
                "result": "success",
                "hidden": True,
                "skipped": False,
                "time": 1002,
            },
            {
                "type": "testStart",
                "test": {"id": 2, "name": "fast case", "suiteID": 0},
                "time": 1003,
            },
            {
                "type": "testDone",
                "testID": 2,
                "result": "success",
                "hidden": False,
                "skipped": False,
                "time": 1103,
            },
            {
                "type": "testStart",
                "test": {"id": 3, "name": "slow failure", "suiteID": 0},
                "time": 1104,
            },
            {
                "type": "error",
                "testID": 3,
                "error": "boom",
                "isFailure": True,
                "time": 5000,
            },
            {
                "type": "testDone",
                "testID": 3,
                "result": "failure",
                "hidden": False,
                "skipped": False,
                "time": 5100,
            },
        ]
        report.write_text(
            "\n".join(json.dumps(event) for event in events) + "\n",
            encoding="utf-8",
        )
        return report

    def test_summary_uses_test_durations_and_collects_failures(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            report = self._write_report(Path(directory))
            summary = test_tiers.build_timing_summary(
                report, min_test_seconds=2.0
            )

        self.assertEqual(summary["testCount"], 2)
        self.assertEqual(summary["failureCount"], 1)
        self.assertEqual(summary["files"][0]["tests"], 2)
        self.assertEqual(summary["files"][0]["elapsedMs"], 100 + 3996)
        self.assertEqual([test["name"] for test in summary["slowTests"]], [
            "slow failure"
        ])
        self.assertEqual(summary["slowTests"][0]["elapsedMs"], 3996)
        self.assertIn("boom", summary["failures"][0]["message"])

    def test_short_test_is_not_reported_as_slow(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            report = self._write_report(Path(directory))
            summary = test_tiers.build_timing_summary(
                report, min_test_seconds=5.0
            )

        self.assertEqual(summary["slowTests"], [])


class FlutterCommandTest(unittest.TestCase):
    def test_timing_report_is_passed_as_file_reporter(self) -> None:
        command = test_tiers.build_flutter_command(
            ["test/a_test.dart"],
            Path("/tmp/report.json"),
            concurrency=2,
        )

        self.assertEqual(command[:3], ["flutter", "test", "--no-pub"])
        self.assertIn("--file-reporter", command)
        self.assertIn("json:/tmp/report.json", command)
        self.assertEqual(command[-1], "test/a_test.dart")


if __name__ == "__main__":
    unittest.main()
