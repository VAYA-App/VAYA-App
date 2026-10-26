import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/layout/window_size_class.dart';
import '../../app/router.dart';
import '../../shared/widgets/mascot_view.dart';
import '../../shared/widgets/motion.dart';
import 'onboarding_seen_provider.dart';

/// Three intro screens shown before the first sign-in (#178). Finishing or
/// skipping marks them seen and moves on to [AppRoutes.login].
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _pages = [
    (
      pose: MascotPose.calendar,
      title: 'บอกแค่เวลา งบ\nและสไตล์ที่ชอบ',
      body:
          'ไม่ต้องรู้ว่าจะไปไหน ช้างน้อยเสนอจังหวัด'
          'ที่เข้ากับงบและช่วงเวลาของคุณให้',
    ),
    (
      pose: MascotPose.map,
      title: 'AI จัดแผนให้\nในไม่กี่วินาที',
      body:
          'ได้แผนรายวัน เส้นทางบนแผนที่ และค่าใช้จ่ายโดยประมาณ'
          'ครบในที่เดียว',
    ),
    (
      pose: MascotPose.celebrate,
      title: 'ปรับได้\nตามใจคุณ',
      body:
          'คุยกับช้างน้อยเพื่อเปลี่ยนที่เที่ยว กดชอบหรือไม่ชอบสถานที่ '
          'แล้วครั้งหน้าจะเลือกให้ตรงใจขึ้น',
    ),
  ];

  final _controller = PageController();
  var _page = 0;

  bool get _isLast => _page == _pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(onboardingSeenProvider.notifier).markSeen();
    if (mounted) context.go(AppRoutes.login);
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: Motion.of(context, Motion.medium),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final margin = context.windowSizeClass.pageMargin;

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: EdgeInsets.fromLTRB(margin, 8, margin, 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'VAYA',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const Spacer(),
                      if (!_isLast)
                        TextButton(
                          onPressed: _finish,
                          child: const Text('ข้าม'),
                        ),
                    ],
                  ),
                  Expanded(
                    child: PageView(
                      controller: _controller,
                      onPageChanged: (i) => setState(() => _page = i),
                      children: [for (final p in _pages) _Page(page: p)],
                    ),
                  ),
                  Semantics(
                    label: 'หน้า ${_page + 1} จาก ${_pages.length}',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _pages.length; i++)
                          AnimatedContainer(
                            duration: Motion.of(context, Motion.short),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: i == _page ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == _page
                                  ? colors.primary
                                  : colors.outlineVariant,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _next,
                      icon: Icon(_isLast ? Icons.check : Icons.arrow_forward),
                      iconAlignment: IconAlignment.end,
                      label: Text(_isLast ? 'เริ่มเลย' : 'ถัดไป'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.page});

  final ({MascotPose pose, String title, String body}) page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // Large text needs the room the mascot would take.
    final showMascot = MediaQuery.textScalerOf(context).scale(1) < 1.5;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            if (showMascot) ...[
              SizedBox.square(
                dimension: 260,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.secondaryContainer,
                  ),
                  child: Center(child: MascotView(pose: page.pose, size: 220)),
                ),
              ),
              const SizedBox(height: 28),
            ],
            Text(
              page.title,
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              page.body,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
