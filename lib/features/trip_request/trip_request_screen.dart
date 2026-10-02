import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/layout/window_size_class.dart';
import '../../app/router.dart';
import 'trip_request_form_notifier.dart';
import 'widgets/budget_step.dart';
import 'widgets/dates_step.dart';
import 'widgets/preferences_step.dart';
import 'widgets/transport_step.dart';

/// Multi-step Trip Request form (#18). State lives in
/// [tripRequestFormProvider] (#17).
class TripRequestScreen extends ConsumerStatefulWidget {
  const TripRequestScreen({super.key});

  @override
  ConsumerState<TripRequestScreen> createState() => _TripRequestScreenState();
}

class _TripRequestScreenState extends ConsumerState<TripRequestScreen> {
  /// Errors appear only after the user tries to continue.
  var _showError = false;

  TripRequestFormNotifier get _form =>
      ref.read(tripRequestFormProvider.notifier);

  void _continue() {
    if (_form.currentError != null) {
      setState(() => _showError = true);
      return;
    }
    setState(() => _showError = false);
    final state = ref.read(tripRequestFormProvider);
    if (!state.isLastStep) {
      _form.next();
      return;
    }
    final request = _form.submit();
    context.go(
      request.destinationId == null
          ? AppRoutes.suggestions
          : AppRoutes.generating,
    );
  }

  void _back() {
    setState(() => _showError = false);
    _form.back();
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(tripRequestFormProvider);
    final steps = TripRequestStep.values;

    return PopScope(
      canPop: form.isFirstStep,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'ปิด',
            onPressed: () => context.go(AppRoutes.home),
          ),
          title: const Text('วางแผนทริปใหม่'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: (form.step.index + 1) / steps.length,
              semanticsLabel:
                  'ขั้นที่ ${form.step.index + 1} จาก ${steps.length}',
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(child: _StepPage(step: form.step)),
              _BottomBar(
                error: _showError ? _form.currentError : null,
                isFirstStep: form.isFirstStep,
                isLastStep: form.isLastStep,
                onBack: _back,
                onContinue: _continue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepPage extends StatelessWidget {
  const _StepPage({required this.step});

  final TripRequestStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final margin = context.windowSizeClass.pageMargin;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(margin, 24, margin, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ขั้นที่ ${step.index + 1} จาก ${TripRequestStep.values.length}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(step.label, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 24),
              switch (step) {
                TripRequestStep.datesAndTravellers => const DatesStep(),
                TripRequestStep.budgetAndPlaces => const BudgetStep(),
                TripRequestStep.transport => const TransportStep(),
                TripRequestStep.preferences => const PreferencesStep(),
              },
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.error,
    required this.isFirstStep,
    required this.isLastStep,
    required this.onBack,
    required this.onContinue,
  });

  final String? error;
  final bool isFirstStep;
  final bool isLastStep;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final margin = context.windowSizeClass.pageMargin;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: EdgeInsets.fromLTRB(margin, 8, margin, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null) ...[
                Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 20,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  if (!isFirstStep)
                    TextButton(
                      onPressed: onBack,
                      child: const Text('ย้อนกลับ'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: onContinue,
                    child: Text(isLastStep ? 'ดูผลลัพธ์' : 'ถัดไป'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
