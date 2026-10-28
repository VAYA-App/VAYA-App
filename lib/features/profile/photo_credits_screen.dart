import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/layout/window_size_class.dart';
import '../../app/providers/data_providers.dart';
import '../../data/photo_catalog.dart';
import '../../domain/domain.dart';
import '../../shared/open_externally.dart';
import '../../shared/widgets/place_photo.dart';

/// Credits for every bundled photo: title, author, licence and source, as
/// the CC BY and CC BY-SA licences require (ADR-0006).
class PhotoCreditsScreen extends ConsumerWidget {
  const PhotoCreditsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final margin = context.windowSizeClass.pageMargin;
    final photos = ref.watch(photoCatalogProvider);
    final places = ref.watch(placeCatalogProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('เครดิตภาพ')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: WindowSizeClass.maxContentWidth,
            ),
            child: switch (photos) {
              AsyncData(:final value) => ListView(
                padding: EdgeInsets.fromLTRB(margin, 8, margin, 32),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'ภาพทั้งหมดมาจาก Wikimedia Commons '
                      'ใช้ตามสัญญาอนุญาตของแต่ละภาพ แตะเพื่อดูต้นฉบับ',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  for (final credit in _sorted(value, places))
                    _CreditTile(
                      credit: credit,
                      subject: _subject(credit.id, places),
                    ),
                ],
              ),
              AsyncError() => _LoadError(
                onRetry: () => ref.invalidate(photoCatalogProvider),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ),
      ),
    );
  }

  /// Destinations first, then Places by name, then category photos.
  static List<PhotoCredit> _sorted(PhotoCatalog photos, PlaceCatalog? places) {
    int rank(String id) => places?.findProvince(id) != null
        ? 0
        : id.startsWith('category-')
        ? 2
        : 1;
    return photos.credits.values.toList()..sort((a, b) {
      final byRank = rank(a.id).compareTo(rank(b.id));
      return byRank != 0
          ? byRank
          : _subject(a.id, places).compareTo(_subject(b.id, places));
    });
  }

  /// What the photo shows, in the app's own words.
  static String _subject(String id, PlaceCatalog? places) {
    for (final c in PlaceCategory.values) {
      if (id == PhotoCatalog.categoryId(c)) return 'ภาพประจำหมวด${c.label}';
    }
    return places?.findProvince(id)?.name ?? places?.findPlace(id)?.name ?? id;
  }
}

class _CreditTile extends StatelessWidget {
  const _CreditTile({required this.credit, required this.subject});

  final PhotoCredit credit;
  final String subject;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 64,
          height: 48,
          child: PlacePhoto(id: credit.id, label: subject),
        ),
      ),
      title: Text(subject),
      subtitle: Text(
        '“${credit.title}” · ${credit.author} · ${credit.licence}',
      ),
      trailing: const Icon(Icons.open_in_new, size: 20),
      onTap: () => openExternally(
        context,
        Uri.parse(credit.source),
        failure: 'เปิดลิงก์ไม่ได้',
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'โหลดเครดิตภาพไม่สำเร็จ',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
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
