import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../shared/widgets/not_implemented_view.dart';

/// แผนการเดินทาง — built in #39.
class TripPlanScreen extends StatelessWidget {
  const TripPlanScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('แผนการเดินทาง · $tripId')),
      body: const NotImplementedView(
        screenName: 'แผนการเดินทาง',
        issue: 39,
        owner: 'Kritternai',
        shortcuts: [(label: 'กลับหน้าแรก', location: AppRoutes.home)],
      ),
    );
  }
}
