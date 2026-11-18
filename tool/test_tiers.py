#!/usr/bin/env python3
"""Select and run the repository test tiers declared in ``test_tiers.json``.

The default gate is the ``fast`` tier.  ``ui`` holds page-flow tests,
``perf`` and ``visual`` hold tests that only run on demand.  The manifest
uses ordered glob rules plus exact-path overrides so an existing suite can be
classified without annotating hundreds of Dart files.

Commands::

    python3 tool/test_tiers.py fast
    python3 tool/test_tiers.py ui --feature novel
    python3 tool/test_tiers.py all --shard 2/4
    python3 tool/test_tiers.py packages
    python3 tool/test_tiers.py list fast
    python3 tool/test_tiers.py check
    python3 tool/test_tiers.py report .test-timings/fast.json

The timing report follows the ``dart test`` JSON reporter protocol and is
written next to the raw report as ``<name>-summary.json`` unless overridden.
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Dict, Iterable, List, Mapping, Optional, Sequence, Tuple

REPO_ROOT = Path(__file__).resolve().parent.parent
MANIFEST_PATH = REPO_ROOT / "tool" / "test_tiers.json"
TESTS_ROOT = REPO_ROOT / "test"

TIERS = ("fast", "ui", "perf", "visual")
ALL_TIER = "all"


class ManifestError(RuntimeError):
    """Raised when the manifest and the test tree disagree."""


def _relative(path: Path) -> str:
    """Format a path relative to the repository when it lives inside it."""

    resolved = path.resolve()
    root = REPO_ROOT.resolve()
    try:
        return resolved.relative_to(root).as_posix()
    except ValueError:
        return resolved.as_posix()


def load_manifest(path: Path = MANIFEST_PATH) -> Dict[str, object]:
    with path.open(encoding="utf-8") as handle:
        manifest = json.load(handle)
    if not isinstance(manifest, dict):
        raise ManifestError(f"{_relative(path)} must contain a JSON object")
    return manifest


def discover_test_files() -> List[str]:
    if not TESTS_ROOT.is_dir():
        raise ManifestError(f"missing test directory: {_relative(TESTS_ROOT)}")
    return sorted(
        _relative(path)
        for path in TESTS_ROOT.rglob("*_test.dart")
        if path.is_file()
    )


def _manifest_rules(manifest: Mapping[str, object]) -> List[Tuple[str, List[str]]]:
    rules = manifest.get("rules")
    if not isinstance(rules, list):
        raise ManifestError("manifest.rules must be a list")
    parsed: List[Tuple[str, List[str]]] = []
    for index, rule in enumerate(rules):
        if not isinstance(rule, dict):
            raise ManifestError(f"manifest.rules[{index}] must be an object")
        tier = rule.get("tier")
        patterns = rule.get("patterns")
        if tier not in TIERS:
            raise ManifestError(
                f"manifest.rules[{index}].tier must be one of {', '.join(TIERS)}"
            )
        if not isinstance(patterns, list) or not patterns:
            raise ManifestError(
                f"manifest.rules[{index}].patterns must be a non-empty list"
            )
        if not all(isinstance(pattern, str) for pattern in patterns):
            raise ManifestError(
                f"manifest.rules[{index}].patterns must contain strings"
            )
        parsed.append((str(tier), list(patterns)))
    return parsed


def _manifest_overrides(manifest: Mapping[str, object]) -> Dict[str, str]:
    overrides = manifest.get("overrides", {})
    if not isinstance(overrides, dict):
        raise ManifestError("manifest.overrides must be an object")
    result: Dict[str, str] = {}
    for path, tier in overrides.items():
        if tier not in TIERS:
            raise ManifestError(
                f"manifest.overrides[{path!r}] must be one of {', '.join(TIERS)}"
            )
        result[str(path)] = str(tier)
    return result


def _matches(path: str, pattern: str) -> bool:
    # fnmatch's ``*`` also crosses ``/``; the manifest only ever holds POSIX
    # repository-relative paths, so no platform conversion is involved.
    return fnmatch.fnmatchcase(path, pattern)


def classify(manifest: Mapping[str, object]) -> Dict[str, str]:
    """Return an exact path -> tier mapping, failing on manifest drift."""

    files = discover_test_files()
    if not files:
        raise ManifestError("no *_test.dart files found under test/")

    default_tier = manifest.get("defaultTier")
    if default_tier not in TIERS:
        raise ManifestError(
            f"manifest.defaultTier must be one of {', '.join(TIERS)}"
        )

    rules = _manifest_rules(manifest)
    overrides = _manifest_overrides(manifest)

    unmatched_patterns: List[str] = []
    for _tier, patterns in rules:
        for pattern in patterns:
            if not any(_matches(path, pattern) for path in files):
                unmatched_patterns.append(pattern)

    result: Dict[str, str] = {}
    for path in files:
        tier = str(default_tier)
        for rule_tier, patterns in rules:
            if any(_matches(path, pattern) for pattern in patterns):
                tier = rule_tier
                break
        if path in overrides:
            tier = overrides[path]
        result[path] = tier

    missing_overrides = sorted(path for path in overrides if path not in result)
    problems: List[str] = []
    if unmatched_patterns:
        problems.append(
            "manifest rules match no test file:\n  "
            + "\n  ".join(sorted(set(unmatched_patterns)))
        )
    if missing_overrides:
        problems.append(
            "manifest overrides point at missing test files:\n  "
            + "\n  ".join(missing_overrides)
        )
    if problems:
        raise ManifestError("\n".join(problems))
    return result


def tier_files(classification: Mapping[str, str], tier: str) -> List[str]:
    if tier == ALL_TIER:
        return sorted(classification)
    if tier not in TIERS:
        raise ManifestError(f"unknown tier {tier!r}; choose one of {', '.join(TIERS)}")
    return sorted(path for path, value in classification.items() if value == tier)


def filter_feature(files: Sequence[str], feature: Optional[str]) -> List[str]:
    if not feature:
        return list(files)
    feature_dir = REPO_ROOT / "test" / "features" / feature
    if not feature_dir.is_dir():
        raise ManifestError(f"unknown feature {feature!r}: {_relative(feature_dir)}")
    prefix = f"test/features/{feature}/"
    selected = [path for path in files if path.startswith(prefix)]
    if not selected:
        raise ManifestError(
            f"no tests in the selected tier belong to feature {feature!r}"
        )
    return selected


_line_count_cache: Dict[str, int] = {}


_PART_DIRECTIVE = re.compile(r"^part '([^']+)';\s*$")
_MAIN_START = re.compile(r"^(?:void\s+)?(?:Future<[^>]+>\s+)?main\s*\(")


def line_count(path: str) -> int:
    """Return the compile size of a test library, including its part files.

    A split test keeps its `part` files next to the parent.  Counting only the
    parent would make shard balancing treat a 10k-line library as a 100-line
    file, so every `part` directive adds the size of its sibling file.
    """

    cached = _line_count_cache.get(path)
    if cached is not None:
        return cached
    full_path = REPO_ROOT / path
    count = 0
    part_paths: List[Path] = []
    in_header = True
    with full_path.open(encoding="utf-8") as handle:
        for line in handle:
            count += 1
            stripped = line.rstrip("\n")
            if in_header and _MAIN_START.match(stripped):
                in_header = False
            match = _PART_DIRECTIVE.match(stripped)
            if in_header and match:
                part_paths.append(full_path.parent / match.group(1))
    for part_path in part_paths:
        if not part_path.is_file():
            raise ManifestError(
                f"{path} declares a missing part: {_relative(part_path)}"
            )
        with part_path.open(encoding="utf-8") as handle:
            count += sum(1 for _line in handle)
    _line_count_cache[path] = count
    return count


def shard_files(files: Sequence[str], shard: str) -> List[str]:
    """Split files into deterministic, line-balanced shards.

    ``shard`` is ``"<1-based index>/<total>"``.  Longest-processing-time
    assignment keeps page-heavy files from piling into the same shard without
    requiring historical timings.
    """

    try:
        index_text, total_text = shard.split("/", 1)
        index = int(index_text)
        total = int(total_text)
    except (ValueError, AttributeError) as error:
        raise ValueError("--shard must look like 2/4") from error
    if total < 1 or index < 1 or index > total:
        raise ValueError("--shard index must satisfy 1 <= index <= total")

    buckets: List[List[str]] = [[] for _ in range(total)]
    weights = [0] * total
    for path in sorted(files, key=lambda item: (-line_count(item), item)):
        target = min(range(total), key=lambda position: weights[position])
        buckets[target].append(path)
        weights[target] += line_count(path)
    return sorted(buckets[index - 1])


def _require_tool(name: str, package: Optional[str] = None) -> None:
    if shutil.which(name):
        return
    hint = f" (working directory {package})" if package else ""
    raise ManifestError(
        f"the {name} executable is not on PATH{hint}; install Flutter or fix PATH"
    )


def _timing_path(timings: str) -> Path:
    path = Path(timings)
    if not path.is_absolute():
        path = REPO_ROOT / path
    return path


def build_flutter_command(
    files: Sequence[str],
    timings: Optional[Path],
    concurrency: Optional[int],
) -> List[str]:
    command = ["flutter", "test", "--no-pub"]
    if concurrency:
        command.extend(["--concurrency", str(concurrency)])
    if timings:
        command.extend(["--file-reporter", f"json:{timings}"])
    command.extend(files)
    return command


def _format_command(command: Sequence[str]) -> str:
    return " ".join(command)


def run_flutter_tests(
    files: Sequence[str],
    timings: Optional[str],
    concurrency: Optional[int],
    dry_run: bool,
    min_test_seconds: float = 2.0,
) -> int:
    if not files:
        print("No tests selected.", file=sys.stderr)
        return 0
    timing_path = _timing_path(timings) if timings else None
    if timing_path:
        timing_path.parent.mkdir(parents=True, exist_ok=True)
    command = build_flutter_command(files, timing_path, concurrency)
    print(f"Running {len(files)} test files from the selected tier.")
    if dry_run or len(files) <= 20:
        print(_format_command(command), flush=True)
    else:
        print(
            f"flutter test --no-pub <{len(files)} files>; "
            "use the list command to print them.",
            flush=True,
        )
    if dry_run:
        return 0
    _require_tool("flutter")
    completed = subprocess.run(command, cwd=REPO_ROOT)
    if timing_path:
        if timing_path.is_file():
            summary = build_timing_summary(
                timing_path, min_test_seconds=min_test_seconds
            )
            write_timing_summary(summary, timing_path)
            print_timing_summary(summary, min_test_seconds=min_test_seconds)
        else:
            print(
                f"warning: Flutter did not write the timing report {timing_path}",
                file=sys.stderr,
            )
    return completed.returncode


def _manifest_packages(manifest: Mapping[str, object]) -> List[Dict[str, str]]:
    packages = manifest.get("packages", [])
    if not isinstance(packages, list):
        raise ManifestError("manifest.packages must be a list")
    parsed: List[Dict[str, str]] = []
    for index, package in enumerate(packages):
        if not isinstance(package, dict):
            raise ManifestError(f"manifest.packages[{index}] must be an object")
        path = package.get("path")
        runner = package.get("runner", "dart")
        if not isinstance(path, str) or not path:
            raise ManifestError(f"manifest.packages[{index}].path is required")
        if runner not in ("dart", "flutter"):
            raise ManifestError(
                f"manifest.packages[{index}].runner must be dart or flutter"
            )
        if not (REPO_ROOT / path / "test").is_dir():
            raise ManifestError(
                f"manifest.packages[{index}] has no test directory: {path}/test"
            )
        parsed.append({"path": path, "runner": str(runner)})
    return parsed


def run_packages(manifest: Mapping[str, object], dry_run: bool) -> int:
    packages = _manifest_packages(manifest)
    if not packages:
        print("No package suites configured.", file=sys.stderr)
        return 0
    failures: List[str] = []
    for package in packages:
        path = package["path"]
        command = (
            ["dart", "test"]
            if package["runner"] == "dart"
            else ["flutter", "test", "--no-pub"]
        )
        print(f"\n==> {path}: {_format_command(command)}", flush=True)
        if dry_run:
            continue
        _require_tool(command[0], path)
        completed = subprocess.run(command, cwd=REPO_ROOT / path)
        if completed.returncode != 0:
            failures.append(path)
    if failures:
        print(
            "\nPackage suites failed:\n  " + "\n  ".join(failures),
            file=sys.stderr,
        )
        return 1
    return 0


def _read_events(path: Path) -> Iterable[Mapping[str, object]]:
    with path.open(encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line:
                continue
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(event, dict):
                yield event


def build_timing_summary(
    path: Path, min_test_seconds: float = 2.0
) -> Dict[str, object]:
    """Summarize a ``dart test`` JSON report by file and by slow test."""

    suite_paths: Dict[int, str] = {}
    test_info: Dict[int, Dict[str, object]] = {}
    test_done: Dict[int, Dict[str, object]] = {}
    errors: Dict[int, List[str]] = {}
    total_events_time = 0

    for event in _read_events(path):
        event_type = event.get("type")
        if isinstance(event.get("time"), (int, float)):
            total_events_time = max(total_events_time, int(event["time"]))
        if event_type == "suite":
            suite = event.get("suite")
            if isinstance(suite, dict) and isinstance(suite.get("id"), int):
                suite_paths[int(suite["id"])] = _relative(
                    Path(str(suite.get("path", "")))
                )
        elif event_type == "testStart":
            test = event.get("test")
            if isinstance(test, dict) and isinstance(test.get("id"), int):
                test_info[int(test["id"])] = {
                    "name": str(test.get("name", "")),
                    "suiteId": test.get("suiteID"),
                    "start": int(event.get("time", 0)),
                }
        elif event_type == "testDone":
            test_id = event.get("testID")
            if isinstance(test_id, int):
                test_done[test_id] = {
                    "done": int(event.get("time", 0)),
                    "result": str(event.get("result", "")),
                    "hidden": bool(event.get("hidden", False)),
                    "skipped": bool(event.get("skipped", False)),
                }
        elif event_type == "error":
            test_id = event.get("testID")
            if isinstance(test_id, int) and event.get("isFailure", True):
                message = str(event.get("error", "")).strip()
                if message:
                    errors.setdefault(test_id, []).append(message)

    files: Dict[str, Dict[str, object]] = {}
    slow_tests: List[Dict[str, object]] = []
    failures: List[Dict[str, object]] = []
    test_count = 0
    skipped_count = 0

    for test_id, info in test_info.items():
        done = test_done.get(test_id)
        if done is None:
            continue
        suite_id = info["suiteId"]
        suite_path = suite_paths.get(suite_id) if isinstance(suite_id, int) else None
        if suite_path is None:
            continue
        elapsed_ms = max(0, int(done["done"]) - int(info["start"]))
        name = str(info["name"])
        if bool(done["hidden"]):
            continue
        test_count += 1
        if bool(done["skipped"]):
            skipped_count += 1
            continue
        file_entry = files.setdefault(
            suite_path,
            {"path": suite_path, "tests": 0, "elapsedMs": 0, "failures": 0},
        )
        file_entry["tests"] = int(file_entry["tests"]) + 1
        file_entry["elapsedMs"] = int(file_entry["elapsedMs"]) + elapsed_ms
        if elapsed_ms / 1000.0 >= min_test_seconds:
            slow_tests.append(
                {"path": suite_path, "name": name, "elapsedMs": elapsed_ms}
            )
        if str(done["result"]) != "success":
            file_entry["failures"] = int(file_entry["failures"]) + 1
            failures.append(
                {
                    "path": suite_path,
                    "name": name,
                    "result": str(done["result"]),
                    "message": "\n".join(errors.get(test_id, [])),
                }
            )

    slow_files = sorted(
        files.values(), key=lambda item: int(item["elapsedMs"]), reverse=True
    )
    slow_tests.sort(key=lambda item: int(item["elapsedMs"]), reverse=True)
    return {
        "schema": 1,
        "source": _relative(path),
        "totalElapsedMs": total_events_time,
        "files": slow_files,
        "slowTests": slow_tests,
        "failures": failures,
        "testCount": test_count,
        "skippedCount": skipped_count,
        "failureCount": len(failures),
    }


def write_timing_summary(summary: Mapping[str, object], report_path: Path) -> Path:
    output = report_path.with_name(f"{report_path.stem}-summary.json")
    output.write_text(
        json.dumps(summary, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return output


def print_timing_summary(
    summary: Mapping[str, object],
    top_files: int = 20,
    min_test_seconds: float = 2.0,
) -> None:
    files = summary.get("files", [])
    failures = summary.get("failures", [])
    print(
        f"\nTiming: {summary.get('testCount', 0)} tests, "
        f"{len(files)} files, "
        f"{summary.get('failureCount', 0)} failures, "
        f"{int(summary.get('totalElapsedMs', 0)) / 1000.0:.1f}s wall clock"
    )
    if files:
        print(f"\nSlowest files (top {min(top_files, len(files))}):")
        for entry in files[:top_files]:
            print(
                f"  {int(entry['elapsedMs']) / 1000.0:8.2f}s  "
                f"{entry['tests']:4d} tests  {entry['path']}"
            )
    slow_tests = [
        test
        for test in summary.get("slowTests", [])
        if int(test["elapsedMs"]) / 1000.0 >= min_test_seconds
    ]
    if slow_tests:
        print(f"\nTests taking at least {min_test_seconds:g}s:")
        for test in slow_tests[:50]:
            print(
                f"  {int(test['elapsedMs']) / 1000.0:8.2f}s  "
                f"{test['path']}: {test['name']}"
            )
    if failures:
        print("\nFailures:")
        for failure in failures:
            print(f"  {failure['path']}: {failure['name']} ({failure['result']})")
    if files:
        over_budget = [entry for entry in files if int(entry["elapsedMs"]) > 60_000]
        if over_budget:
            print("\nFiles over 60s (split candidates):")
            for entry in over_budget:
                print(
                    f"  {int(entry['elapsedMs']) / 1000.0:8.2f}s  {entry['path']}"
                )


def report_command(args: argparse.Namespace) -> int:
    path = Path(args.report)
    if not path.is_file():
        raise ManifestError(f"timing report not found: {path}")
    summary = build_timing_summary(path, min_test_seconds=args.min_test_seconds)
    output = Path(args.output) if args.output else write_timing_summary(summary, path)
    print(f"Summary written to {_relative(output)}")
    print_timing_summary(
        summary,
        top_files=args.top_files,
        min_test_seconds=args.min_test_seconds,
    )
    return 1 if int(summary.get("failureCount", 0)) else 0


def check_command() -> int:
    manifest = load_manifest()
    classification = classify(manifest)
    counts = {tier: 0 for tier in TIERS}
    for tier in classification.values():
        counts[tier] += 1
    print(f"Manifest covers {len(classification)} test files:")
    for tier in TIERS:
        print(f"  {tier:6s} {counts[tier]:4d}")
    packages = _manifest_packages(manifest)
    print("Packages:")
    for package in packages:
        print(f"  {package['path']} ({package['runner']})")
    return 0


def list_command(args: argparse.Namespace) -> int:
    classification = classify(load_manifest())
    files = filter_feature(tier_files(classification, args.tier), args.feature)
    for path in files:
        print(path)
    print(f"# {len(files)} file(s)", file=sys.stderr)
    return 0


def run_command(args: argparse.Namespace) -> int:
    manifest = load_manifest()
    classification = classify(manifest)
    files = filter_feature(tier_files(classification, args.tier), args.feature)
    if args.shard:
        files = shard_files(files, args.shard)
    return run_flutter_tests(
        files,
        timings=args.timings,
        concurrency=args.concurrency,
        dry_run=args.dry_run,
    )


def _add_run_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "tier",
        choices=list(TIERS) + [ALL_TIER],
        help="test tier to run (all = fast + ui + perf + visual)",
    )
    parser.add_argument("--feature", help="limit to test/features/<feature>/")
    parser.add_argument(
        "--shard",
        help="run one deterministic, line-balanced shard, for example 2/4",
    )
    parser.add_argument(
        "--timings",
        help="write a dart test JSON timing report to this path",
    )
    parser.add_argument(
        "--concurrency",
        type=int,
        help="pass --concurrency through to flutter test",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="print the flutter command without running it",
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Run or inspect the repository test tiers.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    subparsers = parser.add_subparsers(dest="command")

    check_parser = subparsers.add_parser(
        "check", help="validate that the manifest covers every test file"
    )
    check_parser.set_defaults(handler=lambda _args: check_command())

    list_parser = subparsers.add_parser("list", help="print files in a tier")
    list_parser.add_argument("tier", choices=list(TIERS) + [ALL_TIER])
    list_parser.add_argument("--feature")
    list_parser.set_defaults(handler=list_command)

    report_parser = subparsers.add_parser(
        "report", help="summarize a dart test JSON timing report"
    )
    report_parser.add_argument("report")
    report_parser.add_argument("--output", help="summary JSON output path")
    report_parser.add_argument("--top-files", type=int, default=20)
    report_parser.add_argument(
        "--min-test-seconds", type=float, default=2.0, help="slow test threshold"
    )
    report_parser.set_defaults(handler=report_command)

    packages_parser = subparsers.add_parser(
        "packages", help="run every package suite listed in the manifest"
    )
    packages_parser.add_argument("--dry-run", action="store_true")
    packages_parser.set_defaults(
        handler=lambda args: run_packages(load_manifest(), args.dry_run)
    )

    run_parser = subparsers.add_parser("run", help="run a tier")
    _add_run_arguments(run_parser)
    run_parser.set_defaults(handler=run_command)
    return parser


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = build_parser()
    subcommands = {"check", "list", "report", "packages", "run"}
    # Short form: ``test_tiers.py fast`` is equivalent to ``run fast``.
    if argv and argv[0] not in subcommands and not argv[0].startswith("-"):
        args = parser.parse_args(["run", *argv])
    else:
        args = parser.parse_args(list(argv))
    if not hasattr(args, "handler"):
        parser.print_help(sys.stderr)
        raise SystemExit(2)
    return args


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = parse_args(list(sys.argv[1:] if argv is None else argv))
    try:
        return int(args.handler(args))
    except ManifestError as error:
        print(f"error: {error}", file=sys.stderr)
        return 2
    except ValueError as error:
        print(f"error: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
