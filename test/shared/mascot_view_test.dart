import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaya_app/shared/widgets/mascot_view.dart';

void main() {
  Widget host(Widget child, {bool still = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: still),
      child: Scaffold(body: Center(child: child)),
    ),
  );

  String shownAsset(WidgetTester tester) {
    final image = tester.widget<Image>(find.byType(Image)).image;
    return ((image as ResizeImage).imageProvider as AssetImage).assetName;
  }

  testWidgets('stands still when animations are off', (tester) async {
    await tester.pumpWidget(
      host(const MascotView(pose: MascotPose.wave), still: true),
    );
    await tester.pumpAndSettle();

    expect(tester.hasRunningAnimations, isFalse);
    expect(shownAsset(tester), 'assets/mascot/wave.webp');
  });

  testWidgets('floats for under five seconds, then rests', (tester) async {
    await tester.pumpWidget(host(const MascotView(pose: MascotPose.wave)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pump(const Duration(seconds: 5));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('floats again after changing pose', (tester) async {
    await tester.pumpWidget(host(const MascotView(pose: MascotPose.wave)));
    await tester.pumpAndSettle();

    await tester.pumpWidget(host(const MascotView(pose: MascotPose.map)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('switches pose', (tester) async {
    await tester.pumpWidget(
      host(const MascotView(pose: MascotPose.wave), still: true),
    );
    await tester.pumpWidget(
      host(const MascotView(pose: MascotPose.celebrate), still: true),
    );
    await tester.pumpAndSettle();

    expect(shownAsset(tester), 'assets/mascot/celebrate.webp');
  });

  testWidgets('never grows past the space it is given', (tester) async {
    await tester.pumpWidget(
      host(
        const SizedBox(
          width: 80,
          child: MascotView(pose: MascotPose.map, size: 200),
        ),
        still: true,
      ),
    );

    expect(tester.getSize(find.byType(Image)), const Size(80, 80));
  });

  testWidgets('is hidden from screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MascotView(pose: MascotPose.wave),
            MascotAvatar(),
          ],
        ),
        still: true,
      ),
    );

    for (final widget in [MascotView, MascotAvatar]) {
      final node = tester.getSemantics(find.byType(widget));
      expect(node.label, isEmpty);
      expect(node.childrenCount, 0);
    }
    semantics.dispose();
  });
}
