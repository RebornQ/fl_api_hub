# R1: 底部导航栏选中色与 FAB 统一

## Goal

`NavigationBar` 选中态（图标、文字、indicator）使用 `colorScheme.primary`，与 FAB 按钮颜色统一。

## Requirements

- 选中 icon + label 颜色 → `colorScheme.primary`
- indicator 背景 → `colorScheme.primaryContainer`
- 未选中保持默认 `colorScheme.onSurfaceVariant`

## Modified Files

- `lib/app/shell/app_shell.dart` — 用 `NavigationBarTheme` 包裹现有 `NavigationBar`

## Implementation

在 `build()` 方法中，用 `NavigationBarTheme` 覆盖 `iconTheme` 和 `labelTextStyle` 的 selected 状态颜色。
