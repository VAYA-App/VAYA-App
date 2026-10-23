import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/layout/window_size_class.dart';
import '../../app/providers/data_providers.dart';
import '../../app/router.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/mascot_view.dart';
import '../trip_plan/trip_plan_view_provider.dart';
import 'plan_chat_panel.dart';

/// AI ช่วยคิด: chat with the mascot to adjust one of your trips (#46).
/// Plans made in this session come first, then saved trips.
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  String? _tripId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final catalog = ref.watch(placeCatalogProvider).value;
    String province(String id) => catalog?.findProvince(id)?.name ?? id;

    final drafts = ref.watch(draftTripsProvider);
    final saved = ref.watch(savedTripsProvider).value ?? const [];
    final trips = <(String, String)>[
      for (final MapEntry(key: id, value: d)
          in drafts.entries.toList().reversed)
        (
          id,
          '${province(d.plan.destinationId)} '
              '${formatDateRange(d.request.startDate, d.request.endDate)} '
              '(ยังไม่บันทึก)',
        ),
      for (final t in saved)
        if (t.id != null)
          (
            t.id!,
            '${province(t.plan.destinationId)} '
                '${formatDateRange(t.request.startDate, t.request.endDate)}',
          ),
    ];
    final ids = {for (final (id, _) in trips) id};
    final selected = ids.contains(_tripId) ? _tripId : trips.firstOrNull?.$1;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const MascotAvatar(radius: 18),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AI ช่วยคิด'),
                  Text(
                    'ช้างน้อย · ผู้ช่วยวางแผนทริป',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: WindowSizeClass.maxContentWidth,
          ),
          child: selected == null
              ? const _NoTrips()
              : Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        context.windowSizeClass.pageMargin,
                        8,
                        context.windowSizeClass.pageMargin,
                        0,
                      ),
                      child: DropdownMenu<String>(
                        key: ValueKey(selected),
                        initialSelection: selected,
                        expandedInsets: EdgeInsets.zero,
                        label: const Text('ทริปที่จะปรับ'),
                        leadingIcon: const Icon(Icons.luggage_outlined),
                        onSelected: (id) => setState(() => _tripId = id),
                        dropdownMenuEntries: [
                          for (final (id, label) in trips)
                            DropdownMenuEntry(value: id, label: label),
                        ],
                      ),
                    ),
                    Expanded(
                      child: PlanChatPanel(
                        key: ValueKey(selected),
                        tripId: selected,
                        onTripChanged: (id) => setState(() => _tripId = id),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _NoTrips extends StatelessWidget {
  const _NoTrips();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MascotView(pose: MascotPose.map, size: 120),
            const SizedBox(height: 16),
            Text(
              'ยังไม่มีทริปให้ปรับ',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'วางแผนทริปก่อน แล้วกลับมาคุยกับช้างน้อยเพื่อเปลี่ยนร้านอาหาร '
              'หรือที่เที่ยวได้เลย',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push(AppRoutes.newTrip),
              icon: const Icon(Icons.add),
              label: const Text('วางแผนทริปใหม่'),
            ),
          ],
        ),
      ),
    );
  }
}
