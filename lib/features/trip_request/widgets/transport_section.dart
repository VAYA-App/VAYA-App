import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../domain/domain.dart';
import '../trip_request_form_notifier.dart';
import 'form_section.dart';
import 'option_card.dart';

/// Intercity Transport (hidden for same-province trips) and Local
/// Transport Mode, on step ② of the form.
class TransportSection extends ConsumerWidget {
  const TransportSection({super.key});

  static const _intercity = {
    IntercityMode.bus: (Icons.directions_bus_outlined, 'สะดวก ราคาประหยัด'),
    IntercityMode.train: (Icons.train_outlined, 'ชมวิวระหว่างทาง'),
    IntercityMode.car: (Icons.directions_car_outlined, 'แวะได้ตามใจ'),
  };

  static const _local = {
    LocalTransportMode.rentalCar: (
      Icons.car_rental_outlined,
      'ขับเองได้ทุกที่',
    ),
    LocalTransportMode.rentalMotorbike: (
      Icons.two_wheeler_outlined,
      'คล่องตัว ประหยัด',
    ),
    LocalTransportMode.taxi: (
      Icons.local_taxi_outlined,
      'เรียกง่าย ไม่ต้องขับ',
    ),
    LocalTransportMode.publicTransport: (
      Icons.directions_transit_outlined,
      'ถูกที่สุด',
    ),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final form = ref.watch(tripRequestFormProvider);
    final notifier = ref.read(tripRequestFormProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (form.needsIntercity)
          FormSection(
            icon: Icons.route_outlined,
            title: 'เดินทางไป–กลับ',
            subtitle: 'ระหว่างจุดเริ่มต้นกับจังหวัดที่ไป',
            child: OptionGrid(
              children: [
                for (final MapEntry(key: mode, value: (icon, caption))
                    in _intercity.entries)
                  OptionCard(
                    icon: icon,
                    label: mode.label,
                    caption: caption,
                    selected: form.intercityMode == mode,
                    onTap: () => notifier.setIntercityMode(mode),
                  ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Card(
              color: colors.secondaryContainer,
              child: ListTile(
                leading: Icon(Icons.info_outline, color: colors.primary),
                title: const Text('เที่ยวในจังหวัดเดียวกับจุดเริ่มต้น'),
                subtitle: const Text('ไม่มีค่าเดินทางข้ามเมือง'),
              ),
            ),
          ),
        FormSection(
          icon: Icons.near_me_outlined,
          title: 'เดินทางในพื้นที่',
          subtitle: 'ใช้ไปมาระหว่างที่เที่ยวในจังหวัด',
          child: OptionGrid(
            children: [
              for (final MapEntry(key: mode, value: (icon, caption))
                  in _local.entries)
                OptionCard(
                  icon: icon,
                  label: mode.label,
                  caption: caption,
                  selected: form.localTransportMode == mode,
                  onTap: () => notifier.setLocalTransportMode(mode),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
