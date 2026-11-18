#!/usr/bin/env python3
"""构建并校验 Android arm64 安装包；用法见 tool/README.md。"""

import argparse
from contextlib import contextmanager
from datetime import datetime
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import zipfile
from zoneinfo import ZoneInfo


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = Path("build/app/outputs/flutter-apk")
RECORD_DIR = Path("build/apk-builds")
LOCK_FILE = Path("build/.apk-build.lock")
GRADLE_FILE = Path("android/app/build.gradle.kts")
ARTIFACT_GLOB = "y300-v*-android-arm64-v8a.apk"
BUILD_MODE = "release"
COMPANION_SUFFIXES = (".sha256", ".sha1", ".idsig")


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def capture(command, root):
    return subprocess.check_output(
        [str(part) for part in command], cwd=root, text=True,
        encoding="utf-8", stderr=subprocess.STDOUT,
    )


def write_json(path, value):
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(
        json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8",
    )
    temporary.replace(path)


@contextmanager
def build_lock(root):
    # 锁跨分支共享，防止两个任务同时改写 Gradle 产物或清理对方安装包。
    path = root / LOCK_FILE
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise RuntimeError("另一个安装包任务正在运行") from error
        yield


def android_tools(root):
    sdk = os.environ.get("ANDROID_SDK_ROOT") or os.environ.get("ANDROID_HOME")
    properties = root / "android/local.properties"
    if not sdk and properties.exists():
        match = re.search(r"^sdk\.dir=(.+)$", properties.read_text(encoding="utf-8"), re.M)
        if match:
            sdk = match.group(1).strip().replace("\\ ", " ")
    sdk_path = Path(sdk).expanduser() if sdk else Path.home() / "Library/Android/sdk"
    candidates = [
        path for path in (sdk_path / "build-tools").glob("*")
        if re.fullmatch(r"\d+(?:\.\d+)+", path.name)
        and all((path / name).is_file() for name in ("aapt", "apksigner", "zipalign"))
    ]
    require(candidates, f"未找到完整的安卓构建工具：{sdk_path}")
    return max(candidates, key=lambda path: tuple(map(int, path.name.split("."))))


def application_id(root):
    """应用标识以 Gradle 配置为唯一来源，脚本不再维护第二份常量。"""
    text = (root / GRADLE_FILE).read_text(encoding="utf-8")
    match = re.search(r'^\s*applicationId\s*=\s*"([^"]+)"\s*$', text, re.M)
    require(match, f"无法从 {GRADLE_FILE} 读取 applicationId")
    return match.group(1)


def android_version(root):
    """版本名与内部版本号以 pubspec.yaml 为唯一来源。"""
    text = (root / "pubspec.yaml").read_text(encoding="utf-8")
    match = re.search(r"^version:\s*([0-9][0-9A-Za-z.\-]*)\+(\d+)\s*$", text, re.M)
    require(match, "无法读取 pubspec.yaml 的版本名与内部版本号")
    return match.group(1), int(match.group(2))


def artifact_name(version_name):
    # 与安卓 Gradle 的 archivesName 保持同一命名，便于识别产物来源。
    return f"y300-v{version_name}-android-arm64-v8a.apk"


def package_info(apk, tools, root):
    badging = capture([tools / "aapt", "dump", "badging", apk], root)
    match = re.search(r"^package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'", badging, re.M)
    require(match, f"无法读取安装包身份：{apk}")
    return {
        "applicationId": match.group(1), "versionCode": int(match.group(2)),
        "versionName": match.group(3),
    }, badging


def delivery_apks(root):
    return sorted((root / OUTPUT_DIR).glob(ARTIFACT_GLOB))


def latest_apk(root, tools):
    candidates = delivery_apks(root)
    require(candidates, "没有可保留的安装包，请先运行构建")
    return max(candidates, key=lambda path: package_info(path, tools, root)[0]["versionCode"])


