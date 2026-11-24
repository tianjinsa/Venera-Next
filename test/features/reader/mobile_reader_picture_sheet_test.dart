import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/common_button.dart' as prism;
import 'package:prism_ui/liquid_glass.dart' as prism;
import 'package:prism_ui/snap_sheet.dart' as prism;
import 'package:venera_next/components/mobile_ui.dart';
import 'package:venera_next/features/reader/auto_reading.dart';
import 'package:venera_next/features/reader/brightness.dart';
import 'package:venera_next/features/reader/platform_effects_controller.dart';
import 'package:venera_next/features/reader/progress_navigation.dart';
import 'package:venera_next/features/reader/scaffold.dart';
import 'package:venera_next/features/reader/shell_data.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/image_work.dart';
import 'package:venera_next/foundation/reader_settings.dart';

class _PushedRoutes extends NavigatorObserver {
  Route<dynamic>? last;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    last = route;
  }
}

class _ArtworkPainter extends CustomPainter {
  const _ArtworkPainter(this.onPaint);
  final VoidCallback onPaint;

  @override
  void paint(Canvas canvas, Size size) {
    onPaint();
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.orange);
  }

  @override
  bool shouldRepaint(_ArtworkPainter oldDelegate) => false;
}

void main() {
  testWidgets(
    'first and repeat picture opens keep the gallery still; eInk stays inline',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final language = appdata.settings['language'];
      appdata.settings['language'] = 'en-US';
      addTearDown(() => appdata.settings['language'] = language);
      final shell = GlobalKey<ReaderScaffoldState>();
      final targets = ValueNotifier(('Original', false));
      final favorites = ChangeNotifier();
      final work = ImageWork();
      final events = <String>[];
      final routes = _PushedRoutes();
      var artworkBuilds = 0, artworkPaints = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [routes],
          localizationsDelegates: const [MobileUiLocalizations.delegate],
          builder: (_, child) => MobileUiTheme(glass: 'ultra', child: child!),
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: targets,
              builder: (_, target, _) => ReaderScaffold(
                key: shell,
                data: ReaderShellData(
                  comicId: target.$1,
                  sourceKey: 'local',
                  title: target.$1,
                  chapterTitle: null,
                  hasChapters: false,
                  vertical: false,
                  gallery: true,
                  animating: false,
                  onCommentsPage: false,
                  swipeToCollect: false,
                  preferences: ReaderSettings.resolve(
                    global: {
                      'eInkRefreshEnabled': target.$2,
                      'showPageNumberInReader': false,
                      'enableClockAndBatteryInfoInReader': false,
                    },
                  ),
                  automaticReading: AutoReadingStatus.stopped,
                ),
                progress: ReaderProgressRequest(
                  identity: target.$1,
                  page: 2,
                  maxPage: 10,
                  chapter: 1,
                  maxChapter: 1,
                  reversed: false,
                  isCurrent: () => true,
                  toPage: (_, {animated = true}) => true,
                  toChapter: (_) => true,
                ),
                onExit: () async {},
                onFullscreen: null,
                onToggleAutomaticReading: () => false,
                acquireSidebarPause: () {
                  events.add('pause');
                  return () => events.add('release');
                },
                readImagePickContext: () => null,
                imageWork: work,
                orientation: ReaderOrientation.system,
                onRotate: null,
                onSystemUiChanged: (_) {},
                createChapterMenu: () => null,
                favoriteChanges: favorites,
                createFavoriteQuery: () => null,
                createImageFavorite: () => null,
                createImageExport: () => null,
                createSettings: () => null,
                createChapterComments: () => null,
                chapterNavigation: null,
                child: Builder(
                  builder: (_) {
                    artworkBuilds++;
                    return CustomPaint(
                      painter: _ArtworkPainter(() => artworkPaints++),
                      size: Size.infinite,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      shell.currentState!.openOrClose();
      await tester.pumpAndSettle();
      final panel = find.byType(ReaderBrightnessPanel);
      final surface = find.byKey(const ValueKey('mobile-large-sheet-surface'));
      final adjust = find.byWidgetPredicate(
        (w) => w is prism.IconButton && w.tooltip == 'Adjust picture',
      );
      expect(panel, findsNothing);
      expect(prism.LiquidGlassHost.debugLastCapture?.panes, isNotEmpty);

      // Compare both openings at the same individual frame boundaries. This
      // is a work/timing regression, not a claim about Android GPU frame time.
      for (var open = 0; open < 2; open++) {
        final previousRoute = routes.last;
        final initialWork = (artworkBuilds, artworkPaints);
        await tester.tap(adjust.hitTestable());
        expect(routes.last, isNot(same(previousRoute)));
        expect(routes.last, isA<prism.SnapSheetRoute<void>>());
        await tester.pump();
        expect(panel, findsOneWidget);
        final mount = tester.getRect(surface).top;
        await tester.pump(const Duration(milliseconds: 16));
        final firstMotion = tester.getRect(surface).top;
        expect(firstMotion, lessThan(mount));
        for (var frame = 0; frame < 4; frame++) {
          expect(prism.LiquidGlassHost.debugLastCapture?.panes, isEmpty);
          expect((artworkBuilds, artworkPaints), initialWork);
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pumpAndSettle();
        expect(
          prism.LiquidGlassScope.of(tester.element(panel)),
          isTrue,
          reason: 'the active sheet retains the normal app glass setting',
        );
        if (open == 0) {
          routes.navigator!.pop();
          await tester.pump(const Duration(milliseconds: 16));
          expect(events, ['pause']);
          expect(prism.LiquidGlassHost.debugLastCapture?.panes, isEmpty);
          await tester.pumpAndSettle();
          expect(events, ['pause', 'release']);
          expect(prism.LiquidGlassHost.debugLastCapture?.panes, isNotEmpty);
        }
      }
      final route = ModalRoute.of(tester.element(panel));
      expect(route, isA<prism.SnapSheetRoute<void>>());
      final sheet = tester.getRect(surface);
      expect(sheet.width, lessThan(390));
      expect(sheet.height, inInclusiveRange(330, 440));
      expect(find.text('Line enhancement'), findsOneWidget);
      expect(find.text('Night mode'), findsOneWidget);
      expect(events, ['pause', 'release', 'pause']);
      // Changing books retires this exact presentation, rather than applying a
      // stale callback to the replacement reader or leaking its borrowed pause.
      targets.value = ('Replacement', false);
      await tester.pumpAndSettle();
      expect(route!.isActive, isFalse);
      expect(panel, findsNothing);
      expect(events, ['pause', 'release', 'pause', 'release']);
      targets.value = ('Replacement', true);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Adjust picture'));
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);
      expect(
        ModalRoute.of(tester.element(panel)),
        isNot(isA<prism.SnapSheetRoute<void>>()),
      );
      expect(events, ['pause', 'release', 'pause', 'release']);
      await tester.pumpWidget(const SizedBox.shrink());
      targets.dispose();
      favorites.dispose();
      expect(tester.takeException(), isNull);
    },
  );
}
