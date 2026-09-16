/// 在线图文解析接口；本地多模态入口为 LocalModelParser。
/// 两种入口输出统一的 ParsedEvent 草稿，进入同一条确认流程。
library;

import '../../core/errors.dart';
import '../../domain/parsed_event.dart';
import '../llm/openai_compatible_client.dart';

export '../../core/errors.dart' show ParserException;

abstract class EventParser {
  /// 解析文字及可选图片，输出结构化草稿列表。
  /// 解析失败抛 [ParserException]，不返回部分结果。
  Future<List<ParsedEvent>> parse(
    String text, {
    List<LlmImage> images = const [],
  });
}
