import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/layout/window_size_class.dart';
import '../../app/providers/data_providers.dart';
import '../../app/router.dart';
import '../../app/theme/theme_mode_provider.dart';
import '../../data/auth_repository.dart';
import 'current_user_provider.dart';

/// โปรไฟล์: ข้อมูลผู้ใช้ ธีม และออกจากระบบ (#16)
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final margin = context.windowSizeClass.pageMargin;
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('โปรไฟล์')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: WindowSizeClass.maxContentWidth,
            ),
            child: ListView(
              padding: EdgeInsets.fromLTRB(margin, 12, margin, 32),
              children: [
                switch (user) {
                  AsyncData(value: final u?) => _UserCard(user: u),
                  AsyncData() => const SizedBox.shrink(),
                  AsyncError() => _ErrorCard(
                    onRetry: () => ref.invalidate(currentUserProvider),
                  ),
                  _ => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                },
                const SizedBox(height: 16),
                const _ThemeCard(),
                const _TasteCard(),
                if (user.value != null) ...[
                  const SizedBox(height: 16),
                  const _SignOutCard(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// การ์ดข้อมูลผู้ใช้: รูป, ชื่อ, และอีเมล
class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final photo = user.photoUrl;
    final name = user.displayName.trim();
    final email = user.email;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: colors.secondaryContainer,
              foregroundColor: colors.onSecondaryContainer,
              foregroundImage: photo == null ? null : NetworkImage(photo),
              child: Text(
                name.isEmpty ? '?' : name.characters.first,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colors.onSecondaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (email != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.mail_outline_rounded,
                            size: 16,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            email,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// การ์ดเลือกธีมการแสดงผล: ตามระบบ / สว่าง / มืด
class _ThemeCard extends ConsumerWidget {
  const _ThemeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final colors = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SizedBox.square(
                  dimension: 42,
                  child: Icon(Icons.palette_outlined, color: colors.primary),
                ),
              ),
              title: const Text('ธีม'),
              subtitle: const Text('เลือกโหมดสว่างหรือมืดของแอป'),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto_outlined),
                    label: Text('ตามระบบ'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('สว่าง'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('มืด'),
                  ),
                ],
                selected: {mode},
                showSelectedIcon: false,
                onSelectionChanged: (s) =>
                    ref.read(themeModeProvider.notifier).select(s.single),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// โปรไฟล์ความชอบจาก 👍/👎 (#49); ซ่อนเมื่อยังไม่เคยกด
class _TasteCard extends ConsumerWidget {
  const _TasteCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taste = ref.watch(tasteProfileProvider);
    final catalog = ref.watch(placeCatalogProvider).value;
    if (taste.isEmpty || catalog == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final liked =
        taste.tagWeights(catalog).entries.where((e) => e.value > 0).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final disliked = taste.disliked.length;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ความชอบของคุณ', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'จากการกดชอบ/ไม่ชอบสถานที่ ใช้ปรับการแนะนำทริปถัดไป',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              if (liked.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in liked.take(5))
                      Chip(
                        avatar: const Icon(Icons.thumb_up_outlined),
                        label: Text(e.key.label),
                      ),
                  ],
                ),
              ],
              if (disliked > 0) ...[
                const SizedBox(height: 12),
                Text(
                  'ไม่แนะนำอีก $disliked แห่ง',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      ref.read(tasteProfileProvider.notifier).clear(),
                  child: const Text('ล้างความชอบ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// การ์ดออกจากระบบพร้อมยืนยันผ่าน AlertDialog
class _SignOutCard extends ConsumerWidget {
  const _SignOutCard();

  Future<void> _confirmAndSignOut(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.logout_rounded, color: colors.error, size: 28),
        title: const Text('ออกจากระบบ?'),
        content: const Text(
          'คุณต้องเข้าสู่ระบบด้วย Google อีกครั้งเพื่อดูทริปที่บันทึกไว้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ออกจากระบบ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(authRepositoryProvider).signOut();
      // go() replaces the whole stack, so back cannot return here.
      if (context.mounted) context.go(AppRoutes.login);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ออกจากระบบไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.error,
              side: BorderSide(color: colors.error.withValues(alpha: 0.35)),
            ),
            onPressed: () => _confirmAndSignOut(context, ref),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('ออกจากระบบ'),
          ),
        ),
      ),
    );
  }
}

/// Error state: the user could not be loaded.
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Icon(
                  Icons.error_outline,
                  size: 40,
                  color: colors.onErrorContainer,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'โหลดข้อมูลผู้ใช้ไม่สำเร็จ',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'ตรวจสอบการเชื่อมต่อแล้วลองใหม่อีกครั้ง',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองใหม่'),
            ),
          ],
        ),
      ),
    );
  }
}
