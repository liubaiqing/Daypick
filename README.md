# 拾日 · Daypick

拾起琐事，安排每日。

轻量 Windows 桌面事务日历：从文字、通知截图中提取日程，经人工确认后保存到本地。

- 本地 Qwen3.5 图文解析（依赖独立部署的 Ollama），也支持在线 AI。
- 月历、可编辑草稿、备份恢复与回收站。
- 浅色、深色与毛玻璃主题。

开发与数据约定见 [技术开发文档](技术开发文档.md)。

```powershell
flutter pub get
flutter analyze
flutter test
flutter build windows --release
```

构建产物为 `build/windows/x64/runner/Release/Daypick.exe`，分发需包含整个 Release 目录；模型权重不随包提供。

为兼容已有日程，内部包名、Windows 数据目录标识和备份标识仍保留 `calendar`，不影响展示名称。
