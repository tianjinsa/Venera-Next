import argparse
import io
import re
import shutil
import subprocess
import tarfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PUBSPEC_PATH = ROOT / "pubspec.yaml"
BUILD_LINUX_DIR = ROOT / "build" / "linux"
BUNDLE_DIR = BUILD_LINUX_DIR / "x64" / "release" / "bundle"
APP_DIR = BUILD_LINUX_DIR / "app"
ARCH_DIR = BUILD_LINUX_DIR / "arch"


class ArchBuildError(RuntimeError):
    pass


def _clean_value(value: str) -> str:
    value = value.strip()
    if "#" in value:
        value = value.split("#", 1)[0].strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
        return value[1:-1]
    return value


def _top_level_value(text: str, key: str) -> str:
    match = re.search(rf"^{re.escape(key)}:\s*(?P<value>.+?)\s*$", text, re.MULTILINE)
    if not match:
        raise ArchBuildError(f"pubspec.yaml does not contain {key}")
    return _clean_value(match.group("value"))


def _flutter_to_arch_config(text: str) -> dict[str, object]:
    lines = text.splitlines()
    config: dict[str, object] = {}
    in_block = False
    current_list: str | None = None

    for line in lines:
        if not in_block:
            if line.strip() == "flutter_to_arch:":
                in_block = True
            continue

        if line.strip() and not line.startswith((" ", "\t")):
            break

        field = re.match(r"\s{2}([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$", line)
        if field:
            key = field.group(1)
            value = _clean_value(field.group(2))
            if value:
                config[key] = value
                current_list = None
            else:
                config[key] = []
                current_list = key
            continue

        item = re.match(r"\s{4}-\s*(.+?)\s*$", line)
        if item and current_list:
            values = config[current_list]
            if not isinstance(values, list):
                raise ArchBuildError(f"flutter_to_arch.{current_list} is not a list")
            values.append(_clean_value(item.group(1)))

    if not config:
        raise ArchBuildError("pubspec.yaml does not contain flutter_to_arch config")
    return config


def _required_string(config: dict[str, object], key: str) -> str:
    value = config.get(key)
    if not isinstance(value, str) or not value:
        raise ArchBuildError(f"flutter_to_arch.{key} is required")
    return value


def _required_list(config: dict[str, object], key: str) -> list[str]:
    value = config.get(key)
    if not isinstance(value, list) or not value or not all(isinstance(i, str) for i in value):
        raise ArchBuildError(f"flutter_to_arch.{key} must be a non-empty list")
    return value


def _arch_version(pubspec_version: str) -> tuple[str, str]:
    version, separator, build = pubspec_version.partition("+")
    if not separator:
        build = "1"
    return version.replace("-", "_"), build


def _desktop_file(
    display_name: str,
    description: str,
    package_name: str,
    categories: str,
    keywords: str,
) -> str:
    return f"""[Desktop Entry]
Name={display_name}
GenericName={display_name}
Comment={description}
Terminal=false
Type=Application
Categories={categories}
Exec=/usr/bin/{package_name}_pkg/{package_name}
Keywords={keywords}
Icon={package_name}
""".strip()


def _pkgbuild(
    package_name: str,
    description: str,
    version: str,
    build: str,
    url: str,
    depends: list[str],
) -> str:
    depends_value = " ".join(f"'{dependency}'" for dependency in depends)
    return f"""pkgname={package_name}
pkgver={version}
pkgrel={build}
pkgdesc="{description}"
arch=('x86_64')
source=("app.tar.gz")
md5sums=('SKIP')
options=('!strip' '!debug')
url="{url}"
depends=({depends_value})

package() {{
    cd "$srcdir"
    install -Dm755 app/{package_name} "$pkgdir/usr/bin/{package_name}_pkg/{package_name}"
    install -d "$pkgdir/usr/bin/{package_name}_pkg/lib"
    cp -r app/lib/* "$pkgdir/usr/bin/{package_name}_pkg/lib/"
    install -d "$pkgdir/usr/bin/{package_name}_pkg/data"
    cp -r app/data/* "$pkgdir/usr/bin/{package_name}_pkg/data/"
    install -Dm644 app/icon.png "$pkgdir/usr/share/icons/hicolor/64x64/apps/{package_name}.png"
    install -Dm644 app/app.desktop "$pkgdir/usr/share/applications/$pkgname.desktop"
    ln -s "/usr/bin/{package_name}_pkg/{package_name}" "$pkgdir/usr/bin/{package_name}"
}}
""".strip()


