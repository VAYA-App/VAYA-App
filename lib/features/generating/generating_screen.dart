import 'package:material_ui/material_ui.dart';

import '../../shared/widgets/not_implemented_view.dart';

/// กำลังสร้างแผน — built in #31.
class GeneratingScreen extends StatelessWidget {
  const GeneratingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const NotImplementedView(
        screenName: 'กำลังสร้างแผน',
        issue: 31,
        owner: 'Kritternai',
        shortcuts: [(label: 'เสร็จ → ดูแผน', location: '/trips/mock')],
      ),
    );
  }
}
