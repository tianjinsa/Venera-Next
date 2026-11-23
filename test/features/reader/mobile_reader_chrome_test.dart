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
import 'package:venera_next/features/reader/bottom_actions.dart';
import 'package:venera_next/features/reader/image_favorite_controller.dart';
import 'package:venera_next/features/reader/platform_effects_controller.dart';
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
    'phone chrome floats over the image; only two quick image commands',
    (tester) async {
      _narrowPhone(tester);
      final calls = <String>[];
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: () => calls.add('image'),
                  child: const ColoredBox(color: Color(0xFF992255)),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    height: 56,
                    child: ReaderTopBar(
                      title: 'Comic',
                      actions: const [],
                      usePrism: true,
                      onBack: () {},
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: ReaderBottomBar(
                    label: 'E1 : P2',
                    actions: buildReaderBottomActions(
                      context,
                      usePrism: true,
                      imageFavoriteStatus:
                          ReaderImageFavoriteStatus.uncollected,
                      onCollect: () => calls.add('collect'),
                      orientation: ReaderOrientation.system,
                      onRotate: () => calls.add('rotate'),
                      brightnessEnabled: true,
                      onBrightness: () => calls.add('picture'),
                      automaticReading: ReaderAutomaticReadingAction(
                        tooltip: 'Auto',
                        active: false,
                        playing: false,
                        onPressed: () => calls.add('auto'),
                      ),
                      onChapters: () => calls.add('chapters'),
                      onSave: () => calls.add('save'),
                      onShare: () => calls.add('share'),
                    ),
                    usePrism: true,
                    page: 2,
                    maxPage: 12,
                    reversed: true,
                    isOpen: true,
                    onPageChanged: (value) => calls.add('page $value'),
                    onPrevious: () {},
                    onNext: () => calls.add('next'),
                    nextTooltip: 'Next chapter',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(
        tester
            .widgetList<prism.TonalButtonGroup>(
              find.byType(prism.TonalButtonGroup),
            )
            .map((group) => group.children.length),
        everyElement(lessThanOrEqualTo(2)),
      );
      final quick = find.byKey(const ValueKey('reader-bottom-quick'));
      final more = find.byKey(const ValueKey('reader-bottom-more'));
      expect(tester.widget<prism.TonalButtonGroup>(quick).children.length, 2);
      expect(tester.getRect(quick).right, lessThan(tester.getRect(more).left));
      for (final key in [ReaderTopBar, ReaderBottomBar]) {
        final bar = find.byType(key);
        final backings = find.descendant(
          of: bar,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Material && w.type != MaterialType.transparency ||
                w is ColoredBox ||
                w is DecoratedBox,
          ),
        );
        for (final box in backings.evaluate()) {
          expect(
            box.size!.width,
            lessThan(320),
            reason: 'the artwork, not a toolbar backing, must fill the width',
          );
        }
      }
      await tester.tapAt(const Offset(140, 26)); // empty top/title
      await tester.tapAt(const Offset(5, 701)); // lower edge outside capsules
      Finder icon(String label) => find.byWidgetPredicate(
        (widget) => widget is prism.IconButton && widget.tooltip == label,
      );
      await tester.tap(icon('Next chapter'));
      await tester.tap(icon('Collect the image'));
      await tester.tap(icon('Adjust picture'));
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.semanticFormatterCallback!(5), contains('5 / 12'));
      slider.onChanged!(5);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(find.text('Chapters').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Chapters').hitTestable());
      await tester.pumpAndSettle();
      expect(calls, [
        'image',
        'image',
        'next',
        'collect',
        'picture',
        'page 5',
        'chapters',
      ]);
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
