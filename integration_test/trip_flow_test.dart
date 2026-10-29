// The main trip flow on a real device or simulator (#146):
//   flutter test integration_test -d <device>
// Real pipeline, data and screens; only sign-in is the mock and Gemini is
// offline, so the planner uses its fallbacks and every run is the same.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaya_app/app/app.dart';
import 'package:vaya_app/app/providers/data_providers.dart';
import 'package:vaya_app/data/mock/mock_auth_repository.dart';
import 'package:vaya_app/features/trip_request/trip_request_form_notifier.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Waits until [finder] shows up, for screens that load or animate.
  Future<void> waitFor(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final end = DateTime.now().add(timeout);
    while (finder.evaluate().isEmpty) {
      if (DateTime.now().isAfter(end)) {
        fail('Timed out waiting for $finder');
      }
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final target = find.text(text).first;
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets('sign in, plan with AI suggestions, save, reopen and delete', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Signed out at first, like a fresh install.
          authRepositoryProvider.overrideWithValue(MockAuthRepository()),
          // The date picker opens on November 2026.
          todayProvider.overrideWithValue(DateTime(2026, 11, 1)),
        ],
        child: const VayaApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Sign in.
    await waitFor(tester, find.textContaining('เข้าสู่ระบบด้วย Google'));
    await tester.tap(find.textContaining('เข้าสู่ระบบด้วย Google'));
    await waitFor(tester, find.text('วางแผนทริปใหม่'));
    await tapText(tester, 'ทริปของฉัน');
    expect(find.text('ยังไม่มีทริป'), findsOneWidget);
    await tapText(tester, 'หน้าแรก');

    // Step 1: dates and travellers; the AI picks the province.
    await tapText(tester, 'วางแผนทริปใหม่');
    await tapText(tester, 'เลือกวันไป–กลับ');
    for (final day in ['14', '15']) {
      await tester.tap(find.text(day).first);
      await tester.pumpAndSettle();
    }
    await tapText(tester, 'ตกลง');
    expect(find.text('2 วัน 1 คืน'), findsOneWidget);
    await tapText(tester, 'ถัดไป');

    // Step 2: a budget, default pace and transport.
    await tester.enterText(find.byType(TextField), '6000');
    await tester.pumpAndSettle();
    await tapText(tester, 'ถัดไป');

    // Step 3: what they like.
    await tapText(tester, 'ทะเล');
    await tapText(tester, 'คาเฟ่');
    await tapText(tester, 'ให้ AI วางแผนให้');

    // Suggestions: Chonburi first for beach and cafés.
    await waitFor(tester, find.text('เลือกจังหวัดนี้'));
    expect(find.text('แนะนำ'), findsOneWidget);
    expect(find.text('ชลบุรี'), findsOneWidget);
    await tapText(tester, 'เลือกจังหวัดนี้');

    // The plan is generated and opens by itself.
    await waitFor(
      tester,
      find.text('บันทึกทริป'),
      timeout: const Duration(seconds: 60),
    );
    expect(find.textContaining('ชลบุรี 2 วัน 1 คืน'), findsWidgets);
    expect(find.text('ราคาโดยประมาณ'), findsWidgets);

    // Save it.
    await tapText(tester, 'บันทึกทริป');
    await waitFor(tester, find.byTooltip('ตัวเลือกเพิ่มเติม'));
    expect(find.text('บันทึกแล้ว'), findsWidgets);

    // Back home, the trip is listed in My Trips and opens again.
    await tester.tap(find.byTooltip('กลับหน้าแรก'));
    await waitFor(tester, find.text('วางแผนทริปใหม่'));
    await tapText(tester, 'ทริปของฉัน');
    final card = find.text('ชลบุรี 2 วัน 1 คืน');
    await waitFor(tester, card);
    await tester.tap(card.first);
    await waitFor(tester, find.byTooltip('ตัวเลือกเพิ่มเติม'));

    // Delete it after confirming.
    await tester.tap(find.byTooltip('ตัวเลือกเพิ่มเติม'));
    await tester.pumpAndSettle();
    await tapText(tester, 'ลบทริป');
    await tester.tap(find.widgetWithText(FilledButton, 'ลบ'));
    await waitFor(tester, find.text('วางแผนทริปใหม่'));
    await tapText(tester, 'ทริปของฉัน');
    expect(find.text('ยังไม่มีทริป'), findsOneWidget);
    expect(find.text('ชลบุรี 2 วัน 1 คืน'), findsNothing);
  });
}
