import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/providers/data_providers.dart';
import '../../../domain/domain.dart';
import '../../../shared/formatters.dart';
import '../trip_request_form_notifier.dart';
import 'step_section.dart';

/// Step ②: total Budget, Origin and an optional Destination.
class BudgetStep extends ConsumerStatefulWidget {
  const BudgetStep({super.key});

  @override
  ConsumerState<BudgetStep> createState() => _BudgetStepState();
}

class _BudgetStepState extends ConsumerState<BudgetStep> {
  /// DropdownMenu cannot select `null`, so "let the AI choose" uses this.
  static const _aiChooses = '';

  late final _budget = TextEditingController(
    text: ref.read(tripRequestFormProvider).budget?.toString() ?? '',
  );

  @override
  void dispose() {
    _budget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final form = ref.watch(tripRequestFormProvider);
    final notifier = ref.read(tripRequestFormProvider.notifier);
    final catalog = ref.watch(placeCatalogProvider);
    final budget = form.budget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StepSection(
          title: 'งบรวมของทริป',
          subtitle: 'รวมทุกคน ทั้งค่าเดินทาง ที่พัก อาหาร และค่าเข้าชม',
          child: TextField(
            controller: _budget,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'งบรวม (บาท)',
              prefixText: '฿ ',
              helperText: budget != null && budget > 0
                  ? 'เฉลี่ยคนละ ${formatBaht((budget / form.travellerCount).round())}'
                  : null,
            ),
            onChanged: (value) => notifier.setBudget(int.tryParse(value)),
          ),
        ),
        StepSection(
          title: 'เส้นทาง',
          child: switch (catalog) {
            AsyncData(:final value) => _PlacesFields(
              provinces: value.provinces,
              form: form,
              notifier: notifier,
            ),
            AsyncError() => Text(
              'โหลดรายชื่อจังหวัดไม่สำเร็จ',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            _ => const LinearProgressIndicator(),
          },
        ),
      ],
    );
  }
}

class _PlacesFields extends StatelessWidget {
  const _PlacesFields({
    required this.provinces,
    required this.form,
    required this.notifier,
  });

  final List<Province> provinces;
  final TripRequestFormState form;
  final TripRequestFormNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = [
      for (final p in provinces) DropdownMenuEntry(value: p.id, label: p.name),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownMenu<String>(
          expandedInsets: EdgeInsets.zero,
          label: const Text('ออกเดินทางจาก'),
          leadingIcon: const Icon(Icons.trip_origin),
          initialSelection: form.originId,
          dropdownMenuEntries: entries,
          onSelected: (id) {
            if (id != null) notifier.setOrigin(id);
          },
        ),
        const SizedBox(height: 16),
        DropdownMenu<String>(
          expandedInsets: EdgeInsets.zero,
          label: const Text('ไปที่'),
          leadingIcon: const Icon(Icons.place_outlined),
          initialSelection: form.destinationId ?? _BudgetStepState._aiChooses,
          dropdownMenuEntries: [
            const DropdownMenuEntry(
              value: _BudgetStepState._aiChooses,
              label: 'ให้ AI เลือกให้',
              leadingIcon: Icon(Icons.auto_awesome_outlined),
            ),
            ...entries,
          ],
          onSelected: (id) => notifier.setDestination(
            id == null || id == _BudgetStepState._aiChooses ? null : id,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          form.destinationId == null
              ? 'ระบบจะเสนอจังหวัดที่เหมาะกับงบและสไตล์ให้เลือก'
              : 'ระบบจะสร้างแผนสำหรับจังหวัดนี้ทันที',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
