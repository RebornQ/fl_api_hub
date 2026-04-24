#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {

constexpr const wchar_t kWindowRegKey[] =
    L"Software\\mallotec\\flapihub";

constexpr int kMinWidth = 1024;
constexpr int kMinHeight = 768;

bool WriteRegDword(HKEY key, const wchar_t* name, DWORD value) {
  return RegSetValueEx(key, name, 0, REG_DWORD,
                       reinterpret_cast<const BYTE*>(&value),
                       sizeof(DWORD)) == ERROR_SUCCESS;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;

    case WM_GETMINMAXINFO: {
      auto mmi = reinterpret_cast<MINMAXINFO*>(lparam);
      mmi->ptMinTrackSize.x = kMinWidth;
      mmi->ptMinTrackSize.y = kMinHeight;
      return 0;
    }

    case WM_CLOSE:
      SaveWindowState();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::SaveWindowState() {
  HWND hwnd = GetHandle();
  if (!hwnd || IsZoomed(hwnd) || IsIconic(hwnd)) {
    return;
  }

  RECT rect;
  if (!GetWindowRect(hwnd, &rect)) {
    return;
  }

  HKEY key;
  if (RegCreateKeyEx(HKEY_CURRENT_USER, kWindowRegKey, 0, nullptr, 0,
                     KEY_WRITE, nullptr, &key, nullptr) != ERROR_SUCCESS) {
    return;
  }

  WriteRegDword(key, L"width", static_cast<DWORD>(rect.right - rect.left));
  WriteRegDword(key, L"height", static_cast<DWORD>(rect.bottom - rect.top));
  WriteRegDword(key, L"x", static_cast<DWORD>(rect.left));
  WriteRegDword(key, L"y", static_cast<DWORD>(rect.top));
  RegCloseKey(key);
}
