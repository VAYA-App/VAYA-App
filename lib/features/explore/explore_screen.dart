import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/layout/window_size_class.dart';
import '../../app/providers/data_providers.dart';
import '../../app/router.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/motion.dart';
import '../../shared/widgets/place_photo.dart';

/// สำรวจ (#174): every Destination and Place in the app's own data, with
/// photos, narrowed by province, name, category and Preference Tag.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  String? _province;
  PlaceCategory? _category;
  PreferenceTag? _tag;
  var _query = '';

  List<Place> _filter(PlaceCatalog catalog) {
    final query = _query.trim().toLowerCase();
    return [
      for (final p in catalog.places)
        if ((_province == null || p.provinceId == _province) &&
            (_category == null || p.category == _category) &&
            (_tag == null || p.tags.contains(_tag)) &&
            (query.isEmpty || p.name.toLowerCase().contains(query)))
          p,
    ]..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(placeCatalogProvider);
    final margin = context.windowSizeClass.pageMargin;

    return Scaffold(
      appBar: AppBar(title: const Text('สำรวจ')),
      body: switch (catalog) {
        AsyncData(:final value) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: WindowSizeClass.maxContentWidth,
            ),
            child: _results(value, margin),
          ),
        ),
        AsyncError() => _LoadError(
          onRetry: () => ref.invalidate(placeCatalogProvider),
        ),
        _ => ListView(
          padding: EdgeInsets.all(margin),
          children: const [
            Skeleton(height: 48, radius: 999),
            SizedBox(height: 16),
            Skeleton(height: 132, radius: 20),
          ],
        ),
      },
    );
  }

  Widget _results(PlaceCatalog catalog, double margin) {
    final places = _filter(catalog);
    final theme = Theme.of(context);

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(margin, 4, margin, 0),
          sliver: SliverList.list(
            children: [
              SearchBar(
                hintText: 'ค้นหาสถานที่ ร้าน หรือที่พัก',
                leading: const Icon(Icons.search),
                elevation: const WidgetStatePropertyAll(0),
                onChanged: (q) => setState(() => _query = q),
              ),
              const SizedBox(height: 16),
              _Provinces(
                provinces: catalog.provinces,
                counts: {
                  for (final p in catalog.provinces)
                    p.id: catalog.placesIn(p.id).length,
                },
                selected: _province,
                onSelect: (id) =>
                    setState(() => _province = _province == id ? null : id),
              ),
              const SizedBox(height: 16),
              SegmentedButton<PlaceCategory?>(
                segments: const [
                  ButtonSegment(value: null, label: Text('ทั้งหมด')),
                  ButtonSegment(
                    value: PlaceCategory.attraction,
                    label: Text('เที่ยว'),
                  ),
                  ButtonSegment(
                    value: PlaceCategory.restaurant,
                    label: Text('กิน'),
                  ),
                  ButtonSegment(
                    value: PlaceCategory.accommodation,
                    label: Text('พัก'),
                  ),
                ],
                selected: {_category},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _category = s.single),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final tag in PreferenceTag.values) ...[
                      FilterChip(
                        label: Text(tag.label),
                        selected: _tag == tag,
                        showCheckmark: false,
                        onSelected: (on) =>
                            setState(() => _tag = on ? tag : null),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'พบ ${places.length} สถานที่',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        if (places.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'ไม่พบสถานที่ที่ตรงกับตัวกรอง ลองเอาตัวกรองบางอย่างออก',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(margin, 0, margin, 32),
            sliver: SliverList.separated(
              itemCount: places.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => StaggeredEntrance(
                index: i,
                child: PlaceTile(
                  place: places[i],
                  provinceName: catalog
                      .findProvince(places[i].provinceId)
                      ?.name,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// One card per Destination; tap to show only its places.
class _Provinces extends StatelessWidget {
  const _Provinces({
    required this.provinces,
    required this.counts,
    required this.selected,
    required this.onSelect,
  });

  final List<Province> provinces;
  final Map<String, int> counts;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (final (i, p) in provinces.indexed) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              selected: p.id == selected,
              button: true,
              child: Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: p.id == selected
                      ? BorderSide(color: colors.primary, width: 3)
                      : BorderSide.none,
                ),
                child: InkWell(
                  onTap: () => onSelect(p.id),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: PlacePhoto(id: p.id, label: p.name),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 120),
                        child: PhotoScrim(
                          child: Container(
                            alignment: Alignment.bottomLeft,
                            padding: const EdgeInsets.fromLTRB(14, 40, 14, 12),
                            child: Builder(
                              builder: (context) {
                                final text = Theme.of(context).textTheme;
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.name, style: text.titleMedium),
                                    Text(
                                      '${counts[p.id]} สถานที่',
                                      style: text.bodySmall,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A Place in a list: photo, name, area and tags, rating and Price Level.
/// Opens its detail page.
class PlaceTile extends StatelessWidget {
  const PlaceTile({super.key, required this.place, this.provinceName});

  final Place place;
  final String? provinceName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.place(place.id)),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 96,
                  height: 72,
                  child: PlacePhoto(
                    id: place.id,
                    label: place.name,
                    category: place.category,
                    heroTag: 'place-${place.id}',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(place.name, style: theme.textTheme.titleSmall),
                    Text(
                      [
                        ?place.area ?? provinceName,
                        ...place.tags.take(2).map((t) => t.label),
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          if (place.rating != null)
                            TextSpan(
                              text: '★ ${place.rating!.toStringAsFixed(1)}  ',
                              style: TextStyle(
                                color: colors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          TextSpan(text: '฿' * place.priceLevel),
                        ],
                      ),
                      style: theme.textTheme.bodySmall,
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

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'โหลดข้อมูลสถานที่ไม่สำเร็จ',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      ),
    );
  }
}
