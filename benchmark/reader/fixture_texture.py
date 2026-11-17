"""Offline textured progressive JPEG for a real native decode workload.

No artificial read/decode sleeps. The older flat PNG can finish too quickly to
expose late look-ahead. Apply identically to both disposable exports BEFORE
building; a new content-addressed folder preserves existing benchmark data.
Requires Pillow only on the host, never as an application dependency.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import random

from PIL import Image, ImageDraw, __version__
from prepare import replace


def instrument(source, width=1303, height=1920):
    rng = random.Random(178)
    texture = Image.frombytes('L', (width, height), rng.randbytes(width * height))
    # Halftones and clean gutters give a reproducible, nontrivial decode.
    texture = texture.point([32 + (n // 32) * 28 for n in range(256)]).convert('RGB')
    draw = ImageDraw.Draw(texture)
    for y in range(0, height, 512):
        draw.rectangle((0, y, width - 1, y + 28), fill='white')
        draw.rectangle((0, y, 28, y + 511), fill='white')
        draw.rectangle((width - 29, y, width - 1, y + 511), fill='white')
        draw.rectangle((80, y + 80, 680, y + 220), fill='white', outline='black', width=5)
    output = io.BytesIO()
    texture.save(output, format='JPEG', quality=85, progressive=True, optimize=True)
    encoded = output.getvalue()
    digest = hashlib.sha256(encoded).hexdigest()
    asset = source / 'assets/reader_benchmark.jpg'
    asset.write_bytes(encoded)
    manifest = source / 'reader-benchmark-source.json'
    data = json.loads(manifest.read_text())
    previous = data.get('textureFixture')
    if not previous:
        replace(source / 'pubspec.yaml', 'assets/reader_benchmark.png', 'assets/reader_benchmark.jpg')
    main = source / 'lib/reader_benchmark.dart'
    if not previous:
        replace(main, 'assets/reader_benchmark.png', 'assets/reader_benchmark.jpg')
    folder = 'fixture-texture-' + digest[:12]
    old_folder = 'fixture-texture-' + previous['sha256'][:12] if previous else 'fixture-rgb-v1'
    if old_folder == folder:
        raise ValueError('This fixture is already installed')
    replace(main, old_folder, folder, count=2)
    # Stored files keep .png names; decoding deliberately uses the byte header,
    # as the production local provider does. No key/decoder implementation change.
    data.update(fixtureWidth=width, fixtureHeight=height)
    data['textureFixture'] = {
        'sha256': digest, 'encodedBytes': len(encoded), 'width': width, 'height': height,
        'format': 'progressive JPEG', 'seed': 178, 'pillow': __version__,
        'scriptSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'artificialDelayMs': 0,
    }
    manifest.write_text(json.dumps(data, indent=2))
    print('TEXTURE FIXTURE:', len(encoded), 'bytes;', digest)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--width', type=int, default=1303)
    parser.add_argument('--height', type=int, default=1920)
    args = parser.parse_args()
    if not 512 <= args.width <= 4096 or not 512 <= args.height <= 4096:
        parser.error('Fixture dimensions outside bounded test range')
    instrument(args.source, args.width, args.height)
