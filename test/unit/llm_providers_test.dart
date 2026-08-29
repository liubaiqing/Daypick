// AI 供应商预设单元测试（文档 11 章）：列表完整性、baseURL 唯一、反查匹配。
import 'package:calendar/domain/llm_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('预设列表非空且 baseURL 唯一、字段完整', () {
    expect(kLlmProviderPresets.length, greaterThanOrEqualTo(5));
    final urls = kLlmProviderPresets.map((p) => p.baseUrl).toSet();
    expect(urls.length, kLlmProviderPresets.length);
    for (final p in kLlmProviderPresets) {
      expect(p.name, isNotEmpty);
      expect(p.baseUrl, startsWith('http'));
      expect(p.defaultModel, isNotEmpty);
    }
  });

  test('presetForBaseUrl 命中预设 / 未命中返回 null（自定义）', () {
    expect(presetForBaseUrl('https://api.deepseek.com')?.name, 'DeepSeek');
    expect(presetForBaseUrl('https://example.com/v1'), isNull);
  });
}
