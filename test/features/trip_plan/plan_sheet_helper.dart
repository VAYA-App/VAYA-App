import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// On a phone the plan rides in a sheet over the map (#182). Drags it all
/// the way up so the timeline scrolls like a normal list; does nothing on
/// wide windows, which have no sheet.
Future<void> openPlanSheet(WidgetTester tester) async {
  final sheet = find.byType(DraggableScrollableSheet);
  if (sheet.evaluate().isEmpty) return;
  await tester.drag(sheet, const Offset(0, -2000));
  await tester.pumpAndSettle();
}
