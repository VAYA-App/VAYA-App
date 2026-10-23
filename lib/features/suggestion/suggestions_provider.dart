import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/data_providers.dart';
import '../../app/providers/mock_providers.dart';
import '../../app/providers/planner_providers.dart';
import '../../domain/domain.dart';
import '../trip_request/trip_request_form_notifier.dart';

/// What the suggestion screen shows: the provinces that fit, best first.
typedef SuggestionsView = ({
  TripRequest request,
  List<DestinationSuggestion> suggestions,
  PlaceCatalog catalog,
});

/// Suggestions for the submitted form, or for the demo request without a
/// Destination when the screen is opened on its own (#23).
final suggestionsProvider = FutureProvider.autoDispose<SuggestionsView>((
  ref,
) async {
  final catalog = await ref.watch(placeCatalogProvider.future);
  final suggester = ref.watch(destinationSuggesterProvider);
  TripRequest request;
  try {
    request = ref.read(tripRequestFormProvider.notifier).submit();
  } on StateError {
    final demo = await ref.watch(mockTripRequestProvider.future);
    request = demo.copyWith(destinationId: () => null);
  }
  return (
    request: request,
    suggestions: await suggester.suggest(request),
    catalog: catalog,
  );
});
