import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaya_app/app/router.dart';
import 'package:vaya_app/domain/domain.dart';
import 'package:vaya_app/features/trip_request/trip_request_form_notifier.dart';

import 'form_test_helpers.dart';

void main() {
  setUpAll(loadPromptFont);

  testWidgets('filling every step builds the trip request', (tester) async {
    final c = await pumpForm(tester);

    // ① where, when and how many
    await chooseDestination(tester, 'ชลบุรี');
    await pickDates(tester);
    expect(find.text('2 วัน 1 คืน'), findsOneWidget);
    await tester.tap(find.byTooltip('เพิ่มจำนวนผู้เดินทาง'));
    await tester.pumpAndSettle();
    expect(find.text('3 คน'), findsOneWidget);
    await next(tester);

    // ② budget, pace and transport
    await tester.enterText(find.byType(TextField), '9000');
    await tester.pumpAndSettle();
    expect(find.text('฿3,000'), findsOneWidget); // per person
    await tapText(tester, 'อัดแน่น');
    expect(find.text('เดินทางไป–กลับ'), findsOneWidget);
    await tapText(tester, 'รถไฟ');
    await tapText(tester, 'รถสาธารณะ');
    await next(tester);

    // ③ style, with the whole request summed up
    await tapText(tester, 'ทะเล');
    await tester.enterText(find.byType(TextField), 'ไม่ทานเผ็ด');
    expect(find.text('กรุงเทพมหานคร → ชลบุรี'), findsOneWidget);
    expect(find.text('฿9,000 (฿3,000 / คน)'), findsOneWidget);
    expect(find.text('อัดแน่น · รถไฟ · รถสาธารณะ'), findsOneWidget);
    await tapText(tester, 'ให้ AI วางแผนให้');

    final request = c.read(tripRequestFormProvider.notifier).submit();
    expect(request.startDate, DateTime(2026, 11, 14));
    expect(request.endDate, DateTime(2026, 11, 15));
    expect(request.travellerCount, 3);
    expect(request.budget, 9000);
    expect(request.destinationId, 'chonburi');
    expect(request.intercityMode, IntercityMode.train);
    expect(request.localTransportMode, LocalTransportMode.publicTransport);
    expect(request.preferenceTags, {PreferenceTag.beach});
    expect(request.pace, Pace.packed);
    expect(request.note, 'ไม่ทานเผ็ด');
    expect(location(c), '${AppRoutes.generating}?destination=chonburi');
  });

  testWidgets('letting the AI choose goes to the suggestions', (tester) async {
    final c = await pumpForm(tester);
    await pickDates(tester);
    await next(tester);
    await tester.enterText(find.byType(TextField), '6000');
    await next(tester);
    await tapText(tester, 'คาเฟ่');
    await tester.tap(find.text('ให้ AI วางแผนให้'));
    // The suggestions resolve outside the fake clock.
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(location(c), AppRoutes.suggestions);
    expect(find.text('เลือกจังหวัดนี้'), findsWidgets);
  });

  testWidgets('a summary row jumps back to its step', (tester) async {
    await pumpForm(tester);
    await pickDates(tester);
    await next(tester);
    await tester.enterText(find.byType(TextField), '6000');
    await next(tester);
    expect(find.text('สรุปคำขอ'), findsOneWidget);

    await tapText(tester, 'งบรวม');
    expect(find.text('ขั้นที่ 2 จาก 3'), findsOneWidget);
    expect(find.text('6000'), findsOneWidget);
  });
}
