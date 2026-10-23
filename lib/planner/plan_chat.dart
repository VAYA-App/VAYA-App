import '../ai/gemini_service.dart';
import '../ai/prompts/edit_plan.dart';
import '../domain/domain.dart';
import 'plan_editor.dart';

/// What the assistant says, and the edits it proposes for the traveller to
/// confirm. No edits means it is only talking.
final class PlanChatReply {
  const PlanChatReply(this.text, {this.edits = const []});

  final String text;
  final List<PlanEdit> edits;
}

/// The AI chat that edits a plan (#46): Gemini proposes, [editor] checks
/// that every proposal fits the plan, Gemini gets one retry with the
/// problems, and without Gemini a keyword reader handles the common asks.
class PlanChat {
  const PlanChat({required this.gemini, required this.editor});

  final GeminiService gemini;
  final PlanEditor editor;

  static const maxAttempts = 2;

  Future<PlanChatReply> ask(
    String message, {
    required TripPlan plan,
    required TripRequest request,
    required PlaceCatalog catalog,
  }) async {
    var errors = <String>[];
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final json = await gemini.generateJson(
          systemInstruction: EditPlanPrompt.systemInstruction,
          prompt: EditPlanPrompt.build(
            message: message,
            plan: plan,
            request: request,
            catalog: catalog,
            previousErrors: errors,
          ),
          responseSchema: EditPlanPrompt.responseSchema,
        );
        final (:reply, :edits) = EditPlanPrompt.parse(json);
        if (edits.isNotEmpty) {
          // Throws when a proposal does not fit; the result is not kept.
          editor.applyAll(
            edits,
            plan: plan,
            request: request,
            catalog: catalog,
          );
        }
        if (reply.isEmpty) throw const FormatException('Empty reply');
        return PlanChatReply(reply, edits: edits);
      } on GeminiException {
        // Offline, timed out or not connected: asking again will not help.
        break;
      } on FormatException catch (e) {
        errors = ['The answer did not match the JSON schema: ${e.message}'];
      } on ArgumentError catch (e) {
        errors = ['An edit does not fit the plan: ${e.message}'];
      }
    }
    return KeywordPlanChat.reply(message, plan: plan, catalog: catalog);
  }
}

/// Understands the common asks without Gemini, such as
/// "วันที่ 2 ขอร้านอาหารทะเลแทน" or "ลบจุดที่ 3 วันที่ 1".
abstract final class KeywordPlanChat {
  static const help =
      'ช้างน้อยยังไม่เข้าใจ ลองพิมพ์แบบนี้นะ เช่น '
      '"วันที่ 2 ขอร้านอาหารทะเลแทน" หรือ "ลบจุดที่ 3 วันที่ 1"';

  /// Longer phrases first, so "อาหารทะเล" means seafood, not the beach.
  static const _tagWords = [
    ('อาหารทะเล', PreferenceTag.seafood),
    ('ซีฟู้ด', PreferenceTag.seafood),
    ('อาหารท้องถิ่น', PreferenceTag.localFood),
    ('ทะเล', PreferenceTag.beach),
    ('ชายหาด', PreferenceTag.beach),
    ('หาด', PreferenceTag.beach),
    ('คาเฟ่', PreferenceTag.cafe),
    ('กาแฟ', PreferenceTag.cafe),
    ('วัด', PreferenceTag.templeHistory),
    ('ประวัติศาสตร์', PreferenceTag.templeHistory),
    ('พิพิธภัณฑ์', PreferenceTag.artCulture),
    ('ศิลปะ', PreferenceTag.artCulture),
    ('ช้อป', PreferenceTag.shopping),
    ('ห้าง', PreferenceTag.shopping),
    ('ตลาด', PreferenceTag.shopping),
    ('ธรรมชาติ', PreferenceTag.nature),
    ('สวน', PreferenceTag.nature),
    ('วิว', PreferenceTag.viewpoint),
    ('สปา', PreferenceTag.wellness),
    ('นวด', PreferenceTag.wellness),
    ('เด็ก', PreferenceTag.family),
    ('ครอบครัว', PreferenceTag.family),
    ('กลางคืน', PreferenceTag.nightlife),
    ('บาร์', PreferenceTag.nightlife),
    ('ผจญภัย', PreferenceTag.adventure),
  ];

  static const _removeWords = ['ลบ', 'เอาออก', 'ตัดออก', 'ไม่ไป', 'ไม่เอา'];
  static const _foodWords = ['ร้าน', 'อาหาร', 'กิน', 'มื้อ', 'ซีฟู้ด'];

  static PlanChatReply reply(
    String message, {
    required TripPlan plan,
    required PlaceCatalog catalog,
  }) {
    final text = message.replaceAll(' ', '');
    int? number(String pattern) => switch (RegExp(pattern).firstMatch(text)) {
      final m? => int.parse(m.group(1)!) - 1,
      null => null,
    };
    final day =
        number(r'วัน(?:ที่)?(\d+)') ?? (plan.days.length == 1 ? 0 : null);
    final stopNumber = number(r'จุด(?:ที่)?(\d+)');
    if (day != null && (day < 0 || day >= plan.days.length)) {
      return PlanChatReply(
        'ทริปนี้มี ${plan.days.length} วัน ลองระบุวันใหม่นะ',
      );
    }

    final tags = <PreferenceTag>{};
    var rest = text;
    for (final (word, tag) in _tagWords) {
      if (rest.contains(word)) {
        tags.add(tag);
        rest = rest.replaceAll(word, '');
      }
    }
    final wantsFood =
        _foodWords.any(text.contains) || tags.contains(PreferenceTag.seafood);
    final removing = _removeWords.any(text.contains);

    // Which Stop: the number given, or the first of the right kind.
    (int, int)? target;
    if (day != null && stopNumber != null) {
      if (stopNumber >= 0 && stopNumber < plan.days[day].stops.length) {
        target = (day, stopNumber);
      }
    } else if (removing || tags.isNotEmpty || wantsFood) {
      for (final (d, dayPlan) in plan.days.indexed) {
        if (day != null && d != day) continue;
        for (final (i, stop) in dayPlan.stops.indexed) {
          if (stop.slot.isMeal == wantsFood) {
            target = (d, i);
            break;
          }
        }
        if (target != null) break;
      }
    }
    if (target == null) return const PlanChatReply(help);

    final (d, i) = target;
    final current = catalog.place(plan.days[d].stops[i].placeId);
    if (removing) {
      if (plan.days[d].stops.length == 1) {
        return const PlanChatReply('วันนั้นเหลือจุดเดียวแล้ว ลบไม่ได้นะ');
      }
      return PlanChatReply(
        'ลบ${current.name}ออกจากวันที่ ${d + 1} ให้ไหม?',
        edits: [RemoveStop(day: d, index: i)],
      );
    }

    final options = PlanEditor.alternatives(
      plan,
      catalog,
      day: d,
      index: i,
      count: 1000,
    );
    final matching = tags.isEmpty
        ? options
        : [
            for (final p in options)
              if (p.tags.any(tags.contains)) p,
          ];
    if (matching.isEmpty) {
      return PlanChatReply(
        'ยังหาที่ใหม่แทน${current.name}ที่ตรงกับที่ขอไม่เจอ ลองบอกแบบอื่นนะ',
      );
    }
    final next = matching.first;
    return PlanChatReply(
      'เปลี่ยน${current.name}เป็น${next.name} '
      '(${next.tags.map((t) => t.label).join(' ')}) ในวันที่ ${d + 1} ให้ไหม?',
      edits: [ReplaceStop(day: d, index: i, placeId: next.id)],
    );
  }
}
