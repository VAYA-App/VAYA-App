import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaya_app/domain/domain.dart';
import 'package:vaya_app/features/trip_request/trip_request_form_notifier.dart';

final today = DateTime(2026, 11, 1);

ProviderContainer makeContainer() {
  final container = ProviderContainer(
    overrides: [todayProvider.overrideWithValue(today)],
  );
  addTearDown(container.dispose);
  return container;
}

void fillValidForm(TripRequestFormNotifier form) {
  form
    ..setDates(DateTime(2026, 11, 14), DateTime(2026, 11, 15))
    ..setTravellerCount(2)
    ..setBudget(6000)
    ..toggleTag(PreferenceTag.beach)
    ..toggleTag(PreferenceTag.cafe)
    ..setPace(Pace.chill);
}

void main() {
  late ProviderContainer container;
  late TripRequestFormNotifier form;
  TripRequestFormState state() => container.read(tripRequestFormProvider);
  String? errorFor(TripRequestStep step) =>
      state().errorFor(step, today: today);

  setUp(() {
    container = makeContainer();
    form = container.read(tripRequestFormProvider.notifier);
  });

  group('dates and travellers', () {
    test('requires both dates', () {
      expect(
        errorFor(TripRequestStep.datesAndTravellers),
        'เลือกวันไปและวันกลับ',
      );
    });

    test('rejects past dates, reversed ranges and trips over 7 days', () {
      form.setDates(DateTime(2026, 10, 30), DateTime(2026, 11, 2));
      expect(
        errorFor(TripRequestStep.datesAndTravellers),
        contains('ผ่านมาแล้ว'),
      );

      form.setDates(DateTime(2026, 11, 10), DateTime(2026, 11, 9));
      expect(
        errorFor(TripRequestStep.datesAndTravellers),
        contains('ก่อนวันไป'),
      );

      form.setDates(DateTime(2026, 11, 10), DateTime(2026, 11, 17));
      expect(errorFor(TripRequestStep.datesAndTravellers), contains('7 วัน'));

      form.setDates(DateTime(2026, 11, 10), DateTime(2026, 11, 16));
      expect(errorFor(TripRequestStep.datesAndTravellers), isNull);
    });

    test('allows 1 to 10 travellers', () {
      form.setDates(DateTime(2026, 11, 10), DateTime(2026, 11, 10));
      form.setTravellerCount(0);
      expect(errorFor(TripRequestStep.datesAndTravellers), isNotNull);
      form.setTravellerCount(11);
      expect(errorFor(TripRequestStep.datesAndTravellers), isNotNull);
      form.setTravellerCount(10);
      expect(errorFor(TripRequestStep.datesAndTravellers), isNull);
    });
  });

  test('budget must be positive and at most one million', () {
    expect(errorFor(TripRequestStep.budgetAndPlaces), 'กรอกงบรวมของทริป');
    form.setBudget(0);
    expect(errorFor(TripRequestStep.budgetAndPlaces), isNotNull);
    form.setBudget(1000001);
    expect(errorFor(TripRequestStep.budgetAndPlaces), isNotNull);
    form.setBudget(6000);
    expect(errorFor(TripRequestStep.budgetAndPlaces), isNull);
  });

  test('preferences need a tag and a short note', () {
    expect(errorFor(TripRequestStep.preferences), contains('อย่างน้อย 1'));
    form.toggleTag(PreferenceTag.beach);
    expect(errorFor(TripRequestStep.preferences), isNull);
    form.setNote('ก' * 301);
    expect(errorFor(TripRequestStep.preferences), contains('300'));
  });

  test('toggling a tag twice removes it', () {
    form
      ..toggleTag(PreferenceTag.nature)
      ..toggleTag(PreferenceTag.nature);
    expect(state().preferenceTags, isEmpty);
  });

  test('next stays on an incomplete step and back keeps the values', () {
    form.next();
    expect(state().step, TripRequestStep.datesAndTravellers);

    form.setDates(DateTime(2026, 11, 14), DateTime(2026, 11, 15));
    form.next();
    expect(state().step, TripRequestStep.budgetAndPlaces);

    form.setBudget(6000);
    form.back();
    expect(state().step, TripRequestStep.datesAndTravellers);
    expect(state().budget, 6000);
  });

  group('intercity choice', () {
    test('is needed when the AI chooses or the trip leaves the origin', () {
      expect(state().needsIntercity, isTrue);
      form.setDestination('chonburi');
      expect(state().needsIntercity, isTrue);
    });

    test('is dropped for a Bangkok to Bangkok trip', () {
      fillValidForm(form);
      form
        ..setOrigin('bangkok')
        ..setDestination('bangkok');

      expect(state().needsIntercity, isFalse);
      expect(form.submit().intercityMode, isNull);
    });
  });

  test('submit builds the demo trip request', () {
    fillValidForm(form);
    form.setNote('  อยากได้คาเฟ่วิวทะเล  ');

    final request = form.submit();

    expect(request.dayCount, 2);
    expect(request.travellerCount, 2);
    expect(request.budget, 6000);
    expect(request.originId, 'bangkok');
    expect(request.destinationId, isNull);
    expect(request.intercityMode, IntercityMode.bus);
    expect(request.preferenceTags, {PreferenceTag.beach, PreferenceTag.cafe});
    expect(request.pace, Pace.chill);
    expect(request.note, 'อยากได้คาเฟ่วิวทะเล');
  });

  test('submit refuses an incomplete form', () {
    expect(form.submit, throwsStateError);
  });
}
