import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaya_app/app/app.dart';
import 'package:vaya_app/app/providers/data_providers.dart';
import 'package:vaya_app/app/providers/planner_providers.dart';
import 'package:vaya_app/app/router.dart';
import 'package:vaya_app/data/mock/mock_auth_repository.dart';
import 'package:vaya_app/domain/domain.dart';
import 'package:vaya_app/features/trip_request/trip_request_form_notifier.dart';
import 'package:vaya_app/features/trip_request/widgets/option_card.dart';
import 'package:vaya_app/planner/planner_service.dart';

/// Never reports progress, so the generating screen starts no timers.
class _IdlePlanner implements PlannerService {
  @override
  Stream<PlanningProgress> generate({
    required TripRequest request,
    required String destinationId,
  }) => const Stream.empty();
}

const phone = Size(412, 900);
const tablet = Size(1280, 800);

Future<ProviderContainer> pumpForm(
  WidgetTester tester, {
  Size size = phone,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(
        MockAuthRepository(initialUser: MockAuthRepository.demoUser),
      ),
      todayProvider.overrideWithValue(DateTime(2026, 11, 1)),
      plannerServiceProvider.overrideWithValue(_IdlePlanner()),
    ],
  );
  addTearDown(container.dispose);
  await tester.runAsync(() => container.read(placeCatalogProvider.future));
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const VayaApp()),
  );
  container.read(routerProvider).go(AppRoutes.newTrip);
  await tester.pumpAndSettle();
  return container;
}

String location(ProviderContainer c) =>
    c.read(routerProvider).routerDelegate.currentConfiguration.uri.toString();

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

/// Taps the destination card, not the origin chip with the same name.
Future<void> chooseDestination(WidgetTester tester, String name) async {
  final card = find.widgetWithText(OptionCard, name);
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  await tester.tap(card);
  await tester.pumpAndSettle();
}

Future<void> next(WidgetTester tester) => tapText(tester, 'ถัดไป');

Future<void> pickDates(WidgetTester tester) async {
  await tapText(tester, 'เลือกวันไป–กลับ');
  // The range picker opens on November 2026 (today is 1 Nov).
  for (final label in ['14', '15']) {
    await tester.tap(find.text(label).first);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('ตกลง'));
  await tester.pumpAndSettle();
}

/// The default test font draws every glyph as a wide box, which overflows
/// the date picker header; real metrics need the app's font.
Future<void> loadPromptFont() async {
  final loader = FontLoader('Prompt');
  for (final w in ['Light', 'Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(
      File(
        'assets/fonts/Prompt-$w.ttf',
      ).readAsBytes().then(ByteData.sublistView),
    );
  }
  await loader.load();
}
