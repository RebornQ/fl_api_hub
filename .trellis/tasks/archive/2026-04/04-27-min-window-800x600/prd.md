# 修改桌面端最小窗口限制为 800×600

## Goal

将 macOS / Windows / Linux 三个桌面平台的最小窗口限制从 1024×768 统一修改为 800×600。

## What I already know

* 当前三平台最小窗口均为 1024×768，定义在各平台原生代码中
* macOS: `macos/Runner/MainFlutterWindow.swift:5-6` — `kMinWidth = 1024`, `kMinHeight = 768`
* Windows: `windows/runner/main.cpp:15-16` — `kMinWidth = 1024`, `kMinHeight = 768`
* Linux: `linux/runner/my_application.cc` — `hints.min_width = 1024`, `hints.min_height = 768`
* 各平台同时使用这些常量作为默认窗口尺寸的下限（screen * 0.8 与 min 取 max）

## Requirements

* 三个桌面平台最小窗口限制统一改为 800×600
* 常量定义和几何约束两处都要同步修改

## Acceptance Criteria

* [ ] macOS `kMinWidth`/`kMinHeight` 改为 800/600，`minSize` 生效
* [ ] Windows `kMinWidth`/`kMinHeight` 改为 800/600，`WM_GETMINMAXINFO` 生效
* [ ] Linux `hints.min_width`/`hints.min_height` 改为 800/600

## Definition of Done

* 三平台原生代码常量修改完成
* `flutter analyze` 通过（纯原生代码修改，不影响 Dart）

## Out of Scope

* 不涉及 Flutter/Dart 层代码
* 不涉及移动端 (Android/iOS)
* 不改变默认窗口尺寸计算逻辑（仍为 screen * 0.8）

## Technical Notes

* 改动范围：3 个文件，各改 2 个数值
* 风险：极低，纯常量修改
