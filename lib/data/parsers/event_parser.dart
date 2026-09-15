/// 在线文本解析接口；本地多模态入口为 LocalModelParser。
/// 两种入口输出统一的 ParsedEvent 草稿，进入同一条确认流程。
library;

import '../../core/errors.dart';
import '../../domain/parsed_event.dart';

export '../../core/errors.dart' show ParserException;

abstract class EventParser {
  /// 解析原文（文本或 OCR 结果），输出结构化草稿列表。
  /// 解析失败抛 [ParserException]，不返回部分结果。
  Future<List<ParsedEvent>> parse(String text);
}
