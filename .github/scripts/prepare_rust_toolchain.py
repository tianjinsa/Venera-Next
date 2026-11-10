import argparse
import subprocess


def prepare_toolchain(version: str, targets: list[str]) -> None:
    available = subprocess.run(
        ["rustup", "run", version, "cargo", "--version"],
        capture_output=True, text=True,
    )
    if available.returncode != 0:
        subprocess.run(
            ["rustup", "toolchain", "install", version, "--profile", "minimal", "--component", "cargo"],
            check=True,
        )
    installed = set(subprocess.check_output(
        ["rustup", "target", "list", "--installed", "--toolchain", version], text=True,
    ).split())
    missing = sorted(set(targets) - installed)
    if missing:
        subprocess.run(["rustup", "target", "add", "--toolchain", version, *missing], check=True)
    subprocess.run(
        ["rustup", "run", version, "cargo", "--version"],
        check=True,
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", default="1.92.0")
    parser.add_argument("--target", action="append", default=[])
    args = parser.parse_args()
    prepare_toolchain(args.version, args.target)


if __name__ == "__main__":
    main()
