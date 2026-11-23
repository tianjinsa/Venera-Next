import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/button.dart' as prism;
import 'package:prism_ui/common_button.dart' as prism;
import 'package:prism_ui/press_surface.dart' as prism;
import 'package:prism_ui/switch.dart' as prism;
import 'package:prism_ui/text_field.dart' as prism;
import 'package:venera_next/components/mobile_ui.dart';
import 'package:venera_next/features/comic_details/action_button.dart';
import 'package:venera_next/features/comic_source/models.dart';
import 'package:venera_next/features/reader/chapter_comments.dart';
import 'package:venera_next/features/reader/chapter_menu.dart';
import 'package:venera_next/features/reader/chapters.dart';
import 'package:venera_next/features/reader/comments_controller.dart';
import 'package:venera_next/features/reader/brightness.dart';
import 'package:venera_next/features/reader/chrome_action.dart';
import 'package:venera_next/features/reader/progress_bar.dart';
import 'package:venera_next/features/reader/top_bar.dart';
import 'package:venera_next/foundation/image_work.dart';
import 'package:venera_next/foundation/res.dart';

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: const [MobileUiLocalizations.delegate],
  builder: (_, widget) => MobileUiTheme(glass: 'off', child: widget!),
  home: Scaffold(body: child),
);

void _narrowPhone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 720);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('compact reader shares one Prism top action group', (
    tester,
  ) async {
    _narrowPhone(tester);
    var settings = 0, exits = 0;
    const settingsKey = ValueKey('reader-settings-action');
    await tester.pumpWidget(
      _app(
        Align(
          alignment: Alignment.topCenter,
          child: ReaderTopBar(
            title: 'Comic name',
            chapterTitle: 'Chapter title',
            usePrism: true,
            onBack: () => exits++,
            actions: [
              ReaderChromeAction(
                key: settingsKey,
                usePrism: true,
                label: 'Settings',
                icon: const Icon(Icons.settings),
                onPressed: () => settings++,
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(prism.TonalButtonGroup), findsOneWidget);
    expect(find.text('Chapter title'), findsOneWidget);
    await tester.tap(find.byKey(settingsKey));
    await tester.pump();
    final back = find.byWidgetPredicate(
      (widget) => widget is prism.IconButton && widget.tooltip == 'Back',
    );
    await tester.tap(back);
    expect(settings, 1);
    expect(exits, 1);
  });

  testWidgets(
    'narrow Prism bottom controls scroll without losing page control',
    (tester) async {
      _narrowPhone(tester);
      var next = 0;
      final actions = <int>[];
      await tester.pumpWidget(
        _app(
          Align(
            alignment: Alignment.bottomCenter,
            child: ReaderBottomBar(
              label: 'E1 : P2',
              actions: [
                for (var i = 0; i < 9; i++)
                  ReaderChromeAction(
                    key: ValueKey(i),
                    usePrism: true,
                    label: 'Action $i',
                    icon: const Icon(Icons.bookmark),
                    onPressed: () => actions.add(i),
                  ),
              ],
              usePrism: true,
              page: 2,
              maxPage: 12,
              reversed: true,
              isOpen: true,
              onPageChanged: (_) {},
              onPrevious: () {},
              onNext: () => next++,
              nextTooltip: 'Next chapter',
            ),
          ),
        ),
      );
      expect(find.byType(ReaderProgressSlider), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is prism.IconButton && widget.tooltip == 'Next chapter',
        ),
      );
      await tester.drag(
        find.byType(prism.TonalButtonGroup),
        const Offset(-330, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey(8)).hitTestable());
      expect(actions, [8]);
      expect(next, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reader appearance uses a Prism switch and keeps slider commands',
    (tester) async {
      _narrowPhone(tester);
      final changes = <bool>[];
      await tester.pumpWidget(
        _app(
          ReaderBrightnessControl(
            enabled: true,
            brightness: 75,
            onEnabledChanged: changes.add,
            onBrightnessChanged: (_) {},
          ),
        ),
      );
      await tester.tap(find.byType(prism.Switch));
      await tester.pumpAndSettle();
      expect(changes, [false]);
      expect(find.byType(Slider), findsOneWidget);
    },
  );

  testWidgets('Prism comic action distinguishes tap, long press and cancel', (
    tester,
  ) async {
    _narrowPhone(tester);
    var taps = 0, holds = 0;
    await tester.pumpWidget(
      _app(
        Center(
          child: ComicDetailActionButton(
            icon: const Icon(Icons.bookmark_outline),
            text: 'Favorite',
            onPressed: () => taps++,
            onLongPressed: () => holds++,
          ),
        ),
      ),
    );
    final action = find.byType(prism.PressSurface);
    expect(action, findsOneWidget);
    final gesture = await tester.startGesture(tester.getCenter(action));
    await tester.pump(const Duration(milliseconds: 180));
    await gesture.cancel();
    await tester.pump();
    expect(taps, 0);
    expect(holds, 0);

    await tester.tap(action);
    await tester.pumpAndSettle();
    await tester.longPress(action);
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(holds, 1);
  });

  testWidgets('Prism chapter row still selects the original chapter index', (
    tester,
  ) async {
    _narrowPhone(tester);
    final selected = <int>[];
    final data = ReaderChapterMenuData(
      ComicChapters.grouped({
        'Volume 1': {'alpha': 'Opening', 'beta': 'Return'},
      }),
      currentChapter: 2,
      downloaded: ['beta'],
    );
    await tester.pumpWidget(
      _app(
        ReaderChaptersView(
          data: data,
          usePrism: true,
          onSelect: selected.add,
          onClose: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final current = find.ancestor(
      of: find.text('Return'),
      matching: find.byType(prism.PressSurface),
    );
    expect(tester.widget<prism.PressSurface>(current).selected, isTrue);
    await tester.tap(find.text('Return').hitTestable());
    expect(selected, [2]);
  });

  testWidgets('Prism chapter reply composer shares original send and exit', (
    tester,
  ) async {
    _narrowPhone(tester);
    final work = ImageWork();
    final sent = <String>[];
    var exits = 0;
    final request = ReaderChapterCommentsRequest(
      identity: Object(),
      sourceKey: 'test',
      comicTitle: 'Book',
      chapterTitle: 'Opening',
      isCurrent: () => true,
      load: (_, _) async => const Res(<Comment>[], subData: 1),
      send: (text, _) async {
        sent.add(text);
        return const Res(true);
      },
    );
    await tester.pumpWidget(
      _app(
        EmbeddedChapterCommentsPage(
          request: request,
          work: work,
          onExit: () async {
            exits++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final field = find.byType(prism.TextField);
    expect(field, findsOneWidget);
    await tester.enterText(field, 'Hello');
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is prism.IconButton && widget.tooltip == 'Send',
      ),
    );
    await tester.pumpAndSettle();
    expect(sent, ['Hello']);
    expect(tester.widget<prism.TextField>(field).controller!.text, isEmpty);
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is prism.IconButton && widget.tooltip == 'Exit',
      ),
    );
    expect(exits, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
