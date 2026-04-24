#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

// Registry key for persisting window geometry.
constexpr const wchar_t kWindowRegKey[] =
    L"Software\\mallotec\\flapihub";

constexpr int kMinWidth = 1024;
constexpr int kMinHeight = 768;
constexpr double kScreenRatio = 0.8;

// Reads a DWORD from the registry. Returns false on failure.
bool ReadRegDword(HKEY key, const wchar_t* name, DWORD* out) {
  DWORD size = sizeof(DWORD);
  return RegGetValue(key, nullptr, name, RRF_RT_DWORD, nullptr, out, &size) ==
         ERROR_SUCCESS;
}

// Writes a DWORD to the registry. Returns false on failure.
bool WriteRegDword(HKEY key, const wchar_t* name, DWORD value) {
  return RegSetValueEx(key, name, 0, REG_DWORD,
                       reinterpret_cast<const BYTE*>(&value),
                       sizeof(DWORD)) == ERROR_SUCCESS;
}

}  // namespace

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

  // Calculate default window size: 80% of primary screen.
  int screen_w = GetSystemMetrics(SM_CXSCREEN);
  int screen_h = GetSystemMetrics(SM_CYSCREEN);
  int width = static_cast<int>(screen_w * kScreenRatio);
  int height = static_cast<int>(screen_h * kScreenRatio);
  if (width < kMinWidth) width = kMinWidth;
  if (height < kMinHeight) height = kMinHeight;
  int x = (screen_w - width) / 2;
  int y = (screen_h - height) / 2;

  // Restore saved window geometry from registry.
  HKEY key;
  if (RegOpenKeyEx(HKEY_CURRENT_USER, kWindowRegKey, 0, KEY_READ, &key) ==
      ERROR_SUCCESS) {
    DWORD val;
    if (ReadRegDword(key, L"width", &val))
      width = static_cast<int>(val);
    if (ReadRegDword(key, L"height", &val))
      height = static_cast<int>(val);
    if (ReadRegDword(key, L"x", &val))
      x = static_cast<int>(val);
    if (ReadRegDword(key, L"y", &val))
      y = static_cast<int>(val);
    RegCloseKey(key);
  }

  // Enforce minimums after loading saved values.
  if (width < kMinWidth) width = kMinWidth;
  if (height < kMinHeight) height = kMinHeight;

  FlutterWindow window(project);
  Win32Window::Point origin(x, y);
  Win32Window::Size size(width, height);
  if (!window.Create(L"Fl API Hub", origin, size)) {
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
