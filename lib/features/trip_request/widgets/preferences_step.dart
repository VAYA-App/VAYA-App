import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../domain/domain.dart';
import '../trip_request_form_notifier.dart';
import 'step_section.dart';

/// Step ④: Preference Tags, Pace and the Free-text Note.
class PreferencesStep extends ConsumerStatefulWidget {
  const PreferencesStep({super.key});

  @override
  ConsumerState<PreferencesStep> createState() => _PreferencesStepState();
}

class _PreferencesStepState extends ConsumerState<PreferencesStep> {
  late final _note = TextEditingController(
    text: ref.read(tripRequestFormProvider).note,
  );

  static const _paceHints = {
    Pace.chill: 'ประมาณ 2 ที่ต่อวัน มีเวลาพักเยอะ',
    Pace.normal: 'ประมาณ 3 ที่ต่อวัน',
    Pace.packed: '4–5 ที่ต่อวัน เที่ยวให้คุ้ม',
  };

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final form = ref.watch(tripRequestFormProvider);
    final notifier = ref.read(tripRequestFormProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StepSection(
          title: 'สไตล์ที่ชอบ',
          subtitle: 'เลือกได้หลายอย่าง',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in PreferenceTag.values)
                FilterChip(
                  label: Text(tag.label),
                  selected: form.preferenceTags.contains(tag),
                  onSelected: (_) => notifier.toggleTag(tag),
                ),
            ],
          ),
        ),
        StepSection(
          title: 'จังหวะการเที่ยว',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<Pace>(
                segments: [
                  for (final pace in Pace.values)
                    ButtonSegment(value: pace, label: Text(pace.label)),
                ],
                selected: {form.pace},
                showSelectedIcon: false,
                onSelectionChanged: (selection) =>
                    notifier.setPace(selection.single),
              ),
              const SizedBox(height: 8),
              Text(
                _paceHints[form.pace]!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        StepSection(
          title: 'ความต้องการเพิ่มเติม',
          subtitle: 'ไม่บังคับ AI จะนำไปใช้ตอนเลือกสถานที่',
          child: TextField(
            controller: _note,
            minLines: 2,
            maxLines: 4,
            maxLength: TripRequestFormState.maxNoteLength,
            decoration: const InputDecoration(
              hintText: 'เช่น ไปกับผู้สูงอายุ ไม่อยากเดินเยอะ ไม่ทานเผ็ด',
            ),
            onChanged: notifier.setNote,
          ),
        ),
      ],
    );
  }
}