def _dockerfile(package_name: str, version: str, build: str, depends: list[str]) -> str:
    return (ROOT / ".github/scripts/arch-builder.Dockerfile").read_text(encoding="utf-8")


def _run(command: list[str], cwd: Path) -> None:
    print(f"+ {' '.join(command)}")
    subprocess.run(command, cwd=cwd, check=True)


def _is_arch_linux() -> bool:
    return Path("/etc/arch-release").exists() and shutil.which("makepkg") is not None


def _make_app_archive(package_name: str, icon_path: str, desktop_content: str) -> None:
    executable = BUNDLE_DIR / package_name
    if not executable.exists():
        available = ", ".join(path.name for path in sorted(BUNDLE_DIR.iterdir())) if BUNDLE_DIR.exists() else "none"
        raise ArchBuildError(
            f"Expected Linux executable {executable}, but it was not found. "
            f"Available bundle entries: {available}"
        )

    icon = ROOT / icon_path
    if not icon.exists():
        raise ArchBuildError(f"Icon file {icon} does not exist")

    archive = BUILD_LINUX_DIR / "app.tar.gz"
    if archive.exists():
        archive.unlink()
    with tarfile.open(archive, "w:gz", compresslevel=1, dereference=True) as tar:
        tar.add(BUNDLE_DIR, arcname="app",
                filter=lambda item: None if item.name in ("app/icon.png", "app/app.desktop") else item)
        tar.add(icon, arcname="app/icon.png")
        data = desktop_content.encode("utf-8")
        entry = tarfile.TarInfo("app/app.desktop")
        entry.mode, entry.size = 0o644, len(data)
        tar.addfile(entry, io.BytesIO(data))

    if ARCH_DIR.exists():
        shutil.rmtree(ARCH_DIR)
    ARCH_DIR.mkdir(parents=True)
    shutil.move(str(archive), ARCH_DIR / "app.tar.gz")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--docker-image", help="Use an already loaded packaging image instead of building one",
    )
    parser.add_argument(
        "--prepare-only",
        action="store_true",
        help="write Arch packaging inputs without running makepkg or Docker",
    )
    args = parser.parse_args()

    text = PUBSPEC_PATH.read_text(encoding="utf-8")
    config = _flutter_to_arch_config(text)
    package_name = _required_string(config, "name")
    description = _top_level_value(text, "description")
    version, build = _arch_version(_top_level_value(text, "version"))
    icon = _required_string(config, "icon")
    categories = _required_string(config, "categories")
    keywords = _required_string(config, "keywords")
    url = _required_string(config, "url")
    depends = _required_list(config, "depends")

    desktop_content = _desktop_file(
        display_name="VeneraNext",
        description=description,
        package_name=package_name,
        categories=categories,
        keywords=keywords,
    )
    _make_app_archive(package_name, icon, desktop_content)
    (ARCH_DIR / "PKGBUILD").write_text(
        _pkgbuild(package_name, description, version, build, url, depends),
        encoding="utf-8",
    )
    (ARCH_DIR / "Dockerfile").write_text(
        _dockerfile(package_name, version, build, depends),
        encoding="utf-8",
    )

    if args.prepare_only:
        print(f"Prepared build/linux/arch for {package_name}-{version}-{build}")
        return

    if _is_arch_linux():
        _run(["makepkg", "-s", "--noconfirm"], ARCH_DIR)
    else:
        image = args.docker_image or "archpkg-builder"
        if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._/:-]*", image):
            raise ArchBuildError("Invalid packaging image name")
        if not args.docker_image:
            _run(["docker", "build", "-t", image, "."], ARCH_DIR)
        mount = f"type=bind,source={ARCH_DIR.resolve()},target=/build"
        _run(["docker", "run", "--rm", "--mount", mount, image], ARCH_DIR)

    print(f"build/linux/arch/{package_name}-{version}-{build}-x86_64.pkg.tar.zst")


if __name__ == "__main__":
    try:
        main()
    except ArchBuildError as error:
        print(f"::error::{error}")
        raise SystemExit(1)
