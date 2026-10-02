import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../shared/widgets/not_implemented_view.dart';

/// วางแผนทริปใหม่ — built in #18.
class TripRequestScreen extends StatelessWidget {
  const TripRequestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('วางแผนทริปใหม่')),
      body: const NotImplementedView(
        screenName: 'วางแผนทริปใหม่',
        issue: 18,
        owner: 'Kritternai',
        shortcuts: [
          (
            label: 'ไม่ระบุจังหวัด → เสนอจังหวัด',
            location: AppRoutes.suggestions,
          ),
          (label: 'ระบุจังหวัด → สร้างแผน', location: AppRoutes.generating),
        ],
      ),
    );
  }
}
