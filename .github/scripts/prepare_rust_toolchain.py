import argparse
import os
import subprocess
from pathlib import Path


def prepare_toolchain(version: str, targets: list[str]) -> None:
    command = [
        "rustup",
        "toolchain",
        "install",
        version,
        "--profile",
        "minimal",
        "--component",
        "cargo",
    ]
    for target in targets:
        command.extend(["--target", target])

    # Install missing components in place. Failures must surface without
    # deleting the existing toolchain or resetting the runner environment.
    subprocess.run(command, check=True)
    for executable in ("cargo", "rustc"):
        subprocess.run(
            ["rustup", "run", version, executable, "--version"],
            check=True,
        )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", default="1.92.0")
    parser.add_argument("--target", action="append", default=[])
    args = parser.parse_args()
    prepare_toolchain(args.version, args.target)
    if github_env := os.environ.get("GITHUB_ENV"):
        # Select the prepared toolchain without auto-installing every platform
        # listed in the repository's rust-toolchain.toml on this runner.
        with Path(github_env).open("a", encoding="utf-8") as output:
            output.write(f"RUSTUP_TOOLCHAIN={args.version}\n")


if __name__ == "__main__":
    main()
