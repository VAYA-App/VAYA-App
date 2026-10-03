import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaya_app/features/assistant/assistant_screen.dart';
import 'package:vaya_app/shared/widgets/mascot_view.dart';

void main() {
  Future<void> pumpChat(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: AssistantScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('says the chat is a preview and shows the mascot', (
    tester,
  ) async {
    await pumpChat(tester);

    expect(find.textContaining('ตัวอย่างบทสนทนา'), findsOneWidget);
    expect(find.text('วันที่ 2 ขอร้านอาหารทะเลแทนได้ไหม'), findsOneWidget);
    expect(find.byType(MascotAvatar), findsWidgets);
  });

  testWidgets('answers what the user types with a coming-soon reply', (
    tester,
  ) async {
    await pumpChat(tester);
    final replies = find.textContaining('ยังเป็นตัวอย่างอยู่');
    expect(replies, findsNothing);

    await tester.enterText(find.byType(TextField), 'อยากไปเขาใหญ่');
    await tester.tap(find.byTooltip('ส่ง'));
    await tester.pumpAndSettle();

    expect(find.text('อยากไปเขาใหญ่'), findsOneWidget);
    expect(replies, findsOneWidget);
  });

  testWidgets('a suggestion chip sends itself', (tester) async {
    await pumpChat(tester);

    final chip = find.widgetWithText(ActionChip, 'ลดงบวันที่ 2 หน่อย');
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();

    // Once as the chip, once as the sent message.
    expect(find.text('ลดงบวันที่ 2 หน่อย'), findsNWidgets(2));
  });
}
