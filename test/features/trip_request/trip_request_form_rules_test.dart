import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaya_app/features/trip_request/trip_request_form_notifier.dart';

import 'form_test_helpers.dart';

void main() {
  setUpAll(loadPromptFont);

  testWidgets('a Bangkok to Bangkok trip hides the intercity choice', (
    tester,
  ) async {
    final c = await pumpForm(tester);
    await chooseDestination(tester, 'กรุงเทพมหานคร');
    await pickDates(tester);
    await next(tester);

    expect(find.text('เที่ยวในจังหวัดเดียวกับจุดเริ่มต้น'), findsOneWidget);
    expect(find.text('เดินทางไป–กลับ'), findsNothing);
    expect(c.read(tripRequestFormProvider).needsIntercity, isFalse);
  });

  testWidgets('shows what is missing instead of moving on', (tester) async {
    await pumpForm(tester);

    await next(tester);
    expect(find.text('เลือกวันไปและวันกลับ'), findsOneWidget);
    expect(find.text('ขั้นที่ 1 จาก 3'), findsOneWidget);

    await pickDates(tester);
    await next(tester);
    await next(tester);
    expect(find.text('กรอกงบรวมของทริป'), findsOneWidget);
    expect(find.text('ขั้นที่ 2 จาก 3'), findsOneWidget);
  });

  testWidgets('going back keeps what was typed', (tester) async {
    await pumpForm(tester);
    await pickDates(tester);
    await next(tester);
    await tester.enterText(find.byType(TextField), '7000');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('ย้อนกลับ'));
    await tester.pumpAndSettle();
    expect(find.text('2 วัน 1 คืน'), findsOneWidget);

    await next(tester);
    expect(find.text('7000'), findsOneWidget);
  });

  testWidgets('wide windows list the steps and allow going back to one', (
    tester,
  ) async {
    await pumpForm(tester, size: tablet);
    await pickDates(tester);
    await next(tester);

    expect(find.text('ขั้นที่ 2 จาก 3'), findsOneWidget);
    await tester.tap(find.text('ไปไหน เมื่อไร กี่คน'));
    await tester.pumpAndSettle();
    expect(find.text('ขั้นที่ 1 จาก 3'), findsOneWidget);
  });
}
