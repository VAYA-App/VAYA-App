import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../shared/formatters.dart';
import '../trip_request_form_notifier.dart';
import 'form_section.dart';

/// The total Budget, on step ② of the form.
class BudgetSection extends ConsumerStatefulWidget {
  const BudgetSection({super.key});

  @override
  ConsumerState<BudgetSection> createState() => _BudgetSectionState();
}

class _BudgetSectionState extends ConsumerState<BudgetSection> {
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

    return FormSection(
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
                  onChanged: (value) => notifier.setBudget(int.tryParse(value)),
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
    );
  }
}
