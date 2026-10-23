import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaya_app/app/providers/data_providers.dart';
import 'package:vaya_app/app/providers/mock_providers.dart';
import 'package:vaya_app/features/assistant/assistant_screen.dart';
import 'package:vaya_app/features/assistant/plan_chat_panel.dart';
import 'package:vaya_app/features/trip_plan/trip_plan_view_provider.dart';
import 'package:vaya_app/shared/widgets/mascot_view.dart';

void main() {
  late ProviderContainer container;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    await tester.pumpAndSettle();
  }

  Future<void> pumpChat(WidgetTester tester, {bool withDraft = true}) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      await container.read(placeCatalogProvider.future);
      await container.read(planChatProvider.future);
      if (withDraft) {
        container
            .read(draftTripsProvider.notifier)
            .add(
              await container.read(mockTripPlanProvider.future),
              await container.read(mockTripRequestProvider.future),
            );
      }
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AssistantScreen()),
      ),
    );
    await settle(tester);
  }

  testWidgets('without trips it points to planning one', (tester) async {
    await pumpChat(tester, withDraft: false);

    expect(find.text('ยังไม่มีทริปให้ปรับ'), findsOneWidget);
    expect(find.text('วางแผนทริปใหม่'), findsOneWidget);
    expect(find.byType(PlanChatPanel), findsNothing);
  });

  testWidgets('picks the latest plan and greets with the mascot', (
    tester,
  ) async {
    await pumpChat(tester);

    expect(find.textContaining('ชลบุรี 14–15 พ.ย.'), findsWidgets);
    expect(find.textContaining('สวัสดี! ฉันช้างน้อย'), findsOneWidget);
    expect(find.byType(MascotAvatar), findsWidgets);
  });

  testWidgets('proposes an edit and applies it only when confirmed', (
    tester,
  ) async {
    await pumpChat(tester);
    final before = container.read(draftTripsProvider)['draft-1']!.plan;

    await tester.enterText(
      find.byType(TextField).last,
      'วันที่ 2 ขอร้านอาหารทะเลแทน',
    );
    await tester.tap(find.byTooltip('ส่ง'));
    await settle(tester);

    // Once as the suggestion chip, once as the sent message.
    expect(find.text('วันที่ 2 ขอร้านอาหารทะเลแทน'), findsNWidgets(2));
    expect(find.textContaining('ให้ไหม?'), findsOneWidget);
    // Nothing changes before the traveller agrees.
    expect(
      identical(container.read(draftTripsProvider)['draft-1']!.plan, before),
      isTrue,
    );

    await tester.tap(find.text('เปลี่ยนเลย'));
    await settle(tester);

    expect(find.textContaining('เรียบร้อย!'), findsOneWidget);
    expect(find.text('เปลี่ยนเลย'), findsNothing);
    final after = container.read(draftTripsProvider)['draft-1']!.plan;
    expect(identical(after, before), isFalse);
  });

  testWidgets('declining keeps the plan', (tester) async {
    await pumpChat(tester);
    final before = container.read(draftTripsProvider)['draft-1']!.plan;

    final chip = find.widgetWithText(ActionChip, 'ลบจุดที่ 2 วันที่ 1');
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await settle(tester);
    await tester.tap(find.text('ไม่เป็นไร'));
    await settle(tester);

    expect(find.text('ได้เลย ไม่เปลี่ยนนะ'), findsOneWidget);
    expect(
      identical(container.read(draftTripsProvider)['draft-1']!.plan, before),
      isTrue,
    );
  });
}
