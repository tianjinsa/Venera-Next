"""Select CI work conservatively from the complete PR/push diff."""

import json
import os
from pathlib import Path
import re
import subprocess


FLAGS = ("analyze", "python", "flutter", "apple", "rhttp_ios", "provider",
         "android", "windows", "linux", "macos", "ios")
DESKTOP = (
    {"platform": "Linux", "runner": "ubuntu-24.04", "target": "linux", "architecture": "x64"},
    {"platform": "macOS", "runner": "macos-15", "target": "macos", "architecture": "arm64"},
    {"platform": "iOS", "runner": "macos-15", "target": "ios", "architecture": "arm64"},
)
GLOBAL = {"pubspec.yaml", "pubspec.lock", "rust-toolchain.toml", "analysis_options.yaml"}


def classify(paths, platforms="all"):
    if platforms not in ("all", "android", "apple", "desktop"):
        raise ValueError("Unknown quality platforms")
    flags = dict.fromkeys(FLAGS, paths is None)
    for path in paths or ():
        parts = Path(path).parts
        if (path in GLOBAL or path.startswith((".github/workflows/", ".github/actions/"))
                or path == ".github/scripts/ci_scope.py"):
            flags.update(dict.fromkeys(FLAGS, True))
        elif (path.startswith(("doc/", "fastlane/", ".github/ISSUE_TEMPLATE/", ".github/data/"))
              or (len(parts) == 1 and (path.endswith(".md") or path in ("LICENSE", "sponsors.json")))):
            continue
        elif path.startswith(".github/scripts/"):
            flags["python"] = True
            if Path(path).name in ("prepare_rust_toolchain.py", "check_native_codec_bundle.py"):
                flags.update(dict.fromkeys(FLAGS, True))
            elif Path(path).name in ("build_android.py", "android_tv_build.py", "prepare_android_space.py"):
                flags["android"] = True
            elif Path(path).name == "prepare_apple_build.py":
                flags["macos"] = flags["ios"] = flags["rhttp_ios"] = True
            elif (Path(path).name in ("prepare_linux_build.py", "linux-build-packages.txt", "test_appimage.sh",
                                     "smoke_appimage.sh", "appimage-smoke.Dockerfile", "arch-builder.Dockerfile")
                  or Path(path).name.startswith(("appimage_", "build_linux_", "build_arch_"))):
                flags["linux"] = True
        elif path.startswith(("lib/", "assets/", "test/")):
            flags["analyze"] = flags["flutter"] = True
            if not path.startswith("test/"):
                flags["android"] = flags["windows"] = True
            if path.startswith(("lib/features/local_comics/", "lib/foundation/saf",
                                "lib/foundation/file_interaction", "lib/foundation/directory",
                                "test/foundation/saf", "test/features/local_comics/")):
                flags["provider"] = True
        elif path.startswith("packages/"):
            flags["analyze"] = flags["flutter"] = True
            native = parts[2] if len(parts) > 2 else ""
            if native in ("android", "windows", "linux", "macos", "ios"):
                flags[native] = True
            else:
                for target in ("android", "windows", "linux", "macos", "ios"):
                    flags[target] = True
            if path.startswith("packages/rhttp/"):
                flags["rhttp_ios"] = True
            if path.startswith("packages/venera_saf/"):
                flags["provider"] = True
        elif parts and parts[0] in ("android", "windows", "linux", "macos", "ios", "apple"):
            target = parts[0]
            flags["apple" if target == "apple" else target] = True
            if target == "apple":
                flags["macos"] = flags["ios"] = True
            if target == "android":
                flags["provider"] = True
            if target == "ios":
                flags["rhttp_ios"] = True
            if path.endswith(".py"):
                flags["python"] = True
        elif path == "release.json":
            flags["python"] = True
        else:
            # New or unclassified inputs must never silently remove coverage.
            flags.update(dict.fromkeys(FLAGS, True))
    if platforms in ("android", "desktop"):
        flags["apple"] = flags["rhttp_ios"] = False
    if platforms in ("apple", "desktop"):
        flags["provider"] = False
    return flags


def changed_paths(event_name, event, ref_type, git=None):
    if ref_type == "tag" or event_name not in ("pull_request", "push"):
        return None
    if event_name == "pull_request":
        pr = event.get("pull_request", {})
        base, head = pr.get("base", {}).get("sha", ""), pr.get("head", {}).get("sha", "")
    else:
        base, head = event.get("before", ""), event.get("after", "")
    if not all(isinstance(sha, str) and re.fullmatch(r"[0-9a-f]{40}", sha) and sha != "0" * 40 for sha in (base, head)):
        return None
    git = git or (lambda *args: subprocess.check_output(["git", *args], stderr=subprocess.PIPE))
    try:
        if event_name == "pull_request":
            base = git("merge-base", base, head).decode().strip()
        return git("diff", "--name-only", "--no-renames", "-z", base, head, "--").decode("utf-8").split("\0")[:-1]
    except (OSError, subprocess.CalledProcessError, UnicodeError):
        return None


def outputs(flags):
    values = {name: str(value).lower() for name, value in flags.items()}
    matrix = [item for item in DESKTOP if flags[item["target"]]]
    values["desktop"] = str(bool(matrix)).lower()
    values["desktop_matrix"] = json.dumps({"include": matrix}, separators=(",", ":"))
    return values


def main():
    try:
        event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text())
        paths = changed_paths(os.environ.get("GITHUB_EVENT_NAME"), event, os.environ.get("GITHUB_REF_TYPE"))
    except (KeyError, OSError, ValueError):
        paths = None
    values = outputs(classify(paths, os.environ.get("QUALITY_PLATFORMS", "all")))
    if destination := os.environ.get("GITHUB_OUTPUT"):
        with Path(destination).open("a", encoding="utf-8") as stream:
            for key, value in values.items():
                stream.write(f"{key}={value}\n")
    print(json.dumps({"diff": "full checks" if paths is None else paths, "scope": values}, indent=2))


if __name__ == "__main__":
    main()
