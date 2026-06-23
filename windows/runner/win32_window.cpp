#include "win32_window.h"

#include <dwmapi.h>
#include <flutter_windows.h>
#include <windowsx.h>

#include "resource.h"

namespace {

/// Window attribute that enables dark mode window decorations.
///
/// Redefined in case the developer's machine has a Windows SDK older than
/// version 10.0.22000.0.
/// See: https://docs.microsoft.com/windows/win32/api/dwmapi/ne-dwmapi-dwmwindowattribute
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

/// Window corner preference for DWM (Windows 11).
/// See: https://docs.microsoft.com/windows/win32/api/dwmapi/ne-dwmapi-dwmwindowcornerpreference
#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif
#ifndef DWMWA_ROUND
#define DWMWA_ROUND 2
#endif

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

/// Registry key for app theme preference.
///
/// A value of 0 indicates apps should use dark mode. A non-zero or missing
/// value indicates apps should use light mode.
constexpr const wchar_t kGetPreferredBrightnessRegKey[] =
  L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
constexpr const wchar_t kGetPreferredBrightnessRegValue[] = L"AppsUseLightTheme";

// The number of Win32Window objects that currently exist.
static int g_active_window_count = 0;

using EnableNonClientDpiScaling = BOOL __stdcall(HWND hwnd);

// Scale helper to convert logical scaler values to physical using passed in
// scale factor
int Scale(int source, double scale_factor) {
  return static_cast<int>(source * scale_factor);
}

// Dynamically loads the |EnableNonClientDpiScaling| from the User32 module.
// This API is only needed for PerMonitor V1 awareness mode.
void EnableFullDpiSupportIfAvailable(HWND hwnd) {
  HMODULE user32_module = LoadLibraryA("User32.dll");
  if (!user32_module) {
    return;
  }
  auto enable_non_client_dpi_scaling =
      reinterpret_cast<EnableNonClientDpiScaling*>(
          GetProcAddress(user32_module, "EnableNonClientDpiScaling"));
  if (enable_non_client_dpi_scaling != nullptr) {
    enable_non_client_dpi_scaling(hwnd);
  }
  FreeLibrary(user32_module);
}

}  // namespace

// Manages the Win32Window's window class registration.
class WindowClassRegistrar {
 public:
  ~WindowClassRegistrar() = default;

  // Returns the singleton registrar instance.
  static WindowClassRegistrar* GetInstance() {
    if (!instance_) {
      instance_ = new WindowClassRegistrar();
    }
    return instance_;
  }

  // Returns the name of the window class, registering the class if it hasn't
  // previously been registered.
  const wchar_t* GetWindowClass();

  // Unregisters the window class. Should only be called if there are no
  // instances of the window.
  void UnregisterWindowClass();

 private:
  WindowClassRegistrar() = default;

  static WindowClassRegistrar* instance_;

  bool class_registered_ = false;
};

WindowClassRegistrar* WindowClassRegistrar::instance_ = nullptr;

const wchar_t* WindowClassRegistrar::GetWindowClass() {
  if (!class_registered_) {
    WNDCLASS window_class{};
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class.lpszClassName = kWindowClassName;
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    window_class.cbClsExtra = 0;
    window_class.cbWndExtra = 0;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.hIcon =
        LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
    window_class.hbrBackground = 0;
    window_class.lpszMenuName = nullptr;
    window_class.lpfnWndProc = Win32Window::WndProc;
    RegisterClass(&window_class);
    class_registered_ = true;
  }
  return kWindowClassName;
}

void WindowClassRegistrar::UnregisterWindowClass() {
  UnregisterClass(kWindowClassName, nullptr);
  class_registered_ = false;
}

Win32Window::Win32Window() {
  ++g_active_window_count;
}

Win32Window::~Win32Window() {
  --g_active_window_count;
  Destroy();
}

