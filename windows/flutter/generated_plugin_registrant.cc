//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <pasteboard/pasteboard_plugin.h>
#include <screen_retriever_windows/screen_retriever_windows_plugin_c_api.h>
#include <window_manager/window_manager_plugin.h>
#include <winrt_ocr_flutter/winrt_ocr_flutter_plugin_c_api.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  PasteboardPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("PasteboardPlugin"));
  ScreenRetrieverWindowsPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("ScreenRetrieverWindowsPluginCApi"));
  WindowManagerPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("WindowManagerPlugin"));
  WinrtOcrFlutterPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("WinrtOcrFlutterPluginCApi"));
}
