import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/layout/window_size_class.dart';
import '../../app/providers/data_providers.dart';
import '../../app/router.dart';
import '../../data/photo_catalog.dart';
import '../../domain/domain.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/open_in_maps_button.dart';
import '../../shared/widgets/place_photo.dart';
import '../trip_request/trip_request_form_notifier.dart';

/// One Place in full (#174): its photo, what it is, how long and how much,
/// and a way to plan a trip to its Destination.
class PlaceDetailScreen extends ConsumerWidget {
  const PlaceDetailScreen({super.key, required this.placeId});

  final String placeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(placeCatalogProvider).value;
    final place = catalog?.findPlace(placeId);
    if (catalog == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (place == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('ไม่พบสถานที่นี้')),
      );
    }
    final province = catalog.findProvince(place.provinceId);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 300,
            flexibleSpace: FlexibleSpaceBar(
              background: PlacePhoto(
                id: place.id,
                label: place.name,
                category: place.category,
                heroTag: 'place-${place.id}',
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: WindowSizeClass.maxContentWidth,
                ),
                child: _Details(place: place, provinceName: province?.name),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            context.windowSizeClass.pageMargin,
            8,
            context.windowSizeClass.pageMargin,
            12,
          ),
          child: FilledButton.icon(
            onPressed: () {
              ref
                  .read(tripRequestFormProvider.notifier)
                  .startWith(
                    destinationId: place.provinceId,
                    tags: place.tags.take(2),
                  );
              context.push(AppRoutes.newTrip);
            },
            icon: const Icon(Icons.auto_awesome),
            label: Text('วางแผนทริป${province?.name ?? ''}'),
          ),
        ),
      ),
    );
  }
}

class _Details extends ConsumerWidget {
  const _Details({required this.place, required this.provinceName});

  final Place place;
  final String? provinceName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final photos = ref.watch(photoCatalogProvider).value;
    final photoId = photos == null
        ? null
        : photos.hasOwnPhoto(place.id)
        ? place.id
        : PhotoCatalog.categoryId(place.category);
    final credit = photoId == null ? null : photos?.credits[photoId];
    final margin = context.windowSizeClass.pageMargin;

    return Padding(
      padding: EdgeInsets.fromLTRB(margin, 20, margin, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [place.category.label, ?provinceName].join(' · '),
            style: theme.textTheme.labelLarge?.copyWith(color: colors.primary),
          ),
          const SizedBox(height: 4),
          Text(place.name, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                if (place.rating != null)
                  TextSpan(
                    text: '★ ${place.rating!.toStringAsFixed(1)}   ',
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (place.area != null) TextSpan(text: '${place.area}   '),
                TextSpan(text: '฿' * place.priceLevel),
              ],
            ),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(place.shortDescription, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in place.tags)
                Chip(
                  label: Text(tag.label),
                  backgroundColor: colors.secondaryContainer,
                  labelStyle: TextStyle(color: colors.onSecondaryContainer),
                  side: BorderSide.none,
                ),
            ],
          ),
          const SizedBox(height: 16),
          _Facts(place: place),
          const SizedBox(height: 16),
          OpenInMapsButton(place: place),
          if (credit != null) ...[
            const SizedBox(height: 16),
            Text(
              '${photoId == place.id ? 'ภาพ' : 'ภาพประจำหมวด'}: '
              '“${credit.title}” · ${credit.author} · ${credit.licence}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// How long, when and how much, as small cards.
class _Facts extends StatelessWidget {
  const _Facts({required this.place});

  final Place place;

  static String _duration(int minutes) =>
      switch ((minutes ~/ 60, minutes % 60)) {
        (0, final m) => '$m นาที',
        (final h, 0) => '$h ชั่วโมง',
        (final h, final m) => '$h ชม. $m นาที',
      };

  /// "ทุกวัน 08:00–18:00" when every day is the same, otherwise today's
  /// hours.
  static String _hours(Map<int, OpeningPeriod>? hours, DateTime now) {
    if (hours == null) return 'ไม่ระบุ';
    String fmt(OpeningPeriod p) => '${p.open}–${p.close}';
    final all = {for (final p in hours.values) fmt(p)};
    if (hours.length == 7 && all.length == 1) return 'ทุกวัน ${all.single}';
    final today = hours[now.weekday];
    return today == null ? 'วันนี้ปิด' : 'วันนี้ ${fmt(today)}';
  }

  @override
  Widget build(BuildContext context) {
    final facts = [
      if (place.dwellMinutes != null)
        (Icons.schedule, 'ใช้เวลาประมาณ', _duration(place.dwellMinutes!)),
      if (place.category != PlaceCategory.accommodation)
        (
          Icons.door_front_door_outlined,
          'เวลาเปิด',
          _hours(place.openingHours, DateTime.now()),
        ),
      if (place.category == PlaceCategory.attraction)
        (
          Icons.confirmation_number_outlined,
          'ค่าเข้าชม',
          place.entranceFee == 0
              ? 'ไม่มีค่าเข้า'
              : '${formatBaht(place.entranceFee)} / คน',
        ),
      if (place.category == PlaceCategory.accommodation)
        (
          Icons.free_breakfast_outlined,
          'อาหารเช้า',
          place.breakfastIncluded ? 'รวมอาหารเช้า' : 'ไม่รวม',
        ),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (icon, label, value) in facts)
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 150),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            value,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
