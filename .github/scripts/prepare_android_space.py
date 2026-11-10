"""Free space on hosted Android runners only when the build needs it."""

import os
from pathlib import Path
import shutil
import subprocess


GIB = 1024 ** 3
CANDIDATES = ("/usr/share/dotnet", "/opt/ghc", "/usr/local/share/boost", "/opt/hostedtoolcache/CodeQL")


def prepare_space(required=20 * GIB, directory="."):
    free = shutil.disk_usage(directory).free
    print(f"Android build: {free / GIB:.1f} GiB free; target {required / GIB:.1f} GiB.")
    if free >= required:
        return
    if os.environ.get("RUNNER_ENVIRONMENT") == "github-hosted":
        for candidate in CANDIDATES:
            if Path(candidate).exists():
                subprocess.run(["sudo", "rm", "-rf", "--", candidate], check=True)
                free = shutil.disk_usage(directory).free
                if free >= required:
                    return
    raise RuntimeError(f"Android build needs {required / GIB:.0f} GiB free; {free / GIB:.1f} GiB available. Free space before retrying.")


if __name__ == "__main__":
    prepare_space()
