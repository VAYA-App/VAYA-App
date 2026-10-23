import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaya_app/app/app.dart';
import 'package:vaya_app/app/providers/data_providers.dart';
import 'package:vaya_app/app/providers/mock_providers.dart';
import 'package:vaya_app/app/providers/planner_providers.dart';
import 'package:vaya_app/app/router.dart';
import 'package:vaya_app/data/mock/mock_auth_repository.dart';
import 'package:vaya_app/domain/domain.dart';
import 'package:vaya_app/planner/destination_suggester.dart';
import 'package:vaya_app/planner/planner_service.dart';

import '../trip_request/form_test_helpers.dart';

class _FakeSuggester implements DestinationSuggester {
  _FakeSuggester(this.answer);

  /// Returns the suggestions, or throws when it is an error.
  Object answer;
  final requests = <TripRequest>[];

  @override
  Future<List<DestinationSuggestion>> suggest(TripRequest request) async {
    requests.add(request);
    if (answer case final List<DestinationSuggestion> list) return list;
    throw answer;
  }
}

/// Never reports progress, so the generating screen starts no timers.
class _IdlePlanner implements PlannerService {
  @override
  Stream<PlanningProgress> generate({
    required TripRequest request,
    required String destinationId,
  }) => const Stream.empty();
}

const _suggestions = [
  DestinationSuggestion(
    provinceId: 'chonburi',
    reason: 'ทะเลใกล้กรุงเทพฯ มีคาเฟ่ริมหาด',
    highlightTags: [PreferenceTag.beach, PreferenceTag.cafe],
    minimumCost: 4800,
  ),
  DestinationSuggestion(
    provinceId: 'bangkok',
    reason: 'คาเฟ่เยอะ เดินทางสะดวก',
    highlightTags: [PreferenceTag.cafe],
    minimumCost: 2100,
  ),
];

void main() {
  setUpAll(loadPromptFont);

  late ProviderContainer container;

  String location() => container
      .read(routerProvider)
      .routerDelegate
      .currentConfiguration
      .uri
      .toString();

  /// The suggestions resolve outside the fake clock; give them real time
  /// before settling.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  Future<_FakeSuggester> pumpSuggestions(
    WidgetTester tester, {
    Object answer = _suggestions,
    Size size = phone,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final suggester = _FakeSuggester(answer);
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          MockAuthRepository(initialUser: MockAuthRepository.demoUser),
        ),
        destinationSuggesterProvider.overrideWithValue(suggester),
        plannerServiceProvider.overrideWithValue(_IdlePlanner()),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      await container.read(placeCatalogProvider.future);
      await container.read(mockTripRequestProvider.future);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const VayaApp()),
    );
    container.read(routerProvider).go(AppRoutes.suggestions);
    await settle(tester);
    return suggester;
  }

  testWidgets('shows a card per province, the first one recommended', (
    tester,
  ) async {
    final suggester = await pumpSuggestions(tester);

    expect(find.text('ชลบุรี'), findsOneWidget);
    expect(find.text('กรุงเทพมหานคร'), findsOneWidget);
    expect(find.text('เลือกจังหวัดนี้'), findsNWidgets(2));
    expect(find.text('แนะนำ'), findsOneWidget);
    expect(find.text('ทะเลใกล้กรุงเทพฯ มีคาเฟ่ริมหาด'), findsOneWidget);
    expect(find.textContaining('เริ่มต้น ~฿4,800 · พ.ย.'), findsOneWidget);
    expect(find.text('ทะเล'), findsOneWidget);

    // Opened on its own: the demo request, with no Destination.
    expect(suggester.requests.single.destinationId, isNull);
  });

  testWidgets('choosing a province generates its plan', (tester) async {
    await pumpSuggestions(tester);

    await tester.tap(find.text('เลือกจังหวัดนี้').last);
    await tester.pumpAndSettle();

    expect(location(), '${AppRoutes.generating}?destination=bangkok');
  });

  testWidgets('no province fits: says so and offers to edit the trip', (
    tester,
  ) async {
    await pumpSuggestions(tester, answer: const <DestinationSuggestion>[]);

    expect(find.text('ยังไม่มีจังหวัดที่อยู่ในงบ'), findsOneWidget);
    await tester.tap(find.text('แก้ไขทริป'));
    await tester.pumpAndSettle();
    expect(location(), AppRoutes.newTrip);
  });

  testWidgets('an error offers to try again', (tester) async {
    final suggester = await pumpSuggestions(
      tester,
      answer: StateError('offline'),
    );

    expect(find.text('หาจังหวัดไม่สำเร็จ'), findsOneWidget);
    suggester.answer = _suggestions;
    await tester.tap(find.text('ลองใหม่'));
    await settle(tester);

    expect(find.text('เลือกจังหวัดนี้'), findsNWidgets(2));
  });

  testWidgets('expanded windows put the cards side by side', (tester) async {
    await pumpSuggestions(tester, size: tablet);

    Offset cardOf(String name) => tester.getTopLeft(
      find.ancestor(of: find.text(name), matching: find.byType(Card)),
    );
    final first = cardOf('ชลบุรี');
    final second = cardOf('กรุงเทพมหานคร');
    expect(second.dy, first.dy);
    expect(second.dx, greaterThan(first.dx));
  });

  for (final size in [const Size(360, 800), tablet]) {
    testWidgets('fits 200% text at ${size.width.toInt()} wide', (tester) async {
      await pumpSuggestions(tester, size: size, textScale: 2);
      expect(tester.takeException(), isNull);
    });
  }
}
