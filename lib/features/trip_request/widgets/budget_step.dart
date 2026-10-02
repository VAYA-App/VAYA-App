import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/providers/data_providers.dart';
import '../../../domain/domain.dart';
import '../../../shared/formatters.dart';
import '../trip_request_form_notifier.dart';
import 'form_section.dart';
import 'option_card.dart';

/// Step ②: total Budget, Origin and an optional Destination.
class BudgetStep extends ConsumerStatefulWidget {
  const BudgetStep({super.key});

  @override
  ConsumerState<BudgetStep> createState() => _BudgetStepState();
}

class _BudgetStepState extends ConsumerState<BudgetStep> {
  static const _sliderMin = 1000.0;
  static const _sliderMax = 50000.0;

  late final _budget = TextEditingController(
    text: ref.read(tripRequestFormProvider).budget?.toString() ?? '',
  );

  @override
  void dispose() {
    _budget.dispose();
    super.dispose();
  }

  void _setFromSlider(double value) {
    final budget = value.round();
    _budget.text = '$budget';
    ref.read(tripRequestFormProvider.notifier).setBudget(budget);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final form = ref.watch(tripRequestFormProvider);
    final notifier = ref.read(tripRequestFormProvider.notifier);
    final budget = form.budget;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormSection(
          icon: Icons.payments_outlined,
          title: 'งบรวมทั้งทริป',
          subtitle: 'รวมทุกคน ทั้งค่าเดินทาง ที่พัก อาหาร และค่าเข้าชม',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _budget,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: theme.textTheme.headlineMedium,
                      decoration: const InputDecoration(
                        hintText: '0',
                        suffixText: 'บาท',
                        semanticCounterText: 'งบรวม',
                      ),
                      onChanged: (value) =>
                          notifier.setBudget(int.tryParse(value)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (budget != null && budget > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('เฉลี่ยต่อคน', style: muted),
                        Text(
                          formatBaht((budget / form.travellerCount).round()),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colors.tertiary,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Slider(
                value: (budget ?? _sliderMin).toDouble().clamp(
                  _sliderMin,
                  _sliderMax,
                ),
                min: _sliderMin,
                max: _sliderMax,
                divisions: 98,
                label: formatBaht(budget ?? _sliderMin.round()),
                onChanged: _setFromSlider,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatBaht(_sliderMin.round()), style: muted),
                  Text('${formatBaht(_sliderMax.round())}+', style: muted),
                ],
              ),
            ],
          ),
        ),
        switch (ref.watch(placeCatalogProvider)) {
          AsyncData(:final value) => _Places(
            provinces: value.provinces,
            form: form,
            notifier: notifier,
          ),
          AsyncError() => Text(
            'โหลดรายชื่อจังหวัดไม่สำเร็จ',
            style: TextStyle(color: colors.error),
          ),
          _ => const LinearProgressIndicator(),
        },
      ],
    );
  }
}

class _Places extends StatelessWidget {
  const _Places({
    required this.provinces,
    required this.form,
    required this.notifier,
  });

  final List<Province> provinces;
  final TripRequestFormState form;
  final TripRequestFormNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormSection(
          icon: Icons.trip_origin,
          title: 'ออกเดินทางจาก',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in provinces)
                ChoiceChip(
                  label: Text(p.name),
                  selected: form.originId == p.id,
                  showCheckmark: false,
                  onSelected: (_) => notifier.setOrigin(p.id),
                ),
            ],
          ),
        ),
        FormSection(
          icon: Icons.place_outlined,
          title: 'อยากไปที่ไหน?',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OptionCard(
                icon: Icons.auto_awesome,
                label: 'ให้ AI เลือกให้',
                caption: 'เสนอจังหวัดที่เหมาะกับงบและสไตล์ของคุณ',
                selected: form.destinationId == null,
                onTap: () => notifier.setDestination(null),
              ),
              for (final p in provinces) ...[
                const SizedBox(height: 12),
                OptionCard(
                  icon: Icons.location_city_outlined,
                  label: p.name,
                  caption: p.tags.take(3).map((t) => t.label).join(' · '),
                  selected: form.destinationId == p.id,
                  onTap: () => notifier.setDestination(p.id),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
