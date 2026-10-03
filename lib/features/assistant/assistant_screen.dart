import 'package:material_ui/material_ui.dart';

import '../../app/layout/window_size_class.dart';
import '../../shared/widgets/coming_soon.dart';
import '../../shared/widgets/mascot_view.dart';

/// Chat with the AI to adjust a plan (S2, #46).
///
/// For now a mock conversation with the mascot as the assistant's face
/// (#83). Anything the user sends gets a canned "coming soon" reply.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

typedef _Message = ({bool fromAi, String text});

class _AssistantScreenState extends State<AssistantScreen> {
  static const _feature = 'แชทปรับแผนกับ AI';
  static const _issue = 46;

  static const _suggestions = [
    'ขอที่เที่ยวสายคาเฟ่เพิ่ม',
    'ลดงบวันที่ 2 หน่อย',
    'อยากได้เวลาพักมากขึ้น',
  ];

  static const _comingSoonReply =
      'ขอบคุณที่บอกนะ ตอนนี้ช้างน้อยยังเป็นตัวอย่างอยู่ '
      'ปรับแผนผ่านแชทได้จริงเร็ว ๆ นี้ (#$_issue)';

  final _messages = <_Message>[
    (
      fromAi: true,
      text:
          'สวัสดี! ฉันช้างน้อย ผู้ช่วยวางแผนทริปของ VAYA '
          'บอกได้เลยว่าอยากปรับแผนตรงไหน',
    ),
    (fromAi: false, text: 'วันที่ 2 ขอร้านอาหารทะเลแทนได้ไหม'),
    (
      fromAi: true,
      text:
          'ได้เลย! เปลี่ยน Pier 21 เป็นตลาดหนองมน '
          'ซีฟู้ดสด ราคาโดยประมาณ ฿350/คน ให้เปลี่ยนไหม?',
    ),
  ];
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(String text) {
    final message = text.trim();
    if (message.isEmpty) return;
    _input.clear();
    setState(() {
      _messages
        ..add((fromAi: false, text: message))
        ..add((fromAi: true, text: _comingSoonReply));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final margin = context.windowSizeClass.pageMargin;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const MascotAvatar(radius: 18),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AI ช่วยคิด'),
                  Text(
                    'ช้างน้อย · ผู้ช่วยวางแผนทริป',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: WindowSizeClass.maxContentWidth,
          ),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: EdgeInsets.fromLTRB(margin, 8, margin, 16),
                  children: [
                    const _DemoNotice(),
                    const SizedBox(height: 16),
                    for (final m in _messages) ...[
                      _Bubble(message: m),
                      const SizedBox(height: 12),
                    ],
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.check),
                          label: const Text('เปลี่ยนเลย'),
                          onPressed: () =>
                              showComingSoon(context, _feature, issue: _issue),
                        ),
                        ActionChip(
                          label: const Text('ไม่เป็นไร'),
                          onPressed: () =>
                              showComingSoon(context, _feature, issue: _issue),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: margin),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final s in _suggestions) ...[
                        ActionChip(
                          avatar: const Icon(Icons.auto_awesome),
                          label: Text(s),
                          onPressed: () => _send(s),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(margin, 8, margin, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _send,
                        decoration: const InputDecoration(
                          hintText: 'พิมพ์สิ่งที่อยากปรับในแผน',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () => _send(_input.text),
                      icon: const Icon(Icons.send),
                      tooltip: 'ส่ง',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Says plainly that the chat is a preview.
class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card.filled(
      color: colors.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: colors.onTertiaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'ตัวอย่างบทสนทนา ฟีเจอร์ปรับแผนด้วยแชทกำลังพัฒนา (#46)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onTertiaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final _Message message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final fromAi = message.fromAi;
    const corner = Radius.circular(20);

    final bubble = Flexible(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fromAi ? colors.surfaceContainerHigh : colors.primaryContainer,
          borderRadius: BorderRadius.only(
            topLeft: fromAi ? const Radius.circular(4) : corner,
            topRight: fromAi ? corner : const Radius.circular(4),
            bottomLeft: corner,
            bottomRight: corner,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            message.text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: fromAi ? colors.onSurface : colors.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );

    return Semantics(
      label: fromAi ? 'ช้างน้อย' : 'คุณ',
      child: Row(
        mainAxisAlignment: fromAi
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: fromAi
            ? [const MascotAvatar(), const SizedBox(width: 8), bubble]
            : [const SizedBox(width: 48), bubble],
      ),
    );
  }
}
