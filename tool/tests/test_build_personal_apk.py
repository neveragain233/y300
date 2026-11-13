"""运行：python3 -m unittest discover -s tool/tests。"""

from pathlib import Path
import json
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import build_personal_apk as build


class PersonalApkTests(unittest.TestCase):
    def test_build_runs_fixed_command_then_publishes_and_prunes(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "pubspec.yaml").write_text("version: 2.0.0+86\n", encoding="utf-8")
            output_dir = root / build.OUTPUT_DIR
            output_dir.mkdir(parents=True)
            old = output_dir / "app-debug-dev-11101758.apk"
            old.write_bytes(b"previous-good")
            pointer = root / ".local/agent-notes/local/personal/build-apk/latest.json"
            pointer.parent.mkdir(parents=True)
            pointer.write_text('{"previous": true}', encoding="utf-8")

            def git_output(command, unused_root):
                return "local/personal" if command[1] == "branch" else "head"

            def flutter_build(command, **kwargs):
                self.assertEqual(command[:8], [
                    "flutter", "build", "apk", "--release", "--no-pub",
                    "--target-platform", "android-arm64", "--build-name",
                ])
                self.assertRegex(command[8], r"^v2\.0\.0-\d{8}dev$")
                self.assertEqual(command[9:], ["--build-number", "102", "-t", "lib/main.dart"])
                self.assertTrue(old.exists())
                self.assertEqual(json.loads(pointer.read_text(encoding="utf-8")), {"previous": True})
                (output_dir / "app-release.apk").write_bytes(b"new-good")

            def verify(apk, tools, unused_root, expected):
                self.assertEqual(apk.read_bytes(), b"new-good")
                self.assertTrue(old.exists())
                return {**expected, "sha256": "hash", "sizeBytes": 8}, {}

            with patch.object(build, "android_tools", return_value=root), \
                    patch.object(build, "capture", side_effect=git_output), \
                    patch.object(build, "package_info", return_value=({"versionCode": 101}, "")), \
                    patch.object(build.subprocess, "run", side_effect=flutter_build), \
                    patch.object(build, "verify_apk", side_effect=verify), \
                    patch("builtins.print"):
                build.run(root)
            latest = json.loads(pointer.read_text(encoding="utf-8"))
            kept = Path(latest["apk"])
            self.assertEqual(kept.read_bytes(), b"new-good")
            self.assertEqual(list(output_dir.glob("*.apk")), [kept])
            metadata = json.loads(Path(latest["metadata"]).read_text(encoding="utf-8"))
            self.assertEqual(metadata["versionCode"], 102)
            self.assertEqual(metadata["buildMode"], "release")

    def test_failed_build_does_not_publish_or_prune(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "pubspec.yaml").write_text("version: 2.0.0+86\n", encoding="utf-8")
            with patch.object(build, "android_tools", return_value=root), \
                    patch.object(build, "capture", return_value="local/personal"), \
                    patch.object(build.subprocess, "run", side_effect=subprocess.CalledProcessError(1, "flutter")), \
                    patch.object(build, "publish_apk") as publish, \
                    patch.object(build, "prune_apks") as prune, \
                    patch("builtins.print"):
                with self.assertRaises(subprocess.CalledProcessError):
                    build.run(root)
            publish.assert_not_called()
            prune.assert_not_called()
            self.assertFalse((root / ".local/agent-notes/local/personal/build-apk/latest.json").exists())

    def test_version_increases_past_current_artifact_and_failed_reservation(self):
        self.assertEqual(build.next_version_code(86, 0, [101]), 102)
        self.assertEqual(build.next_version_code(86, 102, [101]), 103)
        self.assertEqual(build.next_version_code(105, 102, []), 106)

    def test_cleanup_keeps_delivery_and_never_follows_directory_links(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder) / "repo"
            root.mkdir()
            keep = root / "latest.apk"
            keep.write_bytes(b"latest")
            old = root / ".local/preview.apk"
            old.parent.mkdir()
            old.write_bytes(b"preview")
            old.with_suffix(".apk.sha256").write_text("old", encoding="utf-8")
            old.with_suffix(".apk.idsig").write_bytes(b"signature")
            (root / ".local/build.log").write_text("evidence", encoding="utf-8")
            outside = Path(folder) / "outside"
            outside.mkdir()
            external = outside / "external.apk"
            external.write_bytes(b"outside")
            (root / "linked-directory").symlink_to(outside, target_is_directory=True)
            (root / "linked-file.apk").symlink_to(external)
            removed = build.prune_apks(root, keep)
            self.assertEqual(len(removed), 2)
            self.assertEqual(keep.read_bytes(), b"latest")
            self.assertEqual(external.read_bytes(), b"outside")
            self.assertFalse(old.exists())
            self.assertFalse(old.with_suffix(".apk.sha256").exists())
            self.assertFalse(old.with_suffix(".apk.idsig").exists())
            self.assertTrue((root / ".local/build.log").exists())

    def test_external_or_missing_keep_cannot_trigger_cleanup(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder) / "repo"
            root.mkdir()
            old = root / "old.apk"
            old.write_bytes(b"old")
            outside = Path(folder) / "external.apk"
            outside.write_bytes(b"outside")
            with self.assertRaises(RuntimeError):
                build.prune_apks(root, outside)
            with self.assertRaises(FileNotFoundError):
                build.prune_apks(root, root / "missing.apk")
            self.assertTrue(old.exists())

    def test_failed_verification_preserves_previous_delivery(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            old = root / "old.apk"
            old.write_bytes(b"previous-good")
            source = root / "app-release.apk"
            source.write_bytes(b"invalid-new")
            output = root / "new.apk"
            with patch.object(build, "verify_apk", side_effect=RuntimeError("bad signature")):
                with self.assertRaises(RuntimeError):
                    build.publish_apk(source, output, root, root, {})
            self.assertEqual(old.read_bytes(), b"previous-good")
            self.assertFalse(output.exists())
            self.assertFalse(output.with_suffix(".apk.pending").exists())

    def test_publication_refuses_to_overwrite_same_minute_delivery(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            output = root / "latest.apk"
            output.write_bytes(b"previous-good")
            with self.assertRaises(RuntimeError):
                build.publish_apk(root / "missing.apk", output, root, root, {})
            self.assertEqual(output.read_bytes(), b"previous-good")


if __name__ == "__main__":
    unittest.main()
