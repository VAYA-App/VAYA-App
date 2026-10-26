import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../domain/domain.dart';
import '../trip_request_form_notifier.dart';
import 'form_section.dart';

/// Preference Tags and the Free-text Note, on step ③ of the form.
class StyleSection extends ConsumerStatefulWidget {
  const StyleSection({super.key});

  @override
  ConsumerState<StyleSection> createState() => _StyleSectionState();
}

class _StyleSectionState extends ConsumerState<StyleSection> {
  late final _note = TextEditingController(
    text: ref.read(tripRequestFormProvider).note,
  );

  static const _tagIcons = {
    PreferenceTag.nature: Icons.forest_outlined,
    PreferenceTag.beach: Icons.beach_access_outlined,
    PreferenceTag.cafe: Icons.local_cafe_outlined,
    PreferenceTag.templeHistory: Icons.temple_buddhist_outlined,
    PreferenceTag.artCulture: Icons.palette_outlined,
    PreferenceTag.localFood: Icons.ramen_dining_outlined,
    PreferenceTag.seafood: Icons.set_meal_outlined,
    PreferenceTag.shopping: Icons.shopping_bag_outlined,
    PreferenceTag.nightlife: Icons.nightlife_outlined,
    PreferenceTag.viewpoint: Icons.landscape_outlined,
    PreferenceTag.family: Icons.family_restroom_outlined,
    PreferenceTag.wellness: Icons.self_improvement_outlined,
    PreferenceTag.adventure: Icons.kayaking_outlined,
  };

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(tripRequestFormProvider);
    final notifier = ref.read(tripRequestFormProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormSection(
          icon: Icons.favorite_border,
          title: 'สไตล์ที่ชอบ',
          subtitle: 'เลือกได้หลายอย่าง',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in PreferenceTag.values)
                FilterChip(
                  avatar: Icon(_tagIcons[tag]),
                  label: Text(tag.label),
                  showCheckmark: false,
                  selected: form.preferenceTags.contains(tag),
                  onSelected: (_) => notifier.toggleTag(tag),
                ),
            ],
          ),
        ),
        FormSection(
          icon: Icons.edit_note,
          title: 'ความต้องการเพิ่มเติม',
          subtitle: 'ไม่บังคับ AI จะนำไปใช้ตอนเลือกสถานที่',
          child: TextField(
            controller: _note,
            minLines: 3,
            maxLines: 5,
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
