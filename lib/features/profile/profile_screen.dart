import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../shared/widgets/not_implemented_view.dart';

/// โปรไฟล์ — built in #16.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('โปรไฟล์')),
      body: const NotImplementedView(
        screenName: 'โปรไฟล์',
        issue: 16,
        owner: 'gunruethaiz',
        shortcuts: [(label: 'ไปหน้าเข้าสู่ระบบ', location: AppRoutes.login)],
      ),
    );
  }
}
