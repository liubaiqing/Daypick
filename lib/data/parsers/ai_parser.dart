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
  final LlmGateway client;
  final AiConfig config;

  /// 可注入时钟便于测试（与 LocalParser 一致）
  final DateTime Function() _now;

  AiParser({required this.client, required this.config, DateTime Function()? now})
      : _now = now ?? DateTime.now;

  /// system prompt（文档 6.2 节）：要求严格按 JSON Schema 输出；
  /// **注入当前年月并规定：用户未指定年份/月份时一律使用当前年月**
  String get _systemPrompt {
    final now = _now();
    return '你是日历信息抽取助手。今天是${now.year}年${now.month}月。从用户文本中抽取全部事件，严格按以下 JSON 格式输出：'
        '{"events":[{"title":"字符串，事件标题","location":"地点或null",'
        '"start":"ISO8601本地时间如${now.year}-03-12T09:00:00，全天事件用当天00:00:00；无法确定时null",'
        '"end":"ISO8601或null","all_day":"布尔，无具体时刻为true",'
        '"note":"补充信息或null"}]}。规则：1)时间不确定时start为null而不是猜测；'
        '2)不输出任何JSON以外的文字；3)地点只取地名，不包含动词；'
        '4)**用户未在文本中指定年份时，年份一律使用当前年份（${now.year}）；'
        '用户仅提供"日"（未指定年月）时，年份月份一律使用当前年月（${now.year}年${now.month}月），不得猜测其他年月**。';
  }

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
          LlmChatMessage(role: 'system', content: _systemPrompt),
          LlmChatMessage(role: 'user', content: text),
        ],
      );
    } on LlmException catch (e) {
      throw AiParseException(e.message);
    }

    return _mapToEvents(json, text);
  }

  /// 解析 AI 返回的日期字符串（客户端兜底，文档 6.2 节）：
  /// 1) 完整 ISO8601；2) 用户文本无显式年份且年份≠当前年 → 强制当前年；
  /// 3) 宽松格式（缺年份的 M-d 或 M-dTH:m）→ 补当前年；
  /// 4) 仅提供日（缺年月，如 15 / 15T14:00）→ 补当前年月。
  DateTime? _parseDate(String raw, String sourceText) {
    final now = _now();
    final nowYear = now.year;
    final dt = DateTime.tryParse(raw);
    if (dt != null) {
      if (!_hasExplicitYear(sourceText) && dt.year != nowYear) {
        return DateTime(
          nowYear, dt.month, dt.day, dt.hour, dt.minute, dt.second,
        );
      }
      return dt;
    }
    // 宽松解析：M-d（缺年份）→ 补当前年
    final m = RegExp(
      r'(\d{1,2})[月/-](\d{1,2})(?:[T\s](\d{1,2}):(\d{2}))?',
    ).firstMatch(raw);
    if (m != null) {
      final month = int.parse(m.group(1)!);
      final day = int.parse(m.group(2)!);
      if (month < 1 || month > 12 || day < 1 || day > 31) return null;
      final hour = m.group(3) != null ? int.parse(m.group(3)!) : 0;
      final minute = m.group(4) != null ? int.parse(m.group(4)!) : 0;
      final parsed = DateTime(nowYear, month, day, hour, minute);
      if (parsed.day != day) return null; // 当月天数校验
      return parsed;
    }
    // 仅提供日（缺年月）→ 补当前年月（锚定整串，避免误匹配）
    final dm = RegExp(
      r'^(\d{1,2})(?:[T\s](\d{1,2}):(\d{2})(?::\d{2})?)?$',
    ).firstMatch(raw);
    if (dm != null) {
      final day = int.parse(dm.group(1)!);
      if (day < 1 || day > 31) return null;
      final hour = dm.group(2) != null ? int.parse(dm.group(2)!) : 0;
      final minute = dm.group(3) != null ? int.parse(dm.group(3)!) : 0;
      final parsed = DateTime(now.year, now.month, day, hour, minute);
      if (parsed.day != day) return null;
      return parsed;
    }
    return null;
  }

  /// 用户文本是否含显式年份（如 2026年 / 2026- / 2026/）
  bool _hasExplicitYear(String text) =>
      RegExp(r'\d{4}\s*[年/-]').hasMatch(text);

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
      var start = startStr == null ? null : _parseDate(startStr, text);
      var end = endStr == null ? null : _parseDate(endStr, text);
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
