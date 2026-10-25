import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaya_app/shared/widgets/motion.dart';

import '../features/trip_request/form_test_helpers.dart';

void main() {
  Widget host(Widget child, {bool disableAnimations = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: child),
    ),
  );

  double opacityOf(WidgetTester tester, String text) => tester
      .widget<FadeTransition>(
        find
            .ancestor(
              of: find.text(text),
              matching: find.byType(FadeTransition),
            )
            .first,
      )
      .opacity
      .value;

  group('StaggeredEntrance', () {
    testWidgets('fades in one item after another', (tester) async {
      await tester.pumpWidget(
        host(
          const Column(
            children: [
              StaggeredEntrance(index: 0, child: Text('a')),
              StaggeredEntrance(index: 5, child: Text('b')),
            ],
          ),
        ),
      );
      expect(opacityOf(tester, 'a'), 0);

      await tester.pump(const Duration(milliseconds: 200));
      expect(opacityOf(tester, 'a'), greaterThan(0));
      expect(opacityOf(tester, 'b'), 0);

      await tester.pumpAndSettle();
      expect(opacityOf(tester, 'a'), 1);
      expect(opacityOf(tester, 'b'), 1);
    });

    testWidgets('shows at once when animations are off', (tester) async {
      await tester.pumpWidget(
        host(
          const StaggeredEntrance(index: 5, child: Text('a')),
          disableAnimations: true,
        ),
      );
      await tester.pump();
      expect(opacityOf(tester, 'a'), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('FadeThrough', () {
    testWidgets('fades the child in when the key changes', (tester) async {
      await tester.pumpWidget(
        host(const FadeThrough(switchKey: 0, child: Text('a'))),
      );
      expect(opacityOf(tester, 'a'), 1);

      await tester.pumpWidget(
        host(const FadeThrough(switchKey: 1, child: Text('a'))),
      );
      expect(opacityOf(tester, 'a'), 0);
      await tester.pumpAndSettle();
      expect(opacityOf(tester, 'a'), 1);
    });

    testWidgets('does not animate when animations are off', (tester) async {
      await tester.pumpWidget(
        host(
          const FadeThrough(switchKey: 0, child: Text('a')),
          disableAnimations: true,
        ),
      );
      await tester.pumpWidget(
        host(
          const FadeThrough(switchKey: 1, child: Text('a')),
          disableAnimations: true,
        ),
      );
      expect(opacityOf(tester, 'a'), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('SharedAxisSwitcher', () {
    Widget page(int step, {bool disableAnimations = false}) => host(
      SharedAxisSwitcher(
        forward: true,
        child: Text('step $step', key: ValueKey(step)),
      ),
      disableAnimations: disableAnimations,
    );

    testWidgets('keeps both pages while sliding, then only the new one', (
      tester,
    ) async {
      await tester.pumpWidget(page(1));
      await tester.pumpWidget(page(2));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('step 1'), findsOneWidget);
      expect(find.text('step 2'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('step 1'), findsNothing);
      expect(find.text('step 2'), findsOneWidget);
    });

    testWidgets('swaps at once when animations are off', (tester) async {
      await tester.pumpWidget(page(1, disableAnimations: true));
      await tester.pumpWidget(page(2, disableAnimations: true));
      await tester.pump();
      expect(find.text('step 1'), findsNothing);
      expect(find.text('step 2'), findsOneWidget);
    });
  });

  group('CountUp', () {
    testWidgets('counts up to the value and reads it out whole', (
      tester,
    ) async {
      await tester.pumpWidget(host(const CountUp(value: 3920, format: _baht)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('฿3920'), findsNothing);
      expect(find.bySemanticsLabel('฿3920'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('฿3920'), findsOneWidget);
    });

    testWidgets('shows the value at once when animations are off', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const CountUp(value: 3920, format: _baht),
          disableAnimations: true,
        ),
      );
      await tester.pump();
      expect(find.text('฿3920'), findsOneWidget);
    });
  });

  group('Skeleton', () {
    testWidgets('pulses while loading', (tester) async {
      await tester.pumpWidget(host(const Skeleton(height: 40)));
      final fade = tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(Skeleton),
          matching: find.byType(FadeTransition),
        ),
      );
      final before = fade.opacity.value;
      await tester.pump(const Duration(milliseconds: 300));
      expect(fade.opacity.value, isNot(before));
    });

    testWidgets('stays still when animations are off', (tester) async {
      await tester.pumpWidget(
        host(const Skeleton(height: 40), disableAnimations: true),
      );
      // Nothing is scheduled, so settling finishes at once.
      await tester.pumpAndSettle();
      expect(find.byType(Skeleton), findsOneWidget);
    });
  });

  testWidgets('traveller +/- gives a selection click', (tester) async {
    final calls = <String?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          calls.add(call.arguments as String?);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpForm(tester);
    await tester.tap(find.byTooltip('เพิ่มจำนวนผู้เดินทาง'));
    await tester.pump();
    await tester.tap(find.byTooltip('ลดจำนวนผู้เดินทาง'));
    await tester.pumpAndSettle();

    expect(calls, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick',
    ]);
  });
}

String _baht(int v) => '฿$v';
