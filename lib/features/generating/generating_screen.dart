import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/layout/window_size_class.dart';
import '../../app/providers/data_providers.dart';
import '../../app/providers/mock_providers.dart';
import '../../app/providers/planner_providers.dart';
import '../../app/router.dart';
import '../../domain/domain.dart';
import '../../planner/planner_service.dart';
import '../../shared/formatters.dart';
import '../trip_request/trip_request_form_notifier.dart';

/// Shows the planner's progress while a Trip Plan is built (#31, #65),
/// then opens the plan.
class GeneratingScreen extends ConsumerStatefulWidget {
  const GeneratingScreen({super.key, this.destinationId});

  /// From `?destination=`. Falls back to the request's destination, then to
  /// the demo province until the suggestion screen (#23) passes its choice.
  final String? destinationId;

  @override
  ConsumerState<GeneratingScreen> createState() => _GeneratingScreenState();
}

class _GeneratingScreenState extends ConsumerState<GeneratingScreen> {
  static const _fallbackDestination = 'chonburi';

  static const _steps = {
    PlanningStage.selectingPlaces: 'เลือกสถานที่ที่เข้ากับสไตล์',
    PlanningStage.validating: 'ตรวจสอบว่าทุกที่มีอยู่จริง',
    PlanningStage.orderingRoutes: 'จัดลำดับเส้นทางและเวลา',
    PlanningStage.pricing: 'คำนวณค่าใช้จ่ายแยกหมวด',
  };

  StreamSubscription<PlanningProgress>? _subscription;
  TripRequest? _request;
  PlanningStage? _stage;
  Object? _error;

  String get _destinationId =>
      widget.destinationId ?? _request?.destinationId ?? _fallbackDestination;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    await _subscription?.cancel();
    setState(() {
      _error = null;
      _stage = null;
    });
    try {
      final request = _request ??= await _loadRequest();
      _subscription = ref
          .read(plannerServiceProvider)
          .generate(request: request, destinationId: _destinationId)
          .listen(
            _onProgress,
            onError: (Object e) => setState(() => _error = e),
          );
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// The submitted form, or the demo request when this screen was opened
  /// without one (e.g. from a shortcut).
  Future<TripRequest> _loadRequest() async {
    try {
      return ref.read(tripRequestFormProvider.notifier).submit();
    } on StateError {
      return ref.read(mockTripRequestProvider.future);
    }
  }

  void _onProgress(PlanningProgress progress) {
    setState(() => _stage = progress.stage);
    if (progress.stage == PlanningStage.done) {
      context.go(AppRoutes.tripPlan('mock'));
    }
  }

  void _cancel() => context.go(AppRoutes.newTrip);

  @override
  Widget build(BuildContext context) {
    final margin = context.windowSizeClass.pageMargin;
    final province = ref
        .watch(placeCatalogProvider)
        .whenData((c) => c.findProvince(_destinationId))
        .value;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'ยกเลิก',
          onPressed: _cancel,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.fromLTRB(margin, 0, margin, 32),
              children: _error != null
                  ? [_ErrorBody(onRetry: _start, onEdit: _cancel)]
                  : [
                      _ProgressRing(stage: _stage, total: _steps.length),
                      const SizedBox(height: 24),
                      _Headline(request: _request, province: province),
                      const SizedBox(height: 24),
                      _StepList(steps: _steps, current: _stage),
                      if (province != null) ...[
                        const SizedBox(height: 16),
                        _TipCard(tip: province.seasonNote),
                      ],
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: _cancel,
                          child: const Text('ยกเลิกการสร้างแผน'),
                        ),
                      ),
                    ],
            ),
          ),
        ),
      ),
    );
  }
}

int _completed(PlanningStage? stage) => stage?.index ?? 0;

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.stage, required this.total});

  final PlanningStage? stage;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final target = _completed(stage) / total;

    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 16, color: colors.primary),
                const SizedBox(width: 6),
                Text(
                  'AI กำลังวางแผน',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        TweenAnimationBuilder<double>(
          tween: Tween(end: target),
          duration: const Duration(milliseconds: 500),
          builder: (context, value, _) => SizedBox.square(
            dimension: 168,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: value,
                  strokeWidth: 10,
                  strokeCap: StrokeCap.round,
                  backgroundColor: colors.surfaceContainerHighest,
                  semanticsLabel: 'ความคืบหน้าการสร้างแผน',
                  semanticsValue: '${(value * 100).round()}%',
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.travel_explore,
                        size: 32,
                        color: colors.primary,
                      ),
                      Text(
                        '${(value * 100).round()}%',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.request, required this.province});

  final TripRequest? request;
  final Province? province;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final r = request;

    return Column(
      children: [
        Text(
          'กำลังจัดทริปที่ใช่ให้คุณ',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        if (r != null) ...[
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Text(
                [
                  ?province?.name,
                  '${formatThaiShortDate(r.startDate)} – ${formatThaiShortDate(r.endDate)}',
                  'งบ ${formatBaht(r.budget)}',
                ].join(' · '),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StepList extends StatelessWidget {
  const _StepList({required this.steps, required this.current});

  final Map<PlanningStage, String> steps;
  final PlanningStage? current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final done = _completed(current);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'ขั้นตอนการวางแผน',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    '$done จาก ${steps.length}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
            ),
            for (final MapEntry(key: stage, value: label) in steps.entries)
              ListTile(
                leading: SizedBox.square(
                  dimension: 24,
                  child: stage.index < done
                      ? Icon(Icons.check_circle, color: colors.primary)
                      : stage == current
                      ? const CircularProgressIndicator(strokeWidth: 3)
                      : Icon(
                          Icons.radio_button_unchecked,
                          color: colors.outline,
                        ),
                ),
                title: Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: stage.index <= done
                        ? colors.onSurface
                        : colors.onSurfaceVariant,
                  ),
                ),
                subtitle: stage == current ? Text(stage.message) : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.tip});

  final String tip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      color: colors.tertiaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline, color: colors.onTertiaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'เกร็ดน่ารู้ระหว่างรอ',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colors.onTertiaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tip,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onTertiaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.onRetry, required this.onEdit});

  final VoidCallback onRetry;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      children: [
        const SizedBox(height: 48),
        Icon(Icons.cloud_off_outlined, size: 56, color: colors.error),
        const SizedBox(height: 16),
        Text('สร้างแผนไม่สำเร็จ', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'อาจเป็นเพราะการเชื่อมต่อหรือ AI ไม่ตอบ ลองใหม่อีกครั้ง',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('ลองใหม่'),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: onEdit, child: const Text('กลับไปแก้คำขอ')),
      ],
    );
  }
}
