/// 应用级常量：集中管理，避免魔法值散落各处。
/// 对应技术开发文档第 2.2 / 4.1 / 7 / 6.3 节。
library;

/// 应用显示名（窗口标题、导出 PRODID 等统一使用）
const String kAppName = 'calendar';

/// 数据库文件名（位于 path_provider 的 getApplicationSupportDirectory() 下）
const String kDatabaseFileName = 'calendar.sqlite';

// ---- settings 表 key 约定（见文档 4.1 节） ----
const String kSettingParseMode = 'parseMode';
const String kSettingLlmBaseUrl = 'llmBaseUrl';
const String kSettingLlmApiKey = 'llmApiKey';
const String kSettingLlmModel = 'llmModel';
const String kSettingSidebarCollapsed = 'sidebarCollapsed'; // '1' 收起 / '0' 展开
const String kSettingAnimationsEnabled = 'animationsEnabled'; // '0' 关闭动画 / 默认开启

/// 解析模式取值（settings.parseMode）
const String kParseModeLocal = 'local';
const String kParseModeAi = 'ai';

/// 默认解析模式：本地模式（离线可用、无需 API Key）
const String kDefaultParseMode = kParseModeLocal;

// ---- 默认 LLM 配置（OpenAI 兼容，用户可在设置页覆盖）----
const String kDefaultLlmBaseUrl = 'https://api.deepseek.com';
const String kDefaultLlmModel = 'deepseek-chat';

// ---- 窗口（见文档 9.1 节）----
const double kWindowDefaultWidth = 1100;
const double kWindowDefaultHeight = 720;
const double kWindowMinWidth = 900;
const double kWindowMinHeight = 600;

// ---- OCR 预处理（见文档 7.2 节）----
const int kOcrMaxImageDimension = 2000;

// ---- LLM 网络参数（见文档 6.3 节）----
const int kLlmConnectTimeoutMs = 10000;
const int kLlmReceiveTimeoutMs = 30000;
const int kLlmMaxTokens = 2000;
const double kLlmTemperature = 0.1;
const int kLlmRetryCount = 1;
const Duration kLlmRetryDelay = Duration(seconds: 2);
