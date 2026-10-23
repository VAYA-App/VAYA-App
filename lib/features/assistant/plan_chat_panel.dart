import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers/ai_providers.dart';
import '../../app/providers/planner_providers.dart';
import '../../domain/domain.dart';
import '../../planner/plan_chat.dart';
import '../../planner/plan_editor.dart';
import '../../shared/widgets/mascot_view.dart';
import '../trip_plan/trip_plan_view_provider.dart';

/// The chat that edits a plan, with the same pricing as the pipeline (#46).
final planChatProvider = FutureProvider<PlanChat>(
  (ref) async => PlanChat(
    gemini: ref.watch(geminiServiceProvider),
    editor: await ref.watch(planEditorProvider.future),
  ),
);

/// One line of the conversation. An assistant line with [edits] waits for
/// the traveller to confirm them against [plan], the plan it was made for.
final class _Line {
  _Line.user(this.text) : fromAi = false, edits = const [], plan = null;

  _Line.ai(this.text, {this.edits = const [], this.plan}) : fromAi = true;

  final bool fromAi;
  final String text;
  final List<PlanEdit> edits;
  final TripPlan? plan;
  bool answered = false;
}

/// Chat with the mascot about the trip [tripId]; proposed edits are shown
/// first and applied only after the traveller confirms (#46).
/// [onTripChanged] gets the new id when a read-only plan became a draft.
class PlanChatPanel extends ConsumerStatefulWidget {
  const PlanChatPanel({super.key, required this.tripId, this.onTripChanged});

  final String tripId;
  final ValueChanged<String>? onTripChanged;

  static const suggestions = [
    'วันที่ 2 ขอร้านอาหารทะเลแทน',
    'ขอที่เที่ยวสายคาเฟ่แทนจุดแรก',
    'ลบจุดที่ 2 วันที่ 1',
  ];

  @override
  ConsumerState<PlanChatPanel> createState() => _PlanChatPanelState();
}

class _PlanChatPanelState extends ConsumerState<PlanChatPanel> {
  late var _tripId = widget.tripId;
  final _lines = <_Line>[
    _Line.ai(
      'สวัสดี! ฉันช้างน้อย บอกได้เลยว่าอยากปรับแผนตรงไหน '
      'เช่น เปลี่ยนร้านอาหาร หรือลบจุดที่ไม่อยากไป',
    ),
  ];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  var _busy = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _add(_Line line) {
    setState(() => _lines.add(line));
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

  Future<void> _send(String text) async {
    final message = text.trim();
    if (message.isEmpty || _busy) return;
    _input.clear();
    _add(_Line.user(message));
    setState(() => _busy = true);
    try {
      final view = await ref.read(tripPlanViewProvider(_tripId).future);
      final chat = await ref.read(planChatProvider.future);
      if (view == null) throw StateError('No trip $_tripId');
      final reply = await chat.ask(
        message,
        plan: view.plan,
        request: view.request,
        catalog: view.catalog,
      );
      _add(_Line.ai(reply.text, edits: reply.edits, plan: view.plan));
    } catch (_) {
      _add(_Line.ai('ขอโทษนะ ตอนนี้ตอบไม่ได้ ลองใหม่อีกครั้ง'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _answer(_Line line, {required bool accept}) async {
    setState(() => line.answered = true);
    if (!accept) {
      _add(_Line.ai('ได้เลย ไม่เปลี่ยนนะ'));
      return;
    }
    setState(() => _busy = true);
    try {
      final view = await ref.read(tripPlanViewProvider(_tripId).future);
      // The proposal points at Stops of the plan it was made for.
      if (!identical(view?.plan, line.plan)) {
        _add(_Line.ai('แผนเปลี่ยนไปแล้ว ลองขอใหม่อีกครั้งนะ'));
        return;
      }
      final id = await ref
          .read(tripPlanEditsProvider)
          .applyAll(_tripId, line.edits);
      if (id != _tripId) {
        _tripId = id;
        widget.onTripChanged?.call(id);
      }
      _add(_Line.ai('เรียบร้อย! ปรับแผนและคำนวณค่าใช้จ่ายใหม่ให้แล้ว'));
    } catch (_) {
      _add(_Line.ai('ปรับแผนไม่สำเร็จ ลองขอใหม่อีกครั้งนะ'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              for (final line in _lines) ...[
                _Bubble(line: line),
                if (line.edits.isNotEmpty && !line.answered) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 48),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.check),
                          label: const Text('เปลี่ยนเลย'),
                          onPressed: _busy
                              ? null
                              : () => _answer(line, accept: true),
                        ),
                        ActionChip(
                          label: const Text('ไม่เป็นไร'),
                          onPressed: _busy
                              ? null
                              : () => _answer(line, accept: false),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
              if (_busy) const LinearProgressIndicator(),
            ],
          ),
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final s in PlanChatPanel.suggestions) ...[
                ActionChip(
                  avatar: const Icon(Icons.auto_awesome),
                  label: Text(s),
                  onPressed: _busy ? null : () => _send(s),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                onPressed: _busy ? null : () => _send(_input.text),
                icon: const Icon(Icons.send),
                tooltip: 'ส่ง',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.line});

  final _Line line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final fromAi = line.fromAi;
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
            line.text,
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
