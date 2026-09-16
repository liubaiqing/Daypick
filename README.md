# 拾日 · Daypick

拾起琐事，安排每日。

轻量 Windows 桌面事务日历：从文字、通知截图中提取日程，经人工确认后保存到本地。

- 本地 Qwen3.5 图文解析（依赖独立部署的 Ollama），也支持在线 AI。
- 月历、可编辑草稿、备份恢复与回收站。
- 浅色、深色与毛玻璃主题。

## 使用方式

支持 Windows 10 21H2+／Windows 11 x64。输入文字或上传、拖入、粘贴通知图片，选择“本地”或“AI”解析，在草稿中核对后保存；也可通过日期列表的“＋”手动新建。当前不提供提醒、多端同步或重复事件。

### 本地解析

先独立安装 [Ollama](https://ollama.com/)，再下载模型：

```powershell
ollama pull qwen3.5:4b
```

在设置→本地模型中使用 `http://127.0.0.1:11434`、`qwen3.5:4b`，点击“检查”并保存。检查成功只表示服务和模型能力可用，仍需用实际输入验证。模型下载需联网，部署后可离线解析；应用不会自动下载或升级模型。

日历请求显式关闭思考，最多同时处理两张图片；不影响 Ollama 自己的聊天设置。性能取决于本机硬件。混合输入归属不清时会提示澄清，所有结果都需要人工核对。

### 在线 AI

在设置→AI 服务中填写供应商、地址、API Key 和模型（例如已开通的Qwen-VL），再切换输入条到“AI”。同一模型统一处理文字、图片和混合输入，不设置模型类型选项。本批图片与文字直接发送到所选服务，可能产生供应商费用；服务拒绝请求时保留输入，不做OCR兜底或自动切换服务。

两种模式均将图片等比缩小至最长边2000px并转PNG，GIF只处理首帧。在线多图按上传顺序一并提交；模型提示归属不清时，补充文字后重试。

## 开发与构建

需要 Flutter（Dart SDK ≥3.13.2、<4.0.0）、Git，以及安装“使用 C++ 的桌面开发”工作负载的 Visual Studio。当前验证环境为 Flutter 3.47.2／Dart 3.13.2。先运行 `flutter doctor -v` 检查环境。

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d windows
flutter build windows --release
```

构建产物为 `build/windows/x64/runner/Release/Daypick.exe`，分发需包含整个 Release 目录；模型权重不随包提供。

普通测试不依赖运行中的 Ollama；真实模型验收需显式启用，见 [技术开发文档](技术开发文档.md)。本仓库上传源码不等于发布 Windows 安装包。

## 数据与隐私

- 日程与设置保存在本机 SQLite；API Key 当前为明文存储，勿分享数据库。
- 本地模式仅连接回环地址，失败不自动切换在线；在线模式会向配置的服务发送本批文字和图片内容，不发送日历数据库。图片Base64不写入事务记录。
- JSON 备份不包含 API Key、设置及回收站；删除事件可从回收站恢复，彻底清理不可恢复。
- 数据库、备份、密钥、构建产物和本机 `AGENTS.md` 不入库。提交前仍需人工检查，忽略规则不替代敏感信息审查。

为兼容已有日程，内部包名、Windows 数据目录标识和备份标识仍保留 `calendar`，不影响展示名称。

## 图标与第三方资源

沿用原有 Windows 图标 `windows/runner/resources/app_icon.ico`，未采用的品牌设计稿已移除。

本应用使用 HarmonyOS Sans SC 字体，版权归 Huawei Device Co., Ltd.，许可见 [字体许可](assets/fonts/LICENSE.txt)。RapidOCR及PP-OCRv5资源已移除；本地Qwen权重由用户独立部署，不包含在仓库中。各第三方组件遵循各自许可证。

项目尚未选择整体开源许可证；公开源码不表示额外授予使用或再分发许可。
