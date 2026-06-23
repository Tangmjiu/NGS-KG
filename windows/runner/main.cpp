#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <bitsdojo_window_windows/bitsdojo_window_plugin.h>

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

  // bitsdojo_window: 提供 MoveWindow / appWindow 等 Flutter 组件，
  // 但不使用 BDW_CUSTOM_FRAME（窗口框架和 WM_NCHITTEST 由
  // win32_window.cpp 自行管理，含厚边框 + Snap Layout）。
  bitsdojo_window_configure(0);

  // 使用 exe 所在目录的绝对路径定位 data 目录，避免因工作目录
  // 不同（flutter run 使用项目根目录 vs 直接运行使用 exe 目录）
  // 导致 Flutter 引擎找不到 kernel_blob.bin。
  // flutter run 从 runner\Debug\ngskg_plus.exe 启动，data 在
  // runner\data\ 下，因此需要上溯一级；直接运行（runner\ngskg_plus.exe）
  // 则 data 就在同级的 runner\data\。
  wchar_t exePath[MAX_PATH];
  GetModuleFileNameW(nullptr, exePath, MAX_PATH);
  std::wstring dataDir = exePath;
  auto lastSep = dataDir.find_last_of(L"\\/");
  if (lastSep != std::wstring::npos) {
    // 先取 exe 所在目录
    dataDir = dataDir.substr(0, lastSep);
    // 如果目录名是 Debug/Release/Profile，说明在构建输出子目录中，
    // data 目录在父级
    std::wstring dirName = dataDir.substr(dataDir.find_last_of(L"\\/") + 1);
    if (dirName == L"Debug" || dirName == L"Release" || dirName == L"Profile") {
      auto parentSep = dataDir.find_last_of(L"\\/");
      if (parentSep != std::wstring::npos) {
        dataDir = dataDir.substr(0, parentSep);
      }
    }
    dataDir += L"\\data";
  } else {
    dataDir = L"data";  // fallback
  }
  flutter::DartProject project(dataDir.c_str());

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"NGS-KG+", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
