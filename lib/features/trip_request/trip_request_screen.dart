import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/layout/window_size_class.dart';
import '../../app/router.dart';
import '../../shared/widgets/mascot_view.dart';
import '../../shared/widgets/motion.dart';
import 'trip_request_form_notifier.dart';
import 'widgets/budget_section.dart';
import 'widgets/dates_section.dart';
import 'widgets/pace_section.dart';
import 'widgets/request_summary.dart';
import 'widgets/route_section.dart';
import 'widgets/style_section.dart';
import 'widgets/transport_section.dart';

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

  /// Direction of the last step change, for the shared-axis transition.
  var _forward = true;
  TripRequestStep? _lastStep;

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
    context.go(switch (request.destinationId) {
      null => AppRoutes.suggestions,
      final id => '${AppRoutes.generating}?destination=$id',
    });
  }

  void _goBackTo(TripRequestStep step) {
    setState(() => _showError = false);
    _form.goBackTo(step);
  }

  void _back() {
    setState(() => _showError = false);
    _form.back();
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(tripRequestFormProvider);
    if (_lastStep != null && _lastStep != form.step) {
      _forward = form.step.index > _lastStep!.index;
    }
    _lastStep = form.step;

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
        ),
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (context.windowSizeClass.isAtLeast(WindowSizeClass.expanded))
                _StepList(current: form.step, onSelect: _goBackTo),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: SharedAxisSwitcher(
                        forward: _forward,
                        child: _StepPage(
                          key: ValueKey(form.step),
                          step: form.step,
                          onEdit: _goBackTo,
                        ),
                      ),
                    ),
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
            ],
          ),
        ),
      ),
    );
  }
}

/// Left pane on expanded windows: every step with its status. Earlier
/// steps can be revisited; later ones open only through "ถัดไป".
class _StepList extends StatelessWidget {
  const _StepList({required this.current, required this.onSelect});

  final TripRequestStep current;
  final ValueChanged<TripRequestStep> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 0, 24),
      child: Material(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 280,
          // Scrolls when large text makes the steps taller than the window.
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final step in TripRequestStep.values)
                  ListTile(
                    leading: Icon(
                      step.index < current.index
                          ? Icons.check_circle
                          : step == current
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: step.index <= current.index
                          ? colors.primary
                          : colors.outline,
                    ),
                    title: Text(step.label),
                    subtitle: Text('ขั้นที่ ${step.index + 1}'),
                    selected: step == current,
                    enabled: step.index <= current.index,
                    onTap: () => onSelect(step),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Segmented progress bar with the question for the current step, and
/// the mascot acting it out (#81).
class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.step});

  final TripRequestStep step;

  static const _questions = {
    TripRequestStep.routeAndDates: (
      'ไปไหน เมื่อไร กี่คน?',
      'ยังไม่รู้จะไปไหนก็ได้ ให้ AI ช่วยเลือกจังหวัด',
    ),
    TripRequestStep.budgetAndPace: (
      'งบเท่าไร เที่ยวแบบไหน?',
      'ใช้ประมาณค่าใช้จ่าย จำนวนที่เที่ยว และค่าเดินทางในแผน',
    ),
    TripRequestStep.style: (
      'ชอบเที่ยวแบบไหน?',
      'AI จะเลือกสถานที่ให้ตรงกับสไตล์ของคุณ',
    ),
  };

  static const _poses = {
    TripRequestStep.routeAndDates: MascotPose.calendar,
    TripRequestStep.budgetAndPace: MascotPose.budget,
    TripRequestStep.style: MascotPose.wave,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final steps = TripRequestStep.values;
    final (question, hint) = _questions[step]!;
    // Large text on a phone needs the whole width for the question.
    final showMascot =
        context.windowSizeClass != WindowSizeClass.compact ||
        MediaQuery.textScalerOf(context).scale(1) < 1.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'ความคืบหน้า ขั้นที่ ${step.index + 1} จาก ${steps.length}',
          child: Row(
            children: [
              for (final s in steps) ...[
                if (s.index > 0) const SizedBox(width: 6),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 6,
                    decoration: BoxDecoration(
                      color: s.index <= step.index
                          ? colors.primary
                          : colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          children: [
            Text(
              'ขั้นที่ ${step.index + 1} จาก ${steps.length}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.primary,
              ),
            ),
            Text(
              ' · ${step.label}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(question, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(
                    hint,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (showMascot) ...[
              const SizedBox(width: 12),
              MascotView(pose: _poses[step]!, size: 88),
            ],
          ],
        ),
      ],
    );
  }
}

class _StepPage extends StatelessWidget {
  const _StepPage({super.key, required this.step, required this.onEdit});

  final TripRequestStep step;

  /// Goes back to a step from the summary on the last one.
  final ValueChanged<TripRequestStep> onEdit;

  @override
  Widget build(BuildContext context) {
    final margin = context.windowSizeClass.pageMargin;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          // Dragging the form puts the keyboard away (#180).
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(margin, 24, margin, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProgressHeader(step: step),
              const SizedBox(height: 24),
              ...switch (step) {
                TripRequestStep.routeAndDates => const [
                  RouteSection(),
                  DatesSection(),
                ],
                TripRequestStep.budgetAndPace => const [
                  BudgetSection(),
                  PaceSection(),
                  TransportSection(),
                ],
                TripRequestStep.style => [
                  const StyleSection(),
                  RequestSummary(onEdit: onEdit),
                ],
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
                  if (!isFirstStep) ...[
                    IconButton.outlined(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'ย้อนกลับ',
                      style: IconButton.styleFrom(
                        minimumSize: const Size.square(52),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onContinue,
                      icon: Icon(
                        isLastStep ? Icons.auto_awesome : Icons.arrow_forward,
                      ),
                      iconAlignment: isLastStep
                          ? IconAlignment.start
                          : IconAlignment.end,
                      label: Text(isLastStep ? 'ให้ AI วางแผนให้' : 'ถัดไป'),
                    ),
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
