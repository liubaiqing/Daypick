/// AI 解析引擎（文档 6 章）：OpenAI 兼容 + JSON Schema 结构化输出，
/// 输出与 LocalParser 统一为 ParsedEvent，共用确认流程。
library;

import '../../core/errors.dart';
import '../../domain/event_source_type.dart';
import '../../domain/parsed_event.dart';
import '../llm/openai_compatible_client.dart';
import 'event_parser.dart';

/// AI 解析所需配置（来自设置页）
class AiConfig {
  const AiConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  final String baseUrl;
  final String apiKey;
  final String model;
}

class AiParser implements EventParser {
  AiParser({required this.client, required this.config});

  final LlmGateway client;
  final AiConfig config;

  /// system prompt（文档 6.2 节）：要求严格按 JSON Schema 输出
  static const String systemPrompt =
      '你是日历信息抽取助手。从用户文本中抽取全部事件，严格按以下 JSON 格式输出：'
      '{"events":[{"title":"字符串，事件标题","location":"地点或null",'
      '"start":"ISO8601本地时间如2025-03-12T09:00:00，全天事件用当天00:00:00；无法确定时null",'
      '"end":"ISO8601或null","all_day":"布尔，无具体时刻为true",'
      '"note":"补充信息或null"}]}。规则：1)时间不确定时start为null而不是猜测；'
      '2)不输出任何JSON以外的文字；3)地点只取地名，不包含动词。';

  @override
  Future<List<ParsedEvent>> parse(String text) async {
    if (config.apiKey.trim().isEmpty) {
      throw const AiParseException('尚未配置 API Key，请到设置页填写后重试');
    }
    if (config.baseUrl.trim().isEmpty || config.model.trim().isEmpty) {
      throw const AiParseException('baseURL 或模型名未配置，请到设置页检查');
    }

    Map<String, dynamic> json;
    try {
      json = await client.chatJson(
        baseUrl: config.baseUrl,
        apiKey: config.apiKey,
        model: config.model,
        messages: [
          const LlmChatMessage(role: 'system', content: systemPrompt),
          LlmChatMessage(role: 'user', content: text),
        ],
      );
    } on LlmException catch (e) {
      throw AiParseException(e.message);
    }

    return _mapToEvents(json, text);
  }

  List<ParsedEvent> _mapToEvents(Map<String, dynamic> json, String text) {
    final rawList = json['events'];
    if (rawList is! List) {
      throw const AiParseException('AI 返回格式异常，建议切换本地模式重试');
    }
    final events = <ParsedEvent>[];
    for (final raw in rawList) {
      if (raw is! Map<String, dynamic>) continue;
      final title = (raw['title'] as String?)?.trim() ?? '';
      if (title.isEmpty) continue; // 标题为空丢弃该条（文档 6.2 节）

      final startStr = raw['start'] as String?;
      final endStr = raw['end'] as String?;
      final allDay = raw['all_day'] == true;
      var start = startStr == null ? null : DateTime.tryParse(startStr);
      var end = endStr == null ? null : DateTime.tryParse(endStr);
      if (allDay) {
        // 全天：start 归零、end 置空（文档 6.2 节）
        start = start == null
            ? null
            : DateTime(start.year, start.month, start.day);
        end = null;
      } else if (end != null && start != null && end.isBefore(start)) {
        // 跨天区间：结束加一天（与本地模式一致）
        end = end.add(const Duration(days: 1));
      }

      final location = (raw['location'] as String?)?.trim();
      final note = (raw['note'] as String?)?.trim();
      events.add(
        ParsedEvent(
          title: title,
          location: (location == null || location.isEmpty) ? null : location,
          start: start,
          end: end,
          allDay: allDay,
          note: (note == null || note.isEmpty) ? null : note,
          sourceType: EventSourceType.text,
          sourceText: text,
          missing: {
            if (start == null) MissingField.time,
            if (location == null || location.isEmpty) MissingField.location,
          },
          confidence: 0.9, // AI 模式默认高置信（不显示"建议核对"）
        ),
      );
    }
    if (events.isEmpty) {
      throw const AiParseException('AI 未能从文本中抽取到事件信息');
    }
    return events;
  }
}
