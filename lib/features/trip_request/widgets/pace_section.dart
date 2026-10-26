import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../domain/domain.dart';
import '../trip_request_form_notifier.dart';
import 'form_section.dart';
import 'option_card.dart';

/// Pace, on step ② of the form.
class PaceSection extends ConsumerWidget {
  const PaceSection({super.key});

  static const _paces = {
    Pace.chill: (Icons.spa_outlined, '2 ที่ / วัน'),
    Pace.normal: (Icons.directions_walk, '3 ที่ / วัน'),
    Pace.packed: (Icons.bolt_outlined, '4–5 ที่ / วัน'),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(tripRequestFormProvider);
    final notifier = ref.read(tripRequestFormProvider.notifier);

    return FormSection(
      icon: Icons.speed_outlined,
      title: 'จังหวะการเที่ยว',
      child: OptionGrid(
        columns: 3,
        children: [
          for (final MapEntry(key: pace, value: (icon, caption))
              in _paces.entries)
            OptionCard(
              vertical: true,
              icon: icon,
              label: pace.label,
              caption: caption,
              selected: form.pace == pace,
              onTap: () => notifier.setPace(pace),
            ),
        ],
      ),
    );
  }
}
