import 'package:material_ui/material_ui.dart';

import 'google_logo.dart';

/// ปุ่มเข้าสู่ระบบด้วย Google ตามมาตรฐาน Google Identity Branding Guidelines
///
/// ปรับสีอัตโนมัติตาม Light / Dark mode พร้อมโลโก้ Google 4 สี และสถานะ Loading
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.text = 'เข้าสู่ระบบด้วย Google',
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = isDark
        ? const Color(0xFF131314)
        : const Color(0xFFFFFFFF);
    final textColor = isDark
        ? const Color(0xFFE3E3E3)
        : const Color(0xFF1F1F1F);
    final borderColor = isDark
        ? const Color(0xFF8E918F)
        : const Color(0xFF747775);

    return SizedBox(
      height: 48,
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          disabledBackgroundColor: backgroundColor.withValues(alpha: 0.85),
          disabledForegroundColor: textColor.withValues(alpha: 0.6),
          side: BorderSide(
            color: borderColor.withValues(alpha: 0.7),
            width: 1.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: isDark ? 0 : 1,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        icon: isLoading
            ? SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isDark
                      ? const Color(0xFFA8C7FA)
                      : const Color(0xFF0B57D0),
                ),
              )
            : const GoogleLogo(size: 20),
        label: Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.25,
          ),
        ),
      ),
    );
  }
}
