"""Expose the existing production diagnostics in an isolated Next fixture.

Only exported sources are edited. Start/stop stays outside the measured ROI;
the production collector and scroll phase classifier themselves are unchanged.
"""
import argparse
import hashlib
import json
from pathlib import Path

from prepare import replace


def instrument(source):
    manifest = source / 'reader-benchmark-source.json'
    data = json.loads(manifest.read_text())
    if data['variant'] != 'next' or data.get('productionDiagnosticsCommands'):
        raise ValueError('Requires a Next export without these commands')
    main = source / 'lib/reader_benchmark.dart'
    replace(main, "import 'dart:io';", "import 'dart:io';\nimport 'package:venera_next/foundation/reader_diagnostics.dart';")
    replace(main, "'pageCount': key.currentState?.maxPage,", """'pageCount': key.currentState?.maxPage,
      'productionDiagnosticsRecording': key.currentState?.readerDiagnostics.isRecording,""")
    replace(main, "} else if (command == 'pressure') {", """} else if (command == 'diagnostic-start') {
        key.currentState!.readerDiagnostics.start(
          mode: ReaderDiagnosticMode.paged, processingEnabled: false,
          appVersion: '0.0.0',
          refreshRate: View.of(key.currentContext!).display.refreshRate,
        );
      } else if (command == 'diagnostic-stop') {
        final diagnostics = key.currentState!.readerDiagnostics;
        diagnostics.stop(ReaderDiagnosticStop.review);
        await File('${App.externalStoragePath!}/reader-bench/production-diagnostics.json')
          .writeAsString(diagnostics.exportJson());
      } else if (command == 'pressure') {""")
    data['productionDiagnosticsCommands'] = {
        'observerSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'collector': 'Unmodified ReaderDiagnostics in the real Reader; explicit opt-in per capture',
    }
    manifest.write_text(json.dumps(data, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    instrument(parser.parse_args().source)
    print('Exposed the production diagnostics collector in the isolated Next reader')
