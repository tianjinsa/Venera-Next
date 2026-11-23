import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/search_field.dart' as prism show SearchField;
import 'package:prism_ui/sheet_header.dart' as prism show SheetDragHandle;
import 'package:prism_ui/snap_sheet.dart' as prism show SnapSheetRoute;
import 'package:venera_next/components/mobile_ui.dart';
import 'package:venera_next/features/agent/agent_controller.dart';
import 'package:venera_next/features/agent/agent_history_view.dart';
import 'package:venera_next/features/agent/agent_page.dart';
import 'package:venera_next/features/agent/agent_settings_page.dart';
import 'package:venera_next/features/agent/agent_showcase_view.dart';
import 'package:venera_next/features/agent/agent_store.dart';

import 'agent_test_support.dart';

Finder _toolbarButton(String label) => find.byWidgetPredicate(
  (widget) => widget is MobileToolbarButton && widget.label == label,
);

void main() {
  testWidgets('phone Agent sheets dismiss, select, and preserve navigation', (
    tester,
  ) async {
    final root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('agent-mobile-sheets-'),
    ))!;
    configureAgentTestPaths(root.path);
    final store = (await tester.runAsync(
      () => AgentStore.open('${root.path}/agent'),
    ))!;
    final earlier = store.createConversation()
      ..title = '较早的对话'
      ..updatedAt = 1;
    store.saveConversation(earlier);
    final controller = AgentController(store);
    await controller.newConversation();
    final original = controller.conversation.id;
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844)
      ..padding = const FakeViewPadding(top: 24, bottom: 34);
    try {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [MobileUiLocalizations.delegate],
          builder: (_, child) => MobileUiTheme(glass: 'off', child: child!),
          home: AgentPage(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(_toolbarButton('历史对话'));
      await tester.pumpAndSettle();
      final history = find.byType(AgentHistoryPanel);
      final historyScroll = find.byKey(
        const ValueKey('agent-history-mobile-scroll'),
      );
      expect(
        ModalRoute.of(tester.element(history)),
        isA<prism.SnapSheetRoute>(),
      );
      expect(tester.widget<CustomScrollView>(historyScroll).primary, isTrue);
      expect(find.byType(prism.SearchField), findsOneWidget);
      expect(
        find.byKey(const ValueKey('agent-history-delete-selected')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('agent-history-manage')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('agent-history-delete-selected')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('agent-history-manage')));
      await tester.pumpAndSettle();

      final handle = tester.getRect(find.byType(prism.SheetDragHandle));
      await tester.flingFrom(
        Offset(handle.center.dx, handle.bottom - 2),
        const Offset(0, 575),
        1600,
      );
      await tester.pumpAndSettle();
      expect(history, findsNothing);
      expect(controller.conversation.id, original);

      await tester.tap(_toolbarButton('历史对话'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(earlier.title));
      await tester.pumpAndSettle();
      expect(history, findsNothing);
      expect(controller.conversation.id, earlier.id);

      await tester.tap(_toolbarButton('展示漫画'));
      await tester.pumpAndSettle();
      final showcase = find.byType(AgentShowcasePanel);
      expect(
        ModalRoute.of(tester.element(showcase)),
        isA<prism.SnapSheetRoute>(),
      );
      expect(tester.getBottomLeft(showcase).dy, lessThanOrEqualTo(844 - 34));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(showcase, findsNothing);

      await tester.tap(find.byKey(const ValueKey('agent-settings')));
      await tester.pumpAndSettle();
      expect(find.byType(AgentSettingsPage), findsOneWidget);
      expect(find.byType(MobileToolbar), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AgentSettingsPage), findsNothing);
      expect(controller.conversation.id, earlier.id);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      tester.view
        ..resetPadding()
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
      await tester.runAsync(() => root.delete(recursive: true));
    }
  });
}
