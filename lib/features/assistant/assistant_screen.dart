import 'package:material_ui/material_ui.dart';

import '../../shared/widgets/not_implemented_view.dart';

/// Chat with the AI to adjust a plan (S2).
class AssistantScreen extends StatelessWidget {
  const AssistantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI ช่วยคิด')),
      body: const NotImplementedView(screenName: 'แชทปรับแผนกับ AI', issue: 46),
    );
  }
}
