"""Seal actual instrumented inputs and APKs; source SHA alone is insufficient."""
import argparse
import difflib
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--repo', required=True, type=Path)
    parser.add_argument('--product-sha', help='An additional product revision applied to the baseline export')
    parser.add_argument('--product-patch', type=Path, help='Uncommitted product-only experiment patch applied on product-sha')
    parser.add_argument('--apk', action='append', type=Path, default=[])
    parser.add_argument('--out', required=True, type=Path)
    parser.add_argument('--flutter', type=Path, default=Path('D:/.tool/flutter-3.41.4/bin/flutter.bat'))
    args = parser.parse_args()
    manifest = json.loads((args.source / 'reader-benchmark-source.json').read_text(encoding='utf-8'))
    base = manifest['sourceSha']
    patch = []
    hashes = {}
    archive = subprocess.check_output(['git', '-C', str(args.repo), 'archive', '--format=tar', base])
    with tarfile.open(fileobj=io.BytesIO(archive)) as tree:
        for member in tree.getmembers():
            name = member.name
            path = args.source / name
            if not member.isfile() or not path.is_file() or path.suffix not in ('.dart', '.kt', '.gradle', '.properties', '.xml', '.yaml', '.lock'):
                continue
            original = tree.extractfile(member).read()
            actual = path.read_bytes()
            if original.replace(b'\r\n', b'\n') != actual.replace(b'\r\n', b'\n'):
                hashes[name] = sha256(path)
                patch.extend(difflib.unified_diff(original.decode('utf-8').splitlines(True), actual.decode('utf-8').splitlines(True), fromfile='a/' + name, tofile='b/' + name))
    assets = list((args.source / 'assets').glob('reader_benchmark.*'))
    for path in [args.source / 'lib/reader_benchmark.dart', args.source / 'lib/foundation/reader_perf_probe.dart'] + assets + list((args.source / 'android/app/src/main/kotlin').rglob('NativeReaderProbe.kt')):
        hashes[path.relative_to(args.source).as_posix()] = sha256(path)
    manifest['actualSourceOverridesSha256'] = hashes
    manifest['productRevision'] = args.product_sha or base
    if args.product_patch:
        manifest['productPatch'] = {'file': args.product_patch.name, 'sha256': sha256(args.product_patch)}
    manifest['buildDriverSha256'] = sha256(Path(__file__).with_name('build.ps1'))
    manifest['apks'] = [{'file': path.name, 'sha256': sha256(path), 'bytes': path.stat().st_size} for path in args.apk]
    manifest['flutter'] = json.loads(subprocess.check_output([str(args.flutter), '--version', '--machine'], text=True, encoding='utf-8'))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    args.out.with_suffix('.patch').write_text(''.join(patch), encoding='utf-8')
    print('Sealed', len(hashes), 'source overrides and', len(args.apk), 'APKs')


if __name__ == '__main__':
    main()