def certificate_sha256(apk, tools, root):
    signature = capture([tools / "apksigner", "verify", "--print-certs", apk], root)
    match = re.search(r"certificate SHA-256 digest: ([0-9a-f]{64})", signature)
    require(match, f"无法读取签名证书：{apk}")
    return match.group(1)


def verify_apk(apk, tools, root, expected=None):
    info, badging = package_info(apk, tools, root)
    require(info["applicationId"] == application_id(root), "应用标识与 Gradle 配置不一致")
    require("application-debuggable" not in badging, "发布包不能启用调试标志")
    for key, value in (expected or {}).items():
        if key in info:
            require(info[key] == value, f"安装包 {key} 与本次构建不一致")
    signature = capture([tools / "apksigner", "verify", "--print-certs", apk], root)
    certificate = re.search(r"certificate SHA-256 digest: ([0-9a-f]{64})", signature)
    require(certificate, "安装包没有可读取的签名证书")
    previous_certificate = (expected or {}).get("certificateSha256")
    if previous_certificate:
        require(
            certificate.group(1) == previous_certificate,
            "签名证书与已发布安装包不一致，覆盖升级会失败",
        )
    alignment = capture([tools / "zipalign", "-c", "-P", "16", "4", apk], root)
    segments = {}
    with zipfile.ZipFile(apk) as archive:
        names = archive.namelist()
        abis = sorted({name.split("/")[1] for name in names if name.startswith("lib/") and name.endswith(".so")})
        require(abis == ["arm64-v8a"], f"架构不符合约定：{abis}")
        require("assets/flutter_assets/kernel_blob.bin" not in names, "安装包包含调试内核")
        for name in names:
            if not name.startswith("lib/") or not name.endswith(".so"):
                continue
            data = archive.read(name)
            require(data[:6] == b"\x7fELF\x02\x01", f"原生库格式不符：{name}")
            offset = struct.unpack_from("<Q", data, 32)[0]
            size, count = struct.unpack_from("<HH", data, 54)
            values = [
                struct.unpack_from("<Q", data, offset + index * size + 48)[0]
                for index in range(count)
                if struct.unpack_from("<I", data, offset + index * size)[0] == 1
            ]
            require(values and min(values) >= 16384, f"原生库未按16KB对齐：{name}")
            segments[name] = values
    info.update({
        "debuggable": False, "abis": abis,
        "certificateSha256": certificate.group(1),
        "zipAlignment16KB": True, "nativeLoadAlignments": segments,
        "sizeBytes": apk.stat().st_size,
        "sha256": hashlib.sha256(apk.read_bytes()).hexdigest(),
    })
    return info, {"badging.txt": badging, "signature.txt": signature, "zipalign.txt": alignment}


def prune_apks(root, keep):
    """只清理本仓库 build/ 下的 APK，校验通过的交付包不在删除范围内。"""
    root = root.resolve()
    keep = keep.resolve(strict=True)
    require(keep.is_relative_to(root) and keep.suffix == ".apk" and keep.is_file(), "保留包必须位于当前仓库")
    removed = []
    # 不跟随目录链接，不进入 Git 对象库；清理范围只覆盖构建输出。
    for directory, directories, files in os.walk(root / "build", followlinks=False):
        directories[:] = [name for name in directories if name != ".git" and not (Path(directory) / name).is_symlink()]
        for name in files:
            path = Path(directory) / name
            if path.suffix != ".apk" or path.resolve() == keep:
                continue
            length = path.lstat().st_size
            path.unlink()
            for suffix in COMPANION_SUFFIXES:
                path.with_name(path.name + suffix).unlink(missing_ok=True)
            removed.append({"path": str(path.relative_to(root)), "sizeBytes": length})
    # Gradle 与 Flutter 会留下上一轮 APK 的校验和、签名伴随文件，这里一并清理。
    for directory, directories, files in os.walk(root / "build", followlinks=False):
        directories[:] = [name for name in directories if name != ".git" and not (Path(directory) / name).is_symlink()]
        for name in files:
            path = Path(directory) / name
            for suffix in COMPANION_SUFFIXES:
                if not name.endswith(".apk" + suffix):
                    continue
                base = path.with_name(name[: -len(suffix)])
                if base == keep or base.exists():
                    break
                path.unlink(missing_ok=True)
                break
    return removed


