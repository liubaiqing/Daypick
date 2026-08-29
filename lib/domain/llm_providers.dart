/// AI 服务供应商预设（文档 11 章）：设置页下拉选择，选中自动回填 baseURL 与默认模型。
library;

class LlmProviderPreset {
  const LlmProviderPreset({
    required this.name,
    required this.baseUrl,
    required this.defaultModel,
  });

  /// 供应商显示名
  final String name;

  /// OpenAI 兼容 baseURL
  final String baseUrl;

  /// 默认模型名（用户仍可在设置页手动修改）
  final String defaultModel;
}

/// 常见 OpenAI 兼容供应商预设
const List<LlmProviderPreset> kLlmProviderPresets = [
  LlmProviderPreset(
    name: 'DeepSeek',
    baseUrl: 'https://api.deepseek.com',
    defaultModel: 'deepseek-chat',
  ),
  LlmProviderPreset(
    name: 'OpenAI',
    baseUrl: 'https://api.openai.com/v1',
    defaultModel: 'gpt-4o-mini',
  ),
  LlmProviderPreset(
    name: '通义千问',
    baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    defaultModel: 'qwen-plus',
  ),
  LlmProviderPreset(
    name: 'Kimi',
    baseUrl: 'https://api.moonshot.cn/v1',
    defaultModel: 'moonshot-v1-8k',
  ),
  LlmProviderPreset(
    name: '智谱 GLM',
    baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    defaultModel: 'glm-4-flash',
  ),
  LlmProviderPreset(
    name: '豆包',
    baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
    defaultModel: 'doubao-1-5-lite-32k-250115',
  ),
  LlmProviderPreset(
    name: 'Ollama（本地）',
    baseUrl: 'http://localhost:11434/v1',
    defaultModel: 'llama3.1',
  ),
  LlmProviderPreset(
    name: 'SiliconFlow',
    baseUrl: 'https://api.siliconflow.cn/v1',
    defaultModel: 'deepseek-ai/DeepSeek-V3',
  ),
  LlmProviderPreset(
    name: 'OpenRouter',
    baseUrl: 'https://openrouter.ai/api/v1',
    defaultModel: 'deepseek/deepseek-chat',
  ),
];

/// 按 baseUrl 反查预设（设置页加载时回显选中项）；未匹配返回 null（视为自定义）
LlmProviderPreset? presetForBaseUrl(String baseUrl) {
  for (final p in kLlmProviderPresets) {
    if (p.baseUrl == baseUrl) return p;
  }
  return null;
}
