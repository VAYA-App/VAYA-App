import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../shared/widgets/not_implemented_view.dart';

/// เข้าสู่ระบบ — built in #15.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const NotImplementedView(
        screenName: 'เข้าสู่ระบบ',
        issue: 15,
        owner: 'gunruethaiz',
        shortcuts: [(label: 'ข้ามไปหน้าแรก (dev)', location: AppRoutes.home)],
      ),
    );
  }
}