def publish_apk(source, output, tools, root, expected):
    """先在同一目录校验临时副本，通过后再替换同名交付包，失败保留旧包。"""
    temporary = output.with_suffix(".apk.pending")
    try:
        shutil.copyfile(source, temporary)
        info, evidence = verify_apk(temporary, tools, root, expected)
        temporary.replace(output)
        return info, evidence
    finally:
        temporary.unlink(missing_ok=True)


def previous_artifact(root, output):
    candidates = [path for path in delivery_apks(root) if path.resolve() != output.resolve()]
    return candidates


def run(root, keep_latest=False):
    tools = android_tools(root)
    version_name, version_code = android_version(root)
    app_id = application_id(root)
    state_dir = root / RECORD_DIR
    now = datetime.now(ZoneInfo("Asia/Shanghai"))
    record_dir = state_dir / now.strftime("%Y%m%d-%H%M%S-%f")
    record_dir.mkdir(parents=True)
    if keep_latest:
        output = latest_apk(root, tools)
        info, evidence = verify_apk(output, tools, root)
        metadata = {"verifiedAt": now.isoformat(), "action": "keep-latest"}
    else:
        output = root / OUTPUT_DIR / artifact_name(version_name)
        previous = previous_artifact(root, output)
        expected = {
            "applicationId": app_id, "versionCode": version_code,
            "versionName": version_name,
        }
        if previous:
            latest_previous = max(
                previous,
                key=lambda path: package_info(path, tools, root)[0]["versionCode"],
            )
            expected["certificateSha256"] = certificate_sha256(latest_previous, tools, root)
        metadata = {
            "startedAt": now.isoformat(), "versionName": version_name,
            "versionCode": version_code, "applicationId": app_id,
            "buildMode": BUILD_MODE, "entrypoint": "lib/main.dart",
            "gitHead": capture(["git", "rev-parse", "HEAD"], root).strip(),
            "includesUncommittedChanges": bool(capture(["git", "status", "--porcelain"], root).strip()),
        }
        command = [
            "flutter", "build", "apk", "--release", "--no-pub", "--target-platform", "android-arm64",
            "--build-name", version_name, "--build-number", str(version_code), "-t", "lib/main.dart",
        ]
        write_json(record_dir / "request.json", {**metadata, "command": command})
        print(f"正在构建 y300 {version_name}（{version_code}），日志：{record_dir / 'build.log'}", flush=True)
        with (record_dir / "build.log").open("w", encoding="utf-8") as log:
            subprocess.run(command, cwd=root, stdout=log, stderr=subprocess.STDOUT, check=True)
        info, evidence = publish_apk(root / OUTPUT_DIR / "app-release.apk", output, tools, root, expected)
    metadata.update(info)
    metadata["apk"] = str(output)
    for name, contents in evidence.items():
        (record_dir / name).write_text(contents, encoding="utf-8")
    output.with_suffix(".apk.sha256").write_text(f"{info['sha256']}  {output.name}\n", encoding="utf-8")
    write_json(record_dir / "metadata.json", metadata)
    # 只有校验通过的交付包才更新指针；清理失败可用 --keep-latest 重试。
    write_json(state_dir / "latest.json", {"apk": str(output), "metadata": str(record_dir / "metadata.json")})
    removed = prune_apks(root, output)
    write_json(record_dir / "cleanup.json", removed)
    print(f"保留：{output}\n版本：{info['versionName']}（{info['versionCode']}）\n已删除旧包和副本：{len(removed)} 个\n记录：{record_dir}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--keep-latest", action="store_true", help="校验已有最新安装包并清理其余 APK，不重新构建")
    args = parser.parse_args()
    try:
        with build_lock(ROOT):
            run(ROOT, args.keep_latest)
    except (OSError, RuntimeError, ValueError, subprocess.CalledProcessError, zipfile.BadZipFile) as error:
        print(f"安装包任务失败：{error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