bool Win32Window::Create(const std::wstring& title,
                         const Point& origin,
                         const Size& size) {
  Destroy();

  const wchar_t* window_class =
      WindowClassRegistrar::GetInstance()->GetWindowClass();

  const POINT target_point = {static_cast<LONG>(origin.x),
                               static_cast<LONG>(origin.y)};
  HMONITOR monitor = MonitorFromPoint(target_point, MONITOR_DEFAULTTONEAREST);
  UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  double scale_factor = dpi / 96.0;

  // 1) 用 WS_OVERLAPPEDWINDOW 创建窗口 → 保留阴影、最大化行为（不覆盖
  //    任务栏）、调整大小边框。创建后再移除 WS_CAPTION。
  HWND window = CreateWindow(
      window_class, title.c_str(), WS_OVERLAPPEDWINDOW,
      Scale(origin.x, scale_factor), Scale(origin.y, scale_factor),
      Scale(size.width, scale_factor), Scale(size.height, scale_factor),
      nullptr, nullptr, GetModuleHandle(nullptr), this);

  if (!window) {
    return false;
  }

  UpdateTheme(window);

  // 2) 保留 WS_CAPTION，避免最大化时覆盖任务栏。
  //    通过 WM_NCCALCSIZE 将非客户区（标题栏）压缩为 0 来隐藏原生标题栏。
  //    C++ 注释：WS_CAPTION 保留 → 最大化仍预留任务栏空间；
  //    WM_NCCALCSIZE 返回 0 → 客户区铺满全窗口，原生标题栏不可见。

  // Windows 11: 确保窗口圆角。
  DWORD cornerPreference = DWMWA_ROUND;
  DwmSetWindowAttribute(window, DWMWA_WINDOW_CORNER_PREFERENCE,
                        &cornerPreference, sizeof(cornerPreference));

  // 确保第一次 WM_SIZE 被发送，Flutter 子窗口正确定位。
  RECT initRect;
  GetWindowRect(window, &initRect);
  const int w = initRect.right - initRect.left;
  const int h = initRect.bottom - initRect.top;
  SetWindowPos(window, nullptr, 0, 0, w + 1, h,
               SWP_NOMOVE | SWP_NOZORDER | SWP_FRAMECHANGED);
  SetWindowPos(window, nullptr, 0, 0, w, h,
               SWP_NOMOVE | SWP_NOZORDER | SWP_FRAMECHANGED);

  return OnCreate();
}

bool Win32Window::Show() {
  return ShowWindow(window_handle_, SW_SHOWNORMAL);
}

// static
LRESULT CALLBACK Win32Window::WndProc(HWND const window,
                                      UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto window_struct = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(window_struct->lpCreateParams));

    auto that = static_cast<Win32Window*>(window_struct->lpCreateParams);
    EnableFullDpiSupportIfAvailable(window);
    that->window_handle_ = window;
  } else if (Win32Window* that = GetThisFromHandle(window)) {
    return that->MessageHandler(window, message, wparam, lparam);
  }

  return DefWindowProc(window, message, wparam, lparam);
}

