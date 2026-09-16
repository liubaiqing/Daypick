/// OpenAI 兼容 Chat Completions 客户端（文档 6 章）。
/// 默认预置 DeepSeek（baseURL https://api.deepseek.com，model deepseek-chat）。
library;

import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/constants.dart';

/// LLM 请求失败（含状态码与用户可读信息）
class LlmException implements Exception {
  const LlmException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'LlmException: $message';
}

/// 聊天消息
class LlmChatMessage {
  const LlmChatMessage({
    required this.role,
    required this.content,
    this.images = const [],
  });

  final String role;
  final String content;
  final List<LlmImage> images;

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': images.isEmpty
        ? content
        : [
            {'type': 'text', 'text': content},
            for (var i = 0; i < images.length; i++) ...[
              {'type': 'text', 'text': '图片${i + 1}'},
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/png;base64,${images[i].base64Png}',
                },
              },
            ],
          ],
  };
}

/// 预处理后的图片仅随请求驻留内存；文件名用于草稿来源，不发送本机路径。
class LlmImage {
  const LlmImage({required this.name, required this.base64Png});
  final String name;
  final String base64Png;
}

/// LLM 网关抽象（便于 AiParser 测试注入 fake，文档 15.3 节）
abstract class LlmGateway {
  Future<Map<String, dynamic>> chatJson({
    required String baseUrl,
    required String apiKey,
    required String model,
    required List<LlmChatMessage> messages,
  });
}

class OpenAiCompatibleClient implements LlmGateway {
  OpenAiCompatibleClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(
                milliseconds: kLlmConnectTimeoutMs,
              ),
              receiveTimeout: const Duration(
                milliseconds: kLlmReceiveTimeoutMs,
              ),
            ),
          );

  final Dio _dio;

  @override
  Future<Map<String, dynamic>> chatJson({
    required String baseUrl,
    required String apiKey,
    required String model,
    required List<LlmChatMessage> messages,
  }) async {
    final payload = <String, dynamic>{
      'model': model,
      'temperature': kLlmTemperature,
      'max_tokens': kLlmMaxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [for (final m in messages) m.toJson()],
    };

    Map<String, dynamic>? data;
    for (var attempt = 0; attempt <= kLlmRetryCount; attempt++) {
      try {
        final resp = await _dio.post<Map<String, dynamic>>(
          '$baseUrl/chat/completions',
          data: payload,
          options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
        );
        data = resp.data;
        break;
      } on DioException catch (e) {
        final code = e.response?.statusCode;
        if (code == 401) {
          throw const LlmException('API Key 无效，请到设置页检查');
        }
        if (code == 402) {
          throw const LlmException('账户额度不足，请检查余额');
        }
        if (code == 429) {
          if (attempt < kLlmRetryCount) {
            await Future<void>.delayed(kLlmRetryDelay);
            continue;
          }
          throw const LlmException('请求过于频繁，请稍后再试');
        }
        if (code != null && code >= 400 && code < 500) {
          if (code == 413) {
            throw const LlmException('图文请求过大，请减少图片数量后重试');
          }
          if (messages.any((m) => m.images.isNotEmpty)) {
            throw LlmException('图文请求被拒绝（HTTP $code），请检查服务地址、模型名及服务对图片格式和数量的限制');
          }
          throw LlmException('请求被拒绝（HTTP $code），请检查 baseURL 与 Key');
        }
        if (attempt < kLlmRetryCount) {
          await Future<void>.delayed(kLlmRetryDelay);
          continue;
        }
      } catch (_) {
        if (attempt < kLlmRetryCount) {
          await Future<void>.delayed(kLlmRetryDelay);
          continue;
        }
      }
    }

    if (data == null) {
      throw const LlmException('网络异常或服务超时，请稍后重试');
    }
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const LlmException('服务返回异常（无 choices）');
    }
    final content =
        (choices.first as Map<String, dynamic>)['message']?['content'];
    if (content is! String) {
      throw const LlmException('服务返回异常（无内容）');
    }
    try {
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        throw const LlmException('AI 返回格式异常，建议切换本地模式重试');
      }
      return decoded;
    } on FormatException {
      throw const LlmException('AI 返回格式异常，建议切换本地模式重试');
    }
  }

  /// 测试连接：GET {baseUrl}/models（设置页"测试连接"，文档 11 章）
  Future<void> testConnection({
    required String baseUrl,
    required String apiKey,
  }) async {
    try {
      await _dio.get<dynamic>(
        '$baseUrl/models',
        options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
      );
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401) throw const LlmException('API Key 无效');
      if (code == 402) throw const LlmException('账户额度不足');
      throw LlmException('连接失败（HTTP ${code ?? '未知'}）');
    }
  }
}
