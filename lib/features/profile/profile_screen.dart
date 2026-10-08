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
/// ออกแบบในสไตล์ Bento Grid / การ์ดโมเดิร์น Material 3 (Siam Wanderlust)
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
                  AsyncData(value: final u?) => _UserBentoCard(user: u),
                  AsyncData() => const _SignedOutBentoCard(),
                  AsyncError() => _ErrorCard(
                    onRetry: () => ref.invalidate(currentUserProvider),
                  ),
                  _ => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                },
                const SizedBox(height: 16),
                const _ThemeBentoCard(),
                if (user.value != null) ...[
                  const SizedBox(height: 16),
                  const _SignOutBentoCard(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bento Card 1: ข้อมูลผู้ใช้และสถานะนักเดินทาง
class _UserBentoCard extends StatelessWidget {
  const _UserBentoCard({required this.user});

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
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.25),
                  width: 3,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: CircleAvatar(
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
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.verified_rounded,
                        size: 18,
                        color: colors.primary,
                      ),
                    ],
                  ),
                  if (email != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.mail_outline_rounded,
                          size: 14,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            email,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.secondaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: Text(
                        'สมาชิก VAYA',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

/// Bento Card 2: แผงควบคุมและเลือกธีมการแสดงผล
class _ThemeBentoCard extends ConsumerWidget {
  const _ThemeBentoCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final (label, icon) = switch (mode) {
      ThemeMode.system => ('ตามระบบ', Icons.brightness_auto_outlined),
      ThemeMode.light => ('สว่าง', Icons.light_mode_outlined),
      ThemeMode.dark => ('มืด', Icons.dark_mode_outlined),
    };

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
              trailing: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: colors.primary),
                      const SizedBox(width: 4),
                      Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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

/// Bento Card 3: การ์ดออกจากระบบ
class _SignOutBentoCard extends ConsumerWidget {
  const _SignOutBentoCard();

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

/// Empty state Bento Card: ยังไม่ได้เข้าสู่ระบบ
class _SignedOutBentoCard extends ConsumerWidget {
  const _SignedOutBentoCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Icon(
                  Icons.person_pin_circle_outlined,
                  size: 40,
                  color: colors.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ยังไม่ได้เข้าสู่ระบบ',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'เข้าสู่ระบบด้วย Google เพื่อดูโปรไฟล์และทริปที่บันทึกไว้',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.go(AppRoutes.login),
                icon: const Icon(Icons.login_rounded),
                label: const Text('ไปหน้าเข้าสู่ระบบ'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () async {
                  await ref.read(authRepositoryProvider).signInWithGoogle();
                },
                icon: const Icon(Icons.account_circle_outlined),
                label: const Text('เข้าสู่ระบบด้วย Google (ทดลองใช้งาน)'),
              ),
            ),
          ],
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
