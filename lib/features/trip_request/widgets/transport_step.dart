import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../domain/domain.dart';
import '../trip_request_form_notifier.dart';
import 'step_section.dart';

/// Step ③: Intercity Transport (hidden for same-province trips) and Local
/// Transport Mode.
class TransportStep extends ConsumerWidget {
  const TransportStep({super.key});

  static const _intercityIcons = {
    IntercityMode.bus: Icons.directions_bus_outlined,
    IntercityMode.train: Icons.train_outlined,
    IntercityMode.car: Icons.directions_car_outlined,
  };

  static const _localIcons = {
    LocalTransportMode.rentalCar: Icons.car_rental_outlined,
    LocalTransportMode.rentalMotorbike: Icons.two_wheeler_outlined,
    LocalTransportMode.taxi: Icons.local_taxi_outlined,
    LocalTransportMode.publicTransport: Icons.directions_transit_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(tripRequestFormProvider);
    final notifier = ref.read(tripRequestFormProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (form.needsIntercity)
          StepSection(
            title: 'เดินทางไป–กลับ',
            subtitle: 'ระหว่างจุดเริ่มต้นกับจังหวัดที่ไป',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final mode in IntercityMode.values)
                  ChoiceChip(
                    showCheckmark: false,
                    avatar: Icon(_intercityIcons[mode]),
                    label: Text(mode.label),
                    selected: form.intercityMode == mode,
                    onSelected: (_) => notifier.setIntercityMode(mode),
                  ),
              ],
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.only(bottom: 32),
            child: Card.outlined(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('เที่ยวในจังหวัดเดียวกับจุดเริ่มต้น'),
                subtitle: Text('ไม่มีค่าเดินทางข้ามเมือง'),
              ),
            ),
          ),
        StepSection(
          title: 'เดินทางในพื้นที่',
          subtitle: 'ใช้ไปมาระหว่างที่เที่ยวในจังหวัด',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mode in LocalTransportMode.values)
                ChoiceChip(
                  showCheckmark: false,
                  avatar: Icon(_localIcons[mode]),
                  label: Text(mode.label),
                  selected: form.localTransportMode == mode,
                  onSelected: (_) => notifier.setLocalTransportMode(mode),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
