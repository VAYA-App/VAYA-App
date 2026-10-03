import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaya_app/app/app.dart';
import 'package:vaya_app/app/providers/data_providers.dart';
import 'package:vaya_app/app/router.dart';
import 'package:vaya_app/domain/domain.dart';
import 'package:vaya_app/features/explore/trip_ideas.dart';
import 'package:vaya_app/features/trip_request/trip_request_form_notifier.dart';
import 'package:vaya_app/features/trip_request/trip_request_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every idea points at real places in its province', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final catalog = await container.read(placeCatalogProvider.future);
    final ideas = await container.read(tripIdeasProvider.future);

    expect(ideas, isNotEmpty);
    expect(ideas.map((i) => i.id).toSet(), hasLength(ideas.length));
    for (final idea in ideas) {
      expect(catalog.findProvince(idea.provinceId), isNotNull, reason: idea.id);
      expect(idea.tags, isNotEmpty, reason: idea.id);
      for (final id in idea.placeIds) {
        expect(catalog.findPlace(id)?.provinceId, idea.provinceId, reason: id);
      }
    }
  });

  testWidgets('tapping an idea opens the form with it picked', (tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    late List<TripIdea> ideas;
    await tester.runAsync(() async {
      await container.read(placeCatalogProvider.future);
      ideas = await container.read(tripIdeasProvider.future);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const VayaApp()),
    );
    container.read(routerProvider).go(AppRoutes.explore);
    await tester.pumpAndSettle();

    final idea = ideas.last;
    final tile = find.widgetWithText(ListTile, idea.title);
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      ),
    );
    // Keep the tile clear of the bottom navigation bar.
    await tester.ensureVisible(tile);
    await tester.drag(
      find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      ),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();

    // `push` keeps the shell's location, so look for the screen itself.
    expect(find.byType(TripRequestScreen), findsOneWidget);
    expect(find.textContaining(idea.title), findsOneWidget); // snack bar
    final form = container.read(tripRequestFormProvider);
    expect(form.destinationId, idea.provinceId);
    expect(form.preferenceTags, idea.tags.toSet());
  });

  test('starting from an idea clears what was typed before', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final form = container.read(tripRequestFormProvider.notifier)
      ..setBudget(9000)
      ..toggleTag(PreferenceTag.nightlife);

    form.startWith(destinationId: 'bangkok', tags: [PreferenceTag.cafe]);

    final state = container.read(tripRequestFormProvider);
    expect(state.budget, isNull);
    expect(state.destinationId, 'bangkok');
    expect(state.preferenceTags, {PreferenceTag.cafe});
  });
}
