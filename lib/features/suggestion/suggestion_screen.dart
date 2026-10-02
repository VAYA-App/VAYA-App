import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../shared/widgets/not_implemented_view.dart';

/// จังหวัดที่เหมาะกับคุณ — built in #23.
class SuggestionScreen extends StatelessWidget {
  const SuggestionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('จังหวัดที่เหมาะกับคุณ')),
      body: const NotImplementedView(
        screenName: 'จังหวัดที่เหมาะกับคุณ',
        issue: 23,
        owner: 'Nirapada-p',
        shortcuts: [
          (label: 'เลือกจังหวัด → สร้างแผน', location: AppRoutes.generating),
        ],
      ),
    );
  }
}
