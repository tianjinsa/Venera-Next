"""Install only the Rust targets needed by the selected Apple products."""

import os
from prepare_rust_toolchain import prepare_toolchain


def selected_targets(macos, ios):
    if not (macos or ios):
        raise ValueError("No Apple product selected")
    targets = ["aarch64-apple-darwin", "x86_64-apple-darwin"] if macos else []
    if ios:
        targets.append("aarch64-apple-ios")
    return targets


def flag(name):
    value = os.environ.get(name, "false")
    if value not in ("true", "false"):
        raise ValueError(f"Invalid {name}")
    return value == "true"


if __name__ == "__main__":
    prepare_toolchain("1.92.0", selected_targets(flag("BUILD_MACOS"), flag("BUILD_IOS")))
