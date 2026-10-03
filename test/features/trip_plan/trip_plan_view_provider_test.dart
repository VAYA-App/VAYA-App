import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaya_app/app/providers/mock_providers.dart';
import 'package:vaya_app/features/trip_plan/trip_plan_view_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  test('opens a generated draft by the id it was given', () async {
    final plan = await container.read(mockTripPlanProvider.future);
    final request = await container.read(mockTripRequestProvider.future);

    final drafts = container.read(draftTripsProvider.notifier);
    final first = drafts.add(plan, request);
    final second = drafts.add(plan, request);
    expect(first, isNot(second));

    final view = await container.read(tripPlanViewProvider(first).future);
    expect(view?.plan, same(plan));
    expect(view?.request, same(request));
  });

  test('unknown trip ids open nothing', () async {
    expect(
      await container.read(tripPlanViewProvider('draft-99').future),
      isNull,
    );
  });

  test('the mock id still opens the bundled plan', () async {
    final view = await container.read(tripPlanViewProvider(mockTripId).future);
    expect(view?.destination.id, 'chonburi');
  });
}
