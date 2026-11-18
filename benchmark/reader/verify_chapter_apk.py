"""Verify an isolated APK packages the user's original page bytes unchanged."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import zipfile

from fixture_chapter import natural_key


def verify(archive, apk):
    image_types = {'.jpg', '.jpeg', '.png', '.webp', '.gif', '.avif'}
    hashes = []
    with zipfile.ZipFile(archive) as original, zipfile.ZipFile(apk) as built:
        pages = sorted((p for p in original.infolist() if not p.is_dir()
                        and PurePosixPath(p.filename).suffix.lower() in image_types
                        and '__MACOSX' not in p.filename
                        and PurePosixPath(p.filename).stem.lower() != 'cover'),
                       key=lambda p: natural_key(p.filename))
        index = json.loads(built.read('assets/flutter_assets/assets/reader_chapter/index.json'))
        if len(pages) != len(index):
            raise ValueError('Original and packaged page counts differ')
        for page, name in zip(pages, index):
            content = original.read(page)
            packaged = built.read('assets/flutter_assets/assets/reader_chapter/' + name)
            if content != packaged:
                raise ValueError('Original image bytes changed')
            hashes.append(hashlib.sha256(content).hexdigest())
    return {
        'apk': apk.name, 'apkSha256': hashlib.sha256(apk.read_bytes()).hexdigest(),
        'pages': len(hashes), 'originalBytesMatch': True,
        'orderedImageDigest': hashlib.sha256('\n'.join(hashes).encode()).hexdigest(),
    }


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    parser.add_argument('apk', type=Path)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    result = verify(args.archive, args.apk)
    args.out.write_text(json.dumps(result, indent=2) + '\n')
    print('Original page bytes verified:', result['pages'], result['orderedImageDigest'])
