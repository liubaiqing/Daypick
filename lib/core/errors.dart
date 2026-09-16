/// 统一错误类型：UI 层只面向这些类型做用户可读提示。
/// 对应技术开发文档第 6.4 / 14 章。
library;

/// 解析器基类异常
sealed class ParserException implements Exception {
  const ParserException(this.message);

  final String message;

  @override
  String toString() => 'ParserException: $message';
}

/// 离线解析失败（零命中等）
final class LocalParseException extends ParserException {
  const LocalParseException(super.message);
}

/// AI 解析失败（网络 / 认证 / 格式等）
final class AiParseException extends ParserException {
  const AiParseException(super.message);
}

/// 共享图文预处理失败。
final class ImageParseException extends ParserException {
  const ImageParseException(super.message);
}

/// 存储失败（保存 / 删除 / 迁移失败）
final class StorageException implements Exception {
  const StorageException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'StorageException: $message';
}
