"""Build independent Android flavors in one workspace, sharing native compilation."""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess

import android_tv_build as android
from prepare_rust_toolchain import prepare_toolchain


TARGETS = {"armeabi-v7a": ("android-arm", "armv7-linux-androideabi"),
           "arm64-v8a": ("android-arm64", "aarch64-linux-android"),
           "x86_64": ("android-x64", "x86_64-linux-android")}


def build_plan(flavors, architecture, environ):
    if flavors not in ("mobile", "tv", "both") or architecture not in ("arm64", "all"):
        raise ValueError("Unknown Android flavor or architecture selection")
    if environ.get("GITHUB_REF_TYPE") == "tag" or environ.get("GITHUB_REF", "").startswith("refs/tags/"):
        flavors, architecture = "both", "all"
    native_abis = list(TARGETS) if architecture == "all" else ["arm64-v8a"]
    return {"flavors": ["mobile", "tv"] if flavors == "both" else [flavors],
            "architecture": architecture, "native_abis": native_abis,
            "apks": [*native_abis, "universal"] if architecture == "all" else native_abis}


def build(plan, environ):
    pubspec = Path("pubspec.yaml").read_text(encoding="utf-8-sig")
    artifacts = Path("build/android-artifacts")
    if artifacts.exists():
        shutil.rmtree(artifacts)
    artifacts.mkdir(parents=True)
    env = dict(environ, ANDROID_BUILD_ABIS=",".join(plan["native_abis"]))
    for flavor in plan["flavors"]:
        metadata = android.build_metadata(flavor, pubspec, environ)
        profile = Path(f"build/android-{flavor}-profile.json")
        profile.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
        command = ["flutter", "build", "apk", "--release", "--flavor", flavor, "--no-pub",
                   "--target-platform", ",".join(TARGETS[abi][0] for abi in plan["native_abis"])]
        if flavor == "tv":
            command += [f"--dart-define=TV_BUILD={metadata['build_label']}",
                        f"--dart-define=TV_REVISION={metadata['revision']}"]
        subprocess.run(command, env=env, check=True)
        sdk = Path(environ.get("ANDROID_HOME", environ.get("ANDROID_SDK_ROOT", "")))
        verified = android.verify_apks(metadata, sdk, abis=plan["apks"])
        # Stage each verified flavor before Flutter starts the next build.
        for name in verified.values():
            source = Path(name)
            shutil.copy2(source, artifacts / source.name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("plan", "toolchain", "build"))
    args = parser.parse_args()
    plan = build_plan(os.environ.get("ANDROID_FLAVORS", "both"),
                      os.environ.get("ANDROID_ARCHITECTURE", "all"), os.environ)
    if args.command == "plan":
        android.write_outputs(os.environ.get("GITHUB_OUTPUT"), {"architecture": plan["architecture"]})
        print(json.dumps(plan, indent=2))
    elif args.command == "toolchain":
        prepare_toolchain("1.92.0", [TARGETS[abi][1] for abi in plan["native_abis"]])
    else:
        build(plan, os.environ)


if __name__ == "__main__":
    main()
