#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <dwmapi.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"拾日 · Daypick", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  // Windows 11 原生窗口圆角（DWM，文档 9.1 节）：
  // DWMWA_WINDOW_CORNER_PREFERENCE=33 + DWMWCP_ROUND=2；
  // 最大化时系统自动切回直角；非 Win11 环境返回失败，静默忽略。
  const DWORD kWindowCornerPreference = 33;
  const DWORD kCornerRound = 2;
  ::DwmSetWindowAttribute(window.GetHandle(), kWindowCornerPreference,
                          &kCornerRound, sizeof(kCornerRound));

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
