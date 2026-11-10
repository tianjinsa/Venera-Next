"""Install missing Linux build packages without updating APT on complete runners."""

from pathlib import Path
import re
import shutil
import subprocess

PACKAGES = Path(__file__).with_name("linux-build-packages.txt")


def packages(path=PACKAGES):
    names = [line.split("#", 1)[0].strip() for line in path.read_text().splitlines()]
    names = [name for name in names if name]
    if not all(re.fullmatch(r"[a-z0-9][a-z0-9+.-]+", name) for name in names):
        raise ValueError("Invalid APT package name")
    return names


def prepare(names):
    result = subprocess.run(
        ["dpkg-query", "-W", "-f=${binary:Package}\t${Status}\n", *names],
        text=True, capture_output=True,
    )
    if result.returncode not in (0, 1):
        raise RuntimeError("Cannot inspect installed APT packages")
    installed = {line.split("\t")[0].split(":")[0] for line in result.stdout.splitlines()
                 if line.rsplit("\t", 1)[-1].endswith(" ok installed")}
    # Hosted images also install some tools outside APT (for example CMake).
    tools = {"clang": "clang", "cmake": "cmake", "ninja-build": "ninja", "pkg-config": "pkg-config", "ccache": "ccache"}
    installed.update(name for name, executable in tools.items() if shutil.which(executable))
    missing = [name for name in names if name not in installed]
    if missing:
        options = ["-o", "Acquire::Retries=2", "-o", "Acquire::http::Timeout=20", "-o", "Acquire::https::Timeout=20"]
        subprocess.run(["sudo", "apt-get", *options, "update"], check=True)
        subprocess.run(["sudo", "apt-get", *options, "install", "-y", "--no-install-recommends", *missing], check=True)
    else:
        print("Linux build dependencies are already installed; skipping APT.")


if __name__ == "__main__":
    prepare(packages())
