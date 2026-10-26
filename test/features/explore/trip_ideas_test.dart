import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaya_app/app/providers/data_providers.dart';
import 'package:vaya_app/domain/domain.dart';
import 'package:vaya_app/features/explore/trip_ideas.dart';
import 'package:vaya_app/features/trip_request/trip_request_form_notifier.dart';

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
