import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/layout/window_size_class.dart';
import '../../app/providers/data_providers.dart';
import '../../app/router.dart';
import '../../app/theme/theme_mode_provider.dart';
import '../../data/auth_repository.dart';
import 'current_user_provider.dart';

/// โปรไฟล์: ข้อมูลผู้ใช้ ธีม และออกจากระบบ (#16).
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
              padding: EdgeInsets.fromLTRB(margin, 8, margin, 32),
              children: [
                switch (user) {
                  AsyncData(value: final u?) => _UserCard(user: u),
                  AsyncData() => const _SignedOutCard(),
                  AsyncError() => _ErrorCard(
                    onRetry: () => ref.invalidate(currentUserProvider),
                  ),
                  _ => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                },
                const SizedBox(height: 24),
                const _SectionTitle('การแสดงผล'),
                const SizedBox(height: 8),
                const _ThemeModeCard(),
                const SizedBox(height: 24),
                const _SectionTitle('เกี่ยวกับแอป'),
                const SizedBox(height: 8),
                const _AboutCard(),
                if (user.value != null) ...[
                  const SizedBox(height: 32),
                  const _SignOutButton(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// ตามระบบ / สว่าง / มืด; the whole app follows immediately.
class _ThemeModeCard extends ConsumerWidget {
  const _ThemeModeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SizedBox.square(
                  dimension: 40,
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.25),
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: CircleAvatar(
                  radius: 32,
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
                  Text(
                    name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (email != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.secondaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            size: 13,
                            color: colors.onSecondaryContainer,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'บัญชี VAYA',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSecondaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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

/// ข้อมูลเกี่ยวกับแอปพลิเคชัน
class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SizedBox.square(
                dimension: 40,
                child: Icon(Icons.info_outline, color: colors.onSurfaceVariant),
              ),
            ),
            title: const Text('เกี่ยวกับ VAYA'),
            subtitle: const Text('AI Trip Planner สำหรับเที่ยวไทย'),
            trailing: Text(
              'v1.0.0',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: colors.outlineVariant.withValues(alpha: 0.5),
          ),
          ListTile(
            leading: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SizedBox.square(
                dimension: 40,
                child: Icon(
                  Icons.translate_outlined,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            title: const Text('ภาษา'),
            subtitle: const Text('ไทย'),
          ),
        ],
      ),
    );
  }
}

/// Empty state: nobody is signed in.
class _SignedOutCard extends StatelessWidget {
  const _SignedOutCard();

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
                color: colors.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Icon(
                  Icons.person_off_outlined,
                  size: 40,
                  color: colors.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ยังไม่ได้เข้าสู่ระบบ',
              style: theme.textTheme.titleMedium?.copyWith(
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
            FilledButton.icon(
              onPressed: () => context.go(AppRoutes.login),
              icon: const Icon(Icons.login),
              label: const Text('ไปหน้าเข้าสู่ระบบ'),
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

/// ออกจากระบบหลังยืนยันใน AlertDialog แล้วกลับไปหน้าเข้าสู่ระบบ.
class _SignOutButton extends ConsumerWidget {
  const _SignOutButton();

  Future<void> _confirmAndSignOut(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.logout, color: colors.error),
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
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.error,
        side: BorderSide(color: colors.outlineVariant),
      ),
      onPressed: () => _confirmAndSignOut(context, ref),
      icon: const Icon(Icons.logout),
      label: const Text('ออกจากระบบ'),
    );
  }
}
