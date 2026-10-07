import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/layout/window_size_class.dart';
import '../../app/router.dart';
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
              ],
            ),
          ),
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
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: colors.secondaryContainer,
              foregroundColor: colors.onSecondaryContainer,
              foregroundImage: photo == null ? null : NetworkImage(photo),
              child: Text(
                name.isEmpty ? '?' : name.characters.first,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colors.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: theme.textTheme.titleLarge),
                  if (email != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
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
            Icon(Icons.person_off_outlined, size: 40, color: colors.outline),
            const SizedBox(height: 12),
            Text(
              'ยังไม่ได้เข้าสู่ระบบ',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'เข้าสู่ระบบด้วย Google เพื่อดูโปรไฟล์และทริปที่บันทึกไว้',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go(AppRoutes.login),
              child: const Text('ไปหน้าเข้าสู่ระบบ'),
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
            Icon(Icons.error_outline, size: 40, color: colors.error),
            const SizedBox(height: 12),
            Text(
              'โหลดข้อมูลผู้ใช้ไม่สำเร็จ',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'ตรวจสอบการเชื่อมต่อแล้วลองใหม่อีกครั้ง',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
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
