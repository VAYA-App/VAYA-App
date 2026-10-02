import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../shared/widgets/not_implemented_view.dart';

/// ทริปของฉัน — built in #42.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ทริปของฉัน')),
      body: const NotImplementedView(
        screenName: 'ทริปของฉัน',
        issue: 42,
        owner: 'gunruethaiz',
        shortcuts: [
          (label: 'วางแผนทริปใหม่', location: AppRoutes.newTrip),
          (label: 'ดูแผนตัวอย่าง', location: '/trips/mock'),
        ],
      ),
    );
  }
}
