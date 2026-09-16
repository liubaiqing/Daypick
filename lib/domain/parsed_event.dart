/// 解析草稿模型（文档 4.2 节）：解析产物仅存在于内存，确认后才转为数据库事件。
library;

import 'event_source_type.dart';

/// 缺失字段标记：确认卡片上红色提示"请人工补充"
enum MissingField { time, location, title }

class ParsedEvent {
  const ParsedEvent({
    required this.title,
    this.location,
    this.start,
    this.end,
    this.allDay = false,
    this.note,
    required this.sourceType,
    required this.sourceText,
    this.missing = const {},
    this.confidence = 0,
  });

  /// 事件标题；空串表示缺失标题（missing 含 title）
  final String title;

  final String? location;

  /// 开始时间；null 表示未识别出时间（missing 含 time）
  final DateTime? start;

  /// 结束时间；全天事件为 null；单一时刻事件也为 null
  final DateTime? end;

  final bool allDay;

  final String? note;

  /// 来源：文本解析 / 图片（视觉或 OCR）/ 手动
  final EventSourceType sourceType;

  /// 该草稿对应的原始文本（确认入库时记入 sourceText）
  final String sourceText;

  /// 缺失字段警告集
  final Set<MissingField> missing;

  /// 兼容旧草稿的核对提示阈值；本地模型统一为 0，要求人工核对，不代表概率。
  final double confidence;

  bool get hasMissingTime => missing.contains(MissingField.time);
  bool get hasMissingLocation => missing.contains(MissingField.location);
  bool get hasMissingTitle => missing.contains(MissingField.title);

  /// <0.5 视为低置信，确认卡片显示"建议人工核对"
  bool get lowConfidence => confidence < 0.5;

  /// 日期早于今天（"昨天/前天"等过去日期），UI 提示但不拦截保存
  bool isPastDate(DateTime now) {
    final d = start ?? end;
    if (d == null) return false;
    final today = DateTime(now.year, now.month, now.day);
    return d.isBefore(today);
  }
}
