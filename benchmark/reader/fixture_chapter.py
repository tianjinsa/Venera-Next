"""Copy user-supplied offline pages byte-for-byte into an isolated export.

Original archive stays read-only. No names, metadata or original paths enter
the packaged index; only numbered original image bytes and a content digest.
Assets and generated source remain ignored local benchmark artifacts.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import zipfile

from prepare import replace


def natural_key(name):
    return tuple((0, int(p)) if p.isdigit() else (1, p.casefold())
                 for p in re.split(r'(\d+)', name))


def instrument(source, archive, exclude_cover=False):
    destination = source / 'assets/reader_chapter'
    if destination.exists():
        raise ValueError('Original chapter fixture already exists; preserve it')
    manifest = source / 'reader-benchmark-source.json'
    data = json.loads(manifest.read_text())
    image_types = {'.jpg', '.jpeg', '.png', '.webp', '.gif', '.avif'}
    with zipfile.ZipFile(archive) as chapter:
        pages = sorted((p for p in chapter.infolist() if not p.is_dir()
                        and PurePosixPath(p.filename).suffix.lower() in image_types
                        and '__MACOSX' not in p.filename
                        and not (exclude_cover and PurePosixPath(p.filename).stem.lower() == 'cover')),
                       key=lambda p: natural_key(p.filename))
        if not 80 <= len(pages) <= 1000:
            raise ValueError('Requires one bounded chapter with 80..1000 original pages')
        destination.mkdir()
        filenames, hashes = [], []
        for index, page in enumerate(pages, 1):
            image = chapter.read(page)
            name = f'{index:04}' + PurePosixPath(page.filename).suffix.lower()
            (destination / name).write_bytes(image)
            filenames.append(name)
            hashes.append(hashlib.sha256(image).hexdigest())
    digest = hashlib.sha256('\n'.join(hashes).encode()).hexdigest()
    (destination / 'index.json').write_text(json.dumps(filenames))
    asset = 'assets/reader_benchmark.jpg' if data.get('textureFixture') else 'assets/reader_benchmark.png'
    replace(source / 'pubspec.yaml', asset, 'assets/reader_chapter/')
    main = source / 'lib/reader_benchmark.dart'
    replace(main, "import 'dart:io';", "import 'dart:io';\nimport 'dart:convert';")
    text = main.read_text(encoding='utf-8')
    start = text.index('  final directory = await Directory(')
    end = text.index("  debugPrint('BENCH images ready');", start)
    folder = 'fixture-chapter-' + digest[:12]
    text = text[:start] + f'''  final directory = await Directory(
    '${{localRoot.path}}/{folder}/one',
  ).create(recursive: true);
  if (!await File('${{directory.path}}/.complete').exists()) {{
    final names = (jsonDecode(await rootBundle.loadString('assets/reader_chapter/index.json')) as List).cast<String>();
    for (final name in names) {{
      final asset = await rootBundle.load('assets/reader_chapter/$name');
      await File('${{directory.path}}/$name').writeAsBytes(
        asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes));
    }}
    await File('${{directory.path}}/.complete').writeAsString('{digest}');
  }}
''' + text[end:]
    old_folder = ('fixture-texture-' + data['textureFixture']['sha256'][:12]
                  if data.get('textureFixture') else 'fixture-rgb-v1')
    # Only the LocalComic directory remains after replacing the asset-copy block.
    if text.count(old_folder) != 1:
        raise ValueError('Expected a single comic directory anchor')
    main.write_text(text.replace(old_folder, folder), encoding='utf-8')
    data['originalChapterFixture'] = {
        'pages': len(filenames), 'orderedImageDigest': digest,
        'encodedBytes': sum((destination / name).stat().st_size for name in filenames),
        'byteForByte': True, 'artificialDelayMs': 0, 'excludeSeparateCover': exclude_cover,
        'scriptSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    }
    data['fixturePages'] = len(filenames)
    manifest.write_text(json.dumps(data, indent=2))
    print('ORIGINAL OFFLINE PAGES:', len(filenames), 'digest:', digest)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('archive', type=Path)
    parser.add_argument('--exclude-cover', action='store_true')
    args = parser.parse_args()
    instrument(args.source, args.archive, args.exclude_cover)
