import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:path/path.dart' as p;

import '../../core/constants.dart';
import '../../core/errors.dart';

class LocalModelConfig {
  const LocalModelConfig({
    this.url = kDefaultLocalUrl,
    this.model = kDefaultLocalModel,
  });
  final String url;
  final String model;

  Uri get endpoint {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        ![
          'localhost',
          '127.0.0.1',
          '::1',
          '[::1]',
        ].contains(uri.host.toLowerCase()) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        model.trim().isEmpty) {
      throw const LocalParseException(
        '本地服务只允许本机 HTTP(S) 地址和端口，请填写模型名（地址不含 /v1）',
      );
    }
    return uri.replace(path: '');
  }
}

abstract interface class LocalModelGateway {
  Future<Map<String, dynamic>> generate({
    required String system,
    required String text,
    required Map<String, dynamic> schema,
    String? image,
  });
}

/// 本地请求始终关闭思考；不继承桌面聊天参数，不跟随重定向。
class OllamaClient implements LocalModelGateway {
  OllamaClient(this.config, {Dio? dio, Future<bool> Function()? launcher})
    : _dio = dio ?? Dio(),
      _launcher = launcher ?? launchInstalledOllama {
    _dio.options.connectTimeout = const Duration(seconds: 5);
    if (dio == null) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () => HttpClient()..findProxy = (_) => 'DIRECT',
      );
    }
  }
  final LocalModelConfig config;
  final Dio _dio;
  final Future<bool> Function() _launcher;
  static final Map<String, Future<void>> _starting = {};

  Future<Response<dynamic>> _request(
    String path, {
    Object? data,
    Duration? timeout,
  }) async {
    final token = CancelToken();
    try {
      return await _dio
          .request<dynamic>(
            '${config.endpoint}$path',
            data: data,
            cancelToken: token,
            options: Options(
              method: data == null ? 'GET' : 'POST',
              followRedirects: false,
              sendTimeout: const Duration(seconds: 30),
              receiveTimeout: timeout ?? const Duration(seconds: 300),
              validateStatus: (s) => s != null && s >= 200 && s < 300,
            ),
          )
          .timeout(timeout ?? const Duration(seconds: 300));
    } finally {
      token.cancel();
    }
  }

  Future<void> check({bool autoStart = false}) async {
    _dio.options.connectTimeout = const Duration(seconds: 5);
    final key = config.endpoint.toString();
    try {
      await _request('/api/version', timeout: const Duration(seconds: 5));
    } catch (_) {
      if (!autoStart) {
        throw const LocalParseException('无法连接本机 Ollama，请启动服务或检查地址');
      }
      final pending = _starting.putIfAbsent(key, () => _startAndWait());
      try {
        await pending;
      } finally {
        if (identical(_starting[key], pending)) _starting.remove(key);
      }
    }
    try {
      final response = await _request(
        '/api/show',
        data: {'model': config.model},
        timeout: const Duration(seconds: 10),
      );
      final metadata = response.data as Map;
      if (metadata['remote_model'] != null || metadata['remote_host'] != null) {
        throw const LocalParseException('本地模式不允许 Ollama 云端模型，请选择已下载的本机模型');
      }
      final caps = metadata['capabilities'];
      if (caps is! List ||
          !caps.contains('vision') ||
          !caps.contains('completion')) {
        throw const LocalParseException('所选模型不支持图文解析，请选择 qwen3.5:4b 等视觉模型');
      }
    } on LocalParseException {
      rethrow;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw LocalParseException('模型 ${config.model} 未安装，请在 Ollama 中下载后重试');
      }
      throw const LocalParseException('无法检查模型，请确认 Ollama 版本与模型配置');
    } catch (_) {
      throw const LocalParseException('模型检查超时或返回格式异常');
    }
  }

  Future<void> _startAndWait() async {
    if (!await _launcher()) {
      throw const LocalParseException('未找到已安装的 Ollama，请手动启动后重试');
    }
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline)) {
      try {
        await _request('/api/version', timeout: const Duration(seconds: 1));
        return;
      } catch (_) {
        /* 启动中 */
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    throw const LocalParseException('Ollama 启动后仍无法连接，请检查服务地址和端口');
  }

  @override
  Future<Map<String, dynamic>> generate({
    required String system,
    required String text,
    required Map<String, dynamic> schema,
    String? image,
  }) async {
    try {
      final response = await _request(
        '/api/chat',
        data: {
          'model': config.model,
          'think': false,
          'stream': false,
          'keep_alive': '5m',
          'format': schema,
          'options': {
            'num_ctx': 8192,
            'num_predict': 2048,
            'temperature': 0.1,
            'presence_penalty': 0,
          },
          'messages': [
            {'role': 'system', 'content': system},
            {
              'role': 'user',
              'content': text,
              if (image != null) 'images': [image],
            },
          ],
        },
      );
      final data = response.data as Map;
      if (data['done'] != true || data['done_reason'] == 'length') {
        throw const LocalParseException('模型输出被截断，请减少内容后重试');
      }
      final decoded = jsonDecode((data['message'] as Map)['content'] as String);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      return decoded;
    } on LocalParseException {
      rethrow;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404) throw LocalParseException('模型 ${config.model} 未安装');
      if (status != null && status >= 300 && status < 400) {
        throw const LocalParseException('本地服务返回重定向，已阻止');
      }
      final detail = e.response?.data.toString().toLowerCase() ?? '';
      if (detail.contains('memory') || detail.contains('alloc')) {
        throw const LocalParseException('模型内存或显存不足，请关闭其他占用程序或减少图片大小');
      }
      throw const LocalParseException('本地模型连接失败或处理超时，请检查 Ollama 后重试');
    } catch (_) {
      throw const LocalParseException('本地模型超时或返回格式异常，请减少内容后重试');
    }
  }
}

/// 只启动已安装程序，使用参数数组，不拼接用户输入为 shell 命令。
Future<bool> launchInstalledOllama() async {
  if (!Platform.isWindows) return false;
  final candidates = <String>[];
  try {
    final result = await Process.run('where.exe', ['ollama.exe']);
    if (result.exitCode == 0) {
      candidates.addAll(
        result.stdout.toString().trim().split(RegExp(r'\r?\n')),
      );
    }
    final registry = await Process.run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      r"Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue | Where-Object DisplayName -Match '^Ollama' | ForEach-Object { if ($_.InstallLocation) { Join-Path $_.InstallLocation 'ollama.exe' } }",
    ]);
    candidates.addAll(
      registry.stdout.toString().trim().split(RegExp(r'\r?\n')),
    );
  } catch (_) {
    /* 使用默认安装位置 */
  }
  final local = Platform.environment['LOCALAPPDATA'];
  if (local != null) {
    candidates.add(p.join(local, 'Programs', 'Ollama', 'ollama.exe'));
  }
  for (final candidate in candidates.toSet()) {
    if (candidate.isEmpty || !File(candidate).existsSync()) continue;
    final app = p.join(p.dirname(candidate), 'ollama app.exe');
    // 优先桌面程序，保留其自定义模型目录。无桌面程序时隐藏启动 serve。
    final executable = File(app).existsSync() ? app : candidate;
    final escaped = executable.replaceAll("'", "''");
    final command =
        "Start-Process -FilePath '$escaped' -WindowStyle Hidden${executable == app ? '' : ' -ArgumentList serve'}";
    final result = await Process.run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      command,
    ]);
    if (result.exitCode == 0) return true;
  }
  return false;
}
