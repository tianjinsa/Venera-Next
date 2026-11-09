import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/features/history/history.dart';
import 'package:venera_next/foundation/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Agent daily statistics accumulate with Next foreground duration',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'agent-daily-stats-',
      );
      App.dataPath = directory.path;
      final manager = HistoryManager.create();
      try {
        await manager.init();
        final history = History.fromMap({
          'id': 'comic',
          'type': 0,
          'title': 'Test comic',
          'subtitle': 'Test author',
          'cover': '',
          'time': DateTime.now().millisecondsSinceEpoch,
          'ep': 1,
          'page': 1,
        });
        await manager.addHistory(history);
        await manager.addReadDuration(
          history,
          const Duration(milliseconds: 1200),
        );
        await manager.addReadDuration(
          history,
          const Duration(milliseconds: 1800),
        );
        final stats = manager.readingStatistics(1).single;
        expect(stats.comicId, 'comic');
        expect(stats.title, 'Test comic');
        expect(stats.durationSeconds, 3);
        expect(manager.getTotalReadDurationMs(), 3000);
        manager.close();
        await manager.init();
        expect(manager.readingStatistics(1).single.durationSeconds, 3);
      } finally {
        await manager.waitForAsyncWrites();
        await manager.closeAfterReads();
        manager.dispose();
        directory.deleteSync(recursive: true);
      }
    },
  );
}
