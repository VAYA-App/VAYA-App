import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/domain.dart';

/// The four steps of the trip request form (#18).
enum TripRequestStep {
  datesAndTravellers('วันที่และจำนวนคน'),
  budgetAndPlaces('งบและจุดหมาย'),
  transport('การเดินทาง'),
  preferences('สไตล์การเที่ยว');

  const TripRequestStep(this.label);
  final String label;
}

/// Everything the user has typed so far. Fields stay nullable until the
/// user fills them; [TripRequestFormNotifier.submit] turns them into a
/// valid [TripRequest].
final class TripRequestFormState {
  const TripRequestFormState({
    this.step = TripRequestStep.datesAndTravellers,
    this.startDate,
    this.endDate,
    this.travellerCount = 2,
    this.budget,
    this.originId = 'bangkok',
    this.destinationId,
    this.intercityMode = IntercityMode.bus,
    this.localTransportMode = LocalTransportMode.taxi,
    this.preferenceTags = const {},
    this.pace = Pace.normal,
    this.note = '',
  });

  final TripRequestStep step;
  final DateTime? startDate;
  final DateTime? endDate;
  final int travellerCount;
  final int? budget;
  final String originId;

  /// `null` means "let the AI choose".
  final String? destinationId;
  final IntercityMode intercityMode;
  final LocalTransportMode localTransportMode;
  final Set<PreferenceTag> preferenceTags;
  final Pace pace;
  final String note;

  bool get isFirstStep => step == TripRequestStep.values.first;
  bool get isLastStep => step == TripRequestStep.values.last;

  TripRequestFormState copyWith({
    TripRequestStep? step,
    DateTime? startDate,
    DateTime? endDate,
    int? travellerCount,
    int? Function()? budget,
    String? originId,
    String? Function()? destinationId,
    IntercityMode? intercityMode,
    LocalTransportMode? localTransportMode,
    Set<PreferenceTag>? preferenceTags,
    Pace? pace,
    String? note,
  }) => TripRequestFormState(
    step: step ?? this.step,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    travellerCount: travellerCount ?? this.travellerCount,
    budget: budget != null ? budget() : this.budget,
    originId: originId ?? this.originId,
    destinationId: destinationId != null ? destinationId() : this.destinationId,
    intercityMode: intercityMode ?? this.intercityMode,
    localTransportMode: localTransportMode ?? this.localTransportMode,
    preferenceTags: preferenceTags ?? this.preferenceTags,
    pace: pace ?? this.pace,
    note: note ?? this.note,
  );
}

/// Form state for the trip request flow. Kept alive across the suggestion
/// and generating screens so going back never loses what was typed.
final tripRequestFormProvider =
    NotifierProvider<TripRequestFormNotifier, TripRequestFormState>(
      TripRequestFormNotifier.new,
    );

class TripRequestFormNotifier extends Notifier<TripRequestFormState> {
  @override
  TripRequestFormState build() => const TripRequestFormState();

  void setDates(DateTime start, DateTime end) =>
      state = state.copyWith(startDate: _day(start), endDate: _day(end));

  void setTravellerCount(int count) =>
      state = state.copyWith(travellerCount: count);

  void setBudget(int? budget) => state = state.copyWith(budget: () => budget);

  void setOrigin(String originId) => state = state.copyWith(originId: originId);

  void setDestination(String? destinationId) =>
      state = state.copyWith(destinationId: () => destinationId);

  void setIntercityMode(IntercityMode mode) =>
      state = state.copyWith(intercityMode: mode);

  void setLocalTransportMode(LocalTransportMode mode) =>
      state = state.copyWith(localTransportMode: mode);

  void toggleTag(PreferenceTag tag) {
    final tags = {...state.preferenceTags};
    if (!tags.remove(tag)) tags.add(tag);
    state = state.copyWith(preferenceTags: tags);
  }

  void setPace(Pace pace) => state = state.copyWith(pace: pace);

  void setNote(String note) => state = state.copyWith(note: note);

  void next() {
    if (state.isLastStep) return;
    state = state.copyWith(step: TripRequestStep.values[state.step.index + 1]);
  }

  void back() {
    if (state.isFirstStep) return;
    state = state.copyWith(step: TripRequestStep.values[state.step.index - 1]);
  }

  void reset() => state = const TripRequestFormState();

  /// The request built from the current values.
  TripRequest submit() {
    final s = state;
    return TripRequest(
      startDate: s.startDate!,
      endDate: s.endDate!,
      travellerCount: s.travellerCount,
      budget: s.budget!,
      originId: s.originId,
      destinationId: s.destinationId,
      intercityMode: s.intercityMode,
      localTransportMode: s.localTransportMode,
      preferenceTags: s.preferenceTags,
      pace: s.pace,
      note: s.note.trim(),
    );
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
}
