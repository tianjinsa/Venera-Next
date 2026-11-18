import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/features/history/history_api.dart';
import 'package:venera_next/features/reader/auto_reading.dart';
import 'package:venera_next/features/reader/image_favorite_controller.dart';
import 'package:venera_next/features/reader/image_picker.dart';
import 'package:venera_next/features/reader/platform_effects_controller.dart';
import 'package:venera_next/features/reader/progress_bar.dart';
import 'package:venera_next/features/reader/progress_navigation.dart';
import 'package:venera_next/features/reader/scaffold.dart';
import 'package:venera_next/features/reader/shell_data.dart';
import 'package:venera_next/foundation/image_work.dart';
import 'package:venera_next/foundation/reader_settings.dart';

void main() {
  testWidgets(
    'hidden status completion retains toolbar and quick collection; visible status stays live',
    (tester) async {
      final work = ImageWork();
      final changes = ChangeNotifier();
      final shell = GlobalKey<ReaderScaffoldState>();
      final viewport = _SingleImageViewport();
      var pending = Completer<bool>();
      var page = 1, reads = 0, toggles = 0;
      int? selectedIndex;
      final toolbar = find.byType(ReaderBottomBar, skipOffstage: false);
      Future<void> mount() => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderScaffold(
              key: shell,
              data: ReaderShellData(
                comicId: 'fixture',
                sourceKey: 'fixture',
                title: 'Fixture',
                chapterTitle: null,
                hasChapters: false,
                vertical: false,
                gallery: true,
                animating: false,
                onCommentsPage: false,
                swipeToCollect: false,
                preferences: ReaderSettings.resolve(
                  global: {
                    'enableClockAndBatteryInfoInReader': false,
                    'showPageNumberInReader': false,
                  },
                ),
                automaticReading: AutoReadingStatus.stopped,
              ),
              progress: ReaderProgressRequest(
                identity: 'fixture',
                page: page,
                maxPage: 5,
                chapter: 1,
                maxChapter: 1,
                reversed: false,
                isCurrent: () => true,
                toPage: (_, {animated = true}) => true,
                toChapter: (_) => true,
              ),
              imageWork: work,
              favoriteChanges: changes,
              onExit: () async {},
              onFullscreen: null,
              onToggleAutomaticReading: () => false,
              acquireSidebarPause: () => () {},
              orientation: ReaderOrientation.system,
              onRotate: null,
              onSystemUiChanged: (_) {},
              createChapterMenu: () => null,
              readImagePickContext: () => ReaderImagePickContext(
                viewport: viewport,
                images: const ['fixture'],
                chapter: 1,
              ),
              createFavoriteQuery: () {
                final target = page;
                return ReaderImageFavoriteQuery(
                  key: target,
                  isCurrent: () => page == target,
                  read: () {
                    reads++;
                    return pending.future;
                  },
                );
              },
              createImageFavorite: () => ReaderImageFavoriteRequest(
                supported: true,
                isCurrent: () => true,
                toggle: (index, check) async {
                  check();
                  selectedIndex = index;
                  toggles++;
                  pending = Completer<bool>()..complete(true);
                  return ImageFavoriteResult.collected;
                },
              ),
              createImageExport: () => null,
              createSettings: () => null,
              createChapterComments: () => null,
              chapterNavigation: null,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      await mount();
      expect(reads, 1);
      final hidden = tester.widget<ReaderBottomBar>(toolbar);
      pending.complete(false);
      await tester.pump();
      expect(tester.widget<ReaderBottomBar>(toolbar), same(hidden));

      // The completed background read must still admit a shortcut collection.
      shell.currentState!.addImageFavorite();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(toggles, 1);
      expect(selectedIndex, 0);
      expect(reads, 2);
      expect(tester.widget<ReaderBottomBar>(toolbar), same(hidden));
      shell.currentState!.openOrClose();
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(reads, 2);

      shell.currentState!.openOrClose();
      await tester.pumpAndSettle();
      pending = Completer<bool>();
      changes.notifyListeners();
      await tester.pump();
      expect(
        reads,
        3,
        reason: 'Invalidation still binds a new read while closed',
      );
      final invalidated = tester.widget<ReaderBottomBar>(toolbar);
      pending.complete(false);
      await tester.pump();
      expect(tester.widget<ReaderBottomBar>(toolbar), same(invalidated));
      shell.currentState!.openOrClose();
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);

      page = 2;
      pending = Completer<bool>();
      await mount();
      expect(reads, 4);
      final visible = tester.widget<ReaderBottomBar>(toolbar);
      pending.complete(true);
      await tester.pump();
      expect(tester.widget<ReaderBottomBar>(toolbar), isNot(same(visible)));
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await work.dispose();
      changes.dispose();
    },
  );
}

class _SingleImageViewport implements ReaderImagePickingViewport {
  @override
  (int, int)? get currentImageRange => (0, 1);
  @override
  int? getImageIndexByOffset(Offset offset) => 0;
}
