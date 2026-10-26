import 'package:flutter_test/flutter_test.dart';
import 'package:vaya_app/features/trip_request/trip_request_form_notifier.dart';
import 'package:vaya_app/shared/widgets/mascot_view.dart';

import 'form_test_helpers.dart';

void main() {
  MascotPose shownPose(WidgetTester tester) =>
      tester.widget<MascotView>(find.byType(MascotView)).pose;

  testWidgets('the mascot acts out each step', (tester) async {
    final container = await pumpForm(tester);
    expect(shownPose(tester), MascotPose.calendar);

    for (final (step, pose) in [
      (TripRequestStep.budgetAndPace, MascotPose.budget),
      (TripRequestStep.style, MascotPose.wave),
    ]) {
      // Jump straight to the step; filling every field is covered elsewhere.
      container.read(tripRequestFormProvider.notifier).state = container
          .read(tripRequestFormProvider)
          .copyWith(step: step);
      await tester.pumpAndSettle();
      expect(shownPose(tester), pose, reason: step.name);
    }
  });

  testWidgets('large text on a phone leaves the room to the question', (
    tester,
  ) async {
    await pumpForm(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();

    expect(find.byType(MascotView), findsNothing);
  });

  testWidgets('large text on a tablet still shows the mascot', (tester) async {
    await pumpForm(tester, size: tablet);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();

    expect(find.byType(MascotView), findsOneWidget);
  });
}
