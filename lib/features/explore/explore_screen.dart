import 'package:material_ui/material_ui.dart';

import '../../shared/widgets/not_implemented_view.dart';

/// Trip ideas to browse. Outside the current scope; kept so the bottom
/// navigation is complete.
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สำรวจ')),
      body: const NotImplementedView(screenName: 'ไอเดียทริปยอดนิยม'),
    );
  }
}
