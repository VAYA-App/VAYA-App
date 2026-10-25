import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/providers/data_providers.dart';
import '../../../domain/domain.dart';
import '../trip_request_form_notifier.dart';
import 'form_section.dart';

/// Origin and an optional Destination, on step ① of the form, as two
/// menus so the dates stay in view on a phone.
class RouteSection extends ConsumerWidget {
  const RouteSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(tripRequestFormProvider);
    final notifier = ref.read(tripRequestFormProvider.notifier);

    return switch (ref.watch(placeCatalogProvider)) {
      AsyncData(:final value) => _Places(
        provinces: value.provinces,
        form: form,
        notifier: notifier,
      ),
      AsyncError() => Text(
        'โหลดรายชื่อจังหวัดไม่สำเร็จ',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      _ => const LinearProgressIndicator(),
    };
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

  /// The destination menu's value for "let the AI choose".
  static const _aiChooses = '';

  @override
  Widget build(BuildContext context) {
    return FormSection(
      icon: Icons.route_outlined,
      title: 'เส้นทาง',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownMenu<String>(
            label: const Text('ออกเดินทางจาก'),
            leadingIcon: const Icon(Icons.trip_origin),
            expandedInsets: EdgeInsets.zero,
            initialSelection: form.originId,
            requestFocusOnTap: false,
            dropdownMenuEntries: [
              for (final p in provinces)
                DropdownMenuEntry(value: p.id, label: p.name),
            ],
            onSelected: (id) {
              if (id != null) notifier.setOrigin(id);
            },
          ),
          const SizedBox(height: 16),
          DropdownMenu<String>(
            label: const Text('อยากไปที่ไหน'),
            leadingIcon: const Icon(Icons.place_outlined),
            expandedInsets: EdgeInsets.zero,
            initialSelection: form.destinationId ?? _aiChooses,
            requestFocusOnTap: false,
            dropdownMenuEntries: [
              const DropdownMenuEntry(
                value: _aiChooses,
                label: 'ให้ AI เลือกให้',
                leadingIcon: Icon(Icons.auto_awesome),
              ),
              for (final p in provinces)
                DropdownMenuEntry(value: p.id, label: p.name),
            ],
            onSelected: (id) => notifier.setDestination(
              id == null || id == _aiChooses ? null : id,
            ),
          ),
        ],
      ),
    );
  }
}