LRESULT
Win32Window::MessageHandler(HWND hwnd,
                            UINT const message,
                            WPARAM const wparam,
                            LPARAM const lparam) noexcept {
  switch (message) {
    case WM_DESTROY:
      window_handle_ = nullptr;
      Destroy();
      if (quit_on_close_) {
        PostQuitMessage(0);
      }
      return 0;

    case WM_DPICHANGED: {
      auto newRectSize = reinterpret_cast<RECT*>(lparam);
      LONG newWidth = newRectSize->right - newRectSize->left;
      LONG newHeight = newRectSize->bottom - newRectSize->top;

      SetWindowPos(hwnd, nullptr, newRectSize->left, newRectSize->top, newWidth,
                   newHeight, SWP_NOZORDER | SWP_NOACTIVATE);

      return 0;
    }
    case WM_SIZE: {
      RECT rect = GetClientArea();
      if (child_content_ != nullptr) {
        // Size and position the child window.
        MoveWindow(child_content_, rect.left, rect.top, rect.right - rect.left,
                   rect.bottom - rect.top, TRUE);
      }
      return 0;
    }

    case WM_ACTIVATE:
      if (child_content_ != nullptr) {
        SetFocus(child_content_);
      }
      return 0;

    case WM_NCCALCSIZE: {
      // 保留 WS_CAPTION 但将非客户区高度压缩为 0，隐藏原生标题栏。
      // 返回 0 告诉 Windows 使用整个窗口作为客户区。
      // 最大化时 WS_CAPTION 仍被识别，任务栏空间正常预留。
      return 0;
    }

    case WM_NCHITTEST: {
      // 自定义标题栏 Hit Testing，支持：
      //   - 10px 边缘 → 鼠标缩放（HTLEFT/HTRIGHT/HTTOP/HTBOTTOM 等）
      //   - 顶部 40px 标题栏 → HTCAPTION 拖拽 + 双击最大化
      //   - 右上角按钮区域：
      //       [clientWidth-138, clientWidth-92) → 最上化按钮 → HTCLIENT（Flutter 处理）
      //       [clientWidth-92,  clientWidth-46) → 最大化按钮 → HTMAXBUTTON（Snap Layout）
      //       [clientWidth-46,  clientWidth)   → 关闭按钮   → HTCLIENT（Flutter 处理）

      POINT pt;
      pt.x = GET_X_LPARAM(lparam);
      pt.y = GET_Y_LPARAM(lparam);

      // 边缘检测：窗口坐标下 10px 内 → 鼠标缩放
      RECT winRect;
      GetWindowRect(hwnd, &winRect);
      const int winW = winRect.right - winRect.left;
      const int winH = winRect.bottom - winRect.top;
      const int wx = pt.x - winRect.left;
      const int wy = pt.y - winRect.top;

      const int kEdge = 10;
      if (wx < kEdge && wy < kEdge) return HTTOPLEFT;
      if (wx > winW - kEdge && wy < kEdge) return HTTOPRIGHT;
      if (wx < kEdge && wy > winH - kEdge) return HTBOTTOMLEFT;
      if (wx > winW - kEdge && wy > winH - kEdge) return HTBOTTOMRIGHT;
      if (wx < kEdge) return HTLEFT;
      if (wy < kEdge) return HTTOP;
      if (wx > winW - kEdge) return HTRIGHT;
      if (wy > winH - kEdge) return HTBOTTOM;

      // 转换到客户区坐标
      ScreenToClient(hwnd, &pt);

      // DPI 缩放
      const UINT dpi = GetDpiForWindow(hwnd);
      const double scale = dpi / 96.0;

      // 标题栏高度（与 Flutter M3TitleBar height 一致）
      const int titleBarHeight = static_cast<int>(40 * scale);

      if (pt.y >= 0 && pt.y < titleBarHeight) {
        RECT clientRect;
        GetClientRect(hwnd, &clientRect);
        const int clientWidth = clientRect.right - clientRect.left;

        const int btnWidth = static_cast<int>(46 * scale);
        const int btnAreaStart = clientWidth - btnWidth * 3;

        if (pt.x >= btnAreaStart) {
          if (pt.x >= btnAreaStart + btnWidth &&
              pt.x < btnAreaStart + btnWidth * 2) {
            // 最大化按钮 → HTMAXBUTTON：Snap Layout + 原生最大化/还原
            return HTMAXBUTTON;
          }
          // 最小化和关闭按钮 → HTCLIENT：Flutter 通过 appWindow 控制
          return HTCLIENT;
        }

        // 标题栏其余区域 → HTCAPTION：窗口拖拽 + 双击最大化
        return HTCAPTION;
      }

      break;
    }

    case WM_NCRBUTTONUP: {
      // 标题栏右键 → 显示系统菜单
      if (wparam == HTCAPTION || wparam == HTMAXBUTTON) {
        HMENU hMenu = GetSystemMenu(hwnd, FALSE);
        if (hMenu) {
          TrackPopupMenu(hMenu,
              TPM_RIGHTBUTTON | TPM_LEFTALIGN,
              GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam),
              0, hwnd, nullptr);
        }
        return 0;
      }
      break;
    }

    case WM_DWMCOLORIZATIONCOLORCHANGED:
      UpdateTheme(hwnd);
      return 0;
  }

  return DefWindowProc(window_handle_, message, wparam, lparam);
}

void Win32Window::Destroy() {
  OnDestroy();

  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
  if (g_active_window_count == 0) {
    WindowClassRegistrar::GetInstance()->UnregisterWindowClass();
  }
}

Win32Window* Win32Window::GetThisFromHandle(HWND const window) noexcept {
  return reinterpret_cast<Win32Window*>(
      GetWindowLongPtr(window, GWLP_USERDATA));
}

void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;
  SetParent(content, window_handle_);
  RECT frame = GetClientArea();

  MoveWindow(content, frame.left, frame.top, frame.right - frame.left,
             frame.bottom - frame.top, true);

  SetFocus(child_content_);
}

RECT Win32Window::GetClientArea() {
  RECT frame;
  GetClientRect(window_handle_, &frame);
  return frame;
}

HWND Win32Window::GetHandle() {
  return window_handle_;
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

bool Win32Window::OnCreate() {
  // No-op; provided for subclasses.
  return true;
}

void Win32Window::OnDestroy() {
  // No-op; provided for subclasses.
}

void Win32Window::UpdateTheme(HWND const window) {
  DWORD light_mode;
  DWORD light_mode_size = sizeof(light_mode);
  LSTATUS result = RegGetValue(HKEY_CURRENT_USER, kGetPreferredBrightnessRegKey,
                               kGetPreferredBrightnessRegValue,
                               RRF_RT_REG_DWORD, nullptr, &light_mode,
                               &light_mode_size);

  if (result == ERROR_SUCCESS) {
    BOOL enable_dark_mode = light_mode == 0;
    DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE,
                          &enable_dark_mode, sizeof(enable_dark_mode));
  }
}
