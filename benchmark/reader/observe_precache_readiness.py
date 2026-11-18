"""Add identical, lookup-only readiness probes to disposable Next sources.

Never resolves an image, changes a cache entry or modifies production sources.
Checks decoded/live status when display attaches and when navigation accepts a
page; these are readiness proxies, not proof of screen content or presentation.
"""
import argparse
import hashlib
import json
from pathlib import Path

from prepare import replace


def instrument_gallery(gallery):
    replace(gallery, '_activePage.value = page;', '''_activePage.value = page;
                if (!isChapterCommentsPage(page)) {
                  final range = getPageImagesRange(page);
                  final statuses = [for (var n = range.$1; n < range.$2; n++)
                    PaintingBinding.instance.imageCache.statusForKey(_imageProvider(data.images[n]))];
                  ReaderPerfProbe.event('selectionImageStatus', [page, statuses.length,
                    statuses.where((s) => s.keepAlive || (s.live && !s.pending)).length,
                    statuses.where((s) => s.pending).length]);
                }''')


def instrument(source):
    manifest = source / 'reader-benchmark-source.json'
    data = json.loads(manifest.read_text())
    if data['variant'] != 'next':
        raise ValueError('This Next experiment requires its display-relay path')
    if data.get('precacheReadinessProbe'):
        raise ValueError('Readiness probe already installed')
    instrument_gallery(source / 'lib/features/reader/gallery_view.dart')
    display = source / 'lib/features/reader/display_image_provider.dart'
    replace(display, "import 'dart:async';", "import 'dart:async';\nimport 'package:venera_next/foundation/reader_perf_probe.dart';")
    signature = 'Future<ReaderImageProvider> obtainKey(ImageConfiguration configuration) {'
    replace(display, signature, signature + '''
    final probeStatus = PaintingBinding.instance.imageCache.statusForKey(image);
    ReaderPerfProbe.event('displayResolveStatus', [image.hashCode,
      probeStatus.keepAlive, probeStatus.live, probeStatus.pending]);''')
    data['precacheReadinessProbe'] = {
        'observerSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'selectionColumns': ['page', 'images', 'ready', 'pending'],
        'displayColumns': ['sourceKeyHash', 'keepAlive', 'live', 'pending'],
        'meaning': 'Lookup-only cache status, not screen content; identical probes in both APKs',
    }
    manifest.write_text(json.dumps(data, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    args = parser.parse_args()
    instrument(args.source)
    print('Installed lookup-only precache readiness observers')


if __name__ == '__main__':
    main()
