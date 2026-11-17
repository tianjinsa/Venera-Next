"""Observe actual frame requests/callbacks, without requesting any new frames.

Disposable exports only. The binding inherits the ordinary engine binding;
it does not pump frames, change scheduling or use a test binding.
"""
import argparse
import hashlib
import json
from pathlib import Path

from prepare import replace


def instrument(source):
    manifest = source / 'reader-benchmark-source.json'
    data = json.loads(manifest.read_text())
    if data.get('frameRequestProbe'):
        raise ValueError('Frame request probe already installed')
    main = source / 'lib/reader_benchmark.dart'
    replace(main, 'WidgetsFlutterBinding.ensureInitialized();', 'ReaderBenchmarkBinding();')
    replace(main, 'if (observedPager is PageController) {', '''if (observedPager is PageController) {
    ReaderBenchmarkBinding.pageState = () => observedPager.hasClients
      ? [observedPager.page, observedPager.position.isScrollingNotifier.value]
      : [null, false];''')
    with main.open('a', encoding='utf-8') as output:
        output.write('''

class ReaderBenchmarkBinding extends WidgetsFlutterBinding {
  static List<Object?> Function()? pageState;

  @override
  void scheduleFrame() {
    if (ReaderPerfProbe.recording && !hasScheduledFrame && framesEnabled) {
      ReaderPerfProbe.event('frameRequest', [transientCallbackCount, schedulerPhase.index]);
    }
    super.scheduleFrame();
  }

  @override
  void handleBeginFrame(Duration? rawTimeStamp) {
    if (ReaderPerfProbe.recording) {
      ReaderPerfProbe.event('frameBegin', [rawTimeStamp?.inMicroseconds,
        transientCallbackCount, ...?pageState?.call()]);
    }
    super.handleBeginFrame(rawTimeStamp);
  }

  @override
  void handleDrawFrame() {
    super.handleDrawFrame();
    if (ReaderPerfProbe.recording) {
      ReaderPerfProbe.event('frameEnd', [hasScheduledFrame, transientCallbackCount]);
    }
  }
}
''')
    data['frameRequestProbe'] = {
        'sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'beginColumns': ['engineTimestampUs', 'transientCallbacks', 'page', 'scrolling'],
        'requestColumns': ['transientCallbacks', 'schedulerPhaseIndex'],
        'endColumns': ['hasScheduledFrame', 'transientCallbacks'],
        'meaning': 'Observe accepted scheduleFrame calls and actual begin/end; no forced frame',
    }
    manifest.write_text(json.dumps(data, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    instrument(parser.parse_args().source)
