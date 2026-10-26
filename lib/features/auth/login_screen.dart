import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers/data_providers.dart';
import '../../data/auth_repository.dart';
import 'google_sign_in_button.dart';

/// หน้าเข้าสู่ระบบตามแนวคิด Material 3 และ Stitch ("Siam Wanderlust").
///
/// ดีไซน์ภาพพื้นหลังวัดอรุณราชวรารามพร้อมการไล่ระดับสี (Gradient Fade)
/// และปุ่มเข้าสู่ระบบด้วย Google ตามมาตรฐาน Google Identity Guidelines
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;

  Future<void> _signIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      // เมื่อล็อกอินสำเร็จ router จะ redirect ไปยังหน้าแรกอัตโนมัติผ่าน auth state
    } on AuthException catch (e) {
      if (!mounted) return;
      if (!e.cancelled) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เข้าสู่ระบบไม่สำเร็จ กรุณาลองใหม่อีกครั้ง'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showInfoDialog(BuildContext context, String title, String body) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final heroHeight = constraints.hasBoundedHeight
                  ? (constraints.maxHeight * 0.42).clamp(200.0, 340.0)
                  : 260.0;

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Hero Image of Wat Arun with Gradient Fade & VAYA Logo
                    SizedBox(
                      height: heroHeight,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            'assets/images/wat_arun_hero.jpg',
                            fit: BoxFit.cover,
                            alignment: const Alignment(0, -0.3),
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: colors.primaryContainer,
                                  child: Center(
                                    child: Icon(
                                      Icons.temple_buddhist,
                                      size: 70,
                                      color: colors.primary,
                                    ),
                                  ),
                                ),
                          ),
                          // Soft gradient transition into background surface
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: const [0.0, 0.4, 0.75, 1.0],
                                  colors: [
                                    Colors.black.withValues(alpha: 0.3),
                                    Colors.transparent,
                                    colors.surface.withValues(alpha: 0.85),
                                    colors.surface,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Top Left "VAYA" Brand Logo
                          SafeArea(
                            bottom: false,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: Text(
                                  'VAYA',
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.5,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.5,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                // 2. Text & Actions Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'เที่ยวไทยแบบ\nไม่ต้องวางแผนเอง',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'AI จัดแผนรายวัน ค่าใช้จ่าย และเส้นทางบนแผนที่ให้ในไม่กี่วินาที',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      GoogleSignInButton(
                        onPressed: _isLoading ? null : _signIn,
                        isLoading: _isLoading,
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Text(
                          'ทริปที่บันทึกจะซิงก์กับบัญชีนี้ทุกเครื่อง',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant.withValues(alpha: 0.8),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text.rich(
                          TextSpan(
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant.withValues(alpha: 0.8),
                            ),
                            children: [
                              const TextSpan(text: 'การเข้าสู่ระบบถือว่ายอมรับ '),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.baseline,
                                baseline: TextBaseline.alphabetic,
                                child: GestureDetector(
                                  onTap: () => _showInfoDialog(
                                    context,
                                    'ข้อกำหนดการใช้งาน',
                                    'ข้อกำหนดการใช้งานแอปพลิเคชัน VAYA:\n\n'
                                    '1. ผู้ใช้ตกลงใช้แอปพลิเคชันเพื่อการวางแผนการท่องเที่ยวส่วนบุคคล\n'
                                    '2. ข้อมูลราคาและสถานที่อาจมีการเปลี่ยนแปลงตามผู้ให้บริการจริง\n'
                                    '3. แผนการเดินทางที่ AI แนะนำเป็นข้อเสนอแนะเบื้องต้น ผู้ใช้ควรตรวจสอบความพร้อมก่อนเดินทาง',
                                  ),
                                  child: Text(
                                    'ข้อกำหนด',
                                    style: TextStyle(
                                      color: colors.primary,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                      decorationColor: colors.primary,
                                    ),
                                  ),
                                ),
                              ),
                              const TextSpan(text: ' และ '),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.baseline,
                                baseline: TextBaseline.alphabetic,
                                child: GestureDetector(
                                  onTap: () => _showInfoDialog(
                                    context,
                                    'นโยบายความเป็นส่วนตัว',
                                    'นโยบายความเป็นส่วนตัว VAYA:\n\n'
                                    '1. เราจัดเก็บเฉพาะข้อมูลที่จำเป็นต่อการให้บริการ เช่น ชื่อและอีเมลที่ได้จาก Google\n'
                                    '2. ข้อมูลแผนการเดินทางของคุณจะถูกซิงก์อย่างปลอดภัยเพื่อเข้าถึงได้จากทุกอุปกรณ์\n'
                                    '3. เราไม่จำหน่ายหรือเผยแพร่ข้อมูลส่วนบุคคลของคุณแก่บุคคลภายนอก',
                                  ),
                                  child: Text(
                                    'นโยบายความเป็นส่วนตัว',
                                    style: TextStyle(
                                      color: colors.primary,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                      decorationColor: colors.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  ),
);
  }
}
