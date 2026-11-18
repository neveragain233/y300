"""运行：python3 -m unittest discover -s tool/tests。"""

from pathlib import Path
import json
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import build_apk as build


def write_gradle(root, application_id="com.adws.y300.fork"):
    path = root / build.GRADLE_FILE
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        "android {\n    defaultConfig {\n"
        f'        applicationId = "{application_id}"\n'
        "    }\n}\n",
        encoding="utf-8",
    )


class BuildApkTests(unittest.TestCase):
    def test_build_publishes_named_artifact_and_prunes_old(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            write_gradle(root)
            (root / "pubspec.yaml").write_text("version: 2.0.0+86\n", encoding="utf-8")
            output_dir = root / build.OUTPUT_DIR
            output_dir.mkdir(parents=True)
            old = output_dir / "y300-v1.9.0-android-arm64-v8a.apk"
            old.write_bytes(b"previous-good")

            def flutter_build(command, **kwargs):
                self.assertEqual(command[:8], [
                    "flutter", "build", "apk", "--release", "--no-pub",
                    "--target-platform", "android-arm64", "--build-name",
                ])
                self.assertEqual(command[8], "2.0.0")
                self.assertEqual(
                    command[9:], ["--build-number", "86", "-t", "lib/main.dart"],
                )
                self.assertTrue(old.exists())
                (output_dir / "app-release.apk").write_bytes(b"new-good")

            def verify(apk, tools, unused_root, expected):
                self.assertEqual(apk.read_bytes(), b"new-good")
                self.assertEqual(expected["certificateSha256"], "cert")
                return {**expected, "sha256": "hash", "sizeBytes": 8}, {}

            with patch.object(build, "android_tools", return_value=root), \
                    patch.object(build, "capture", return_value="head"), \
                    patch.object(build, "package_info", return_value=({"versionCode": 101}, "")), \
                    patch.object(build, "certificate_sha256", return_value="cert"), \
                    patch.object(build.subprocess, "run", side_effect=flutter_build), \
                    patch.object(build, "verify_apk", side_effect=verify), \
                    patch("builtins.print"):
                build.run(root)
            latest = json.loads((root / build.RECORD_DIR / "latest.json").read_text(encoding="utf-8"))
            kept = Path(latest["apk"])
            self.assertEqual(kept.name, "y300-v2.0.0-android-arm64-v8a.apk")
            self.assertEqual(kept.read_bytes(), b"new-good")
            self.assertEqual(list(output_dir.glob("*.apk")), [kept])
            metadata = json.loads(Path(latest["metadata"]).read_text(encoding="utf-8"))
            self.assertEqual(metadata["versionName"], "2.0.0")
            self.assertEqual(metadata["versionCode"], 86)
            self.assertEqual(metadata["applicationId"], "com.adws.y300.fork")
            self.assertEqual(metadata["buildMode"], "release")

    def test_failed_build_does_not_publish_or_prune(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            write_gradle(root)
            (root / "pubspec.yaml").write_text("version: 2.0.0+86\n", encoding="utf-8")
            with patch.object(build, "android_tools", return_value=root), \
                    patch.object(build, "capture", return_value="head"), \
                    patch.object(build.subprocess, "run", side_effect=subprocess.CalledProcessError(1, "flutter")), \
                    patch.object(build, "publish_apk") as publish, \
                    patch.object(build, "prune_apks") as prune, \
                    patch("builtins.print"):
                with self.assertRaises(subprocess.CalledProcessError):
                    build.run(root)
            publish.assert_not_called()
            prune.assert_not_called()
            self.assertFalse((root / build.RECORD_DIR / "latest.json").exists())

    def test_application_id_and_version_come_from_project_config(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            write_gradle(root, "com.example.app")
            (root / "pubspec.yaml").write_text("version: 3.1.4+207\n", encoding="utf-8")
            self.assertEqual(build.application_id(root), "com.example.app")
            self.assertEqual(build.android_version(root), ("3.1.4", 207))
            self.assertEqual(
                build.artifact_name("3.1.4"), "y300-v3.1.4-android-arm64-v8a.apk",
            )

    def test_local_properties_overrides_application_id(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            write_gradle(root)
            local = root / "android/local.properties"
            local.parent.mkdir(parents=True, exist_ok=True)
            local.write_text(
                "sdk.dir=/tmp/sdk\ny300.applicationId=com.adws.y300.personal\n",
                encoding="utf-8",
            )
            self.assertEqual(build.application_id(root), "com.adws.y300.personal")

    def test_cleanup_keeps_delivery_and_never_follows_directory_links(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder) / "repo"
            root.mkdir()
            output = root / build.OUTPUT_DIR
            output.mkdir(parents=True)
            keep = output / "y300-v2.0.0-android-arm64-v8a.apk"
            keep.write_bytes(b"latest")
            old = root / "build/preview.apk"
            old.write_bytes(b"preview")
            old.with_suffix(".apk.sha256").write_text("old", encoding="utf-8")
            old.with_suffix(".apk.idsig").write_bytes(b"signature")
            (root / "build/build.log").write_text("evidence", encoding="utf-8")
            outside = Path(folder) / "outside"
            outside.mkdir()
            external = outside / "external.apk"
            external.write_bytes(b"outside")
            (root / "build/linked-directory").symlink_to(outside, target_is_directory=True)
            removed = build.prune_apks(root, keep)
            self.assertEqual(len(removed), 1)
            self.assertEqual(keep.read_bytes(), b"latest")
            self.assertEqual(external.read_bytes(), b"outside")
            self.assertFalse(old.exists())
            self.assertFalse(old.with_suffix(".apk.sha256").exists())
            self.assertFalse(old.with_suffix(".apk.idsig").exists())
            self.assertTrue((root / "build/build.log").exists())

    def test_external_or_missing_keep_cannot_trigger_cleanup(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder) / "repo"
            root.mkdir()
            (root / "build").mkdir()
            old = root / "build/old.apk"
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
            output = root / "artifact.apk"
            output.write_bytes(b"previous-good")
            source = root / "app-release.apk"
            source.write_bytes(b"invalid-new")
            with patch.object(build, "verify_apk", side_effect=RuntimeError("bad signature")):
                with self.assertRaises(RuntimeError):
                    build.publish_apk(source, output, root, root, {})
            self.assertEqual(output.read_bytes(), b"previous-good")
            self.assertFalse(output.with_suffix(".apk.pending").exists())

    def test_publication_replaces_same_version_artifact(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            output = root / "artifact.apk"
            output.write_bytes(b"previous-good")
            source = root / "app-release.apk"
            source.write_bytes(b"new-good")
            with patch.object(build, "verify_apk", return_value=({"sha256": "hash"}, {})):
                info, unused = build.publish_apk(source, output, root, root, {})
            self.assertEqual(info["sha256"], "hash")
            self.assertEqual(output.read_bytes(), b"new-good")
            self.assertFalse(output.with_suffix(".apk.pending").exists())


if __name__ == "__main__":
    unittest.main()
