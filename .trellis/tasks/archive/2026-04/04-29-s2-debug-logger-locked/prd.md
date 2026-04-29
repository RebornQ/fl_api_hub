# S2: 请求记录器 kDebug 模式锁定开启

## Goal

在 debug 模式下，请求记录器默认开启且不可手动关闭，确保开发者始终能看到请求日志。

## Current Behavior

- `requestLoggerEnabledProvider` 初始值硬编码 `false`
- 开发者选项页面 SwitchListTile 可自由开关
- 每次 cold start 默认关闭

## Target Behavior

- kDebugMode: 初始值 `true`，开关 disabled（锁定开启）
- Release: 行为与当前一致（默认 false，可手动开关）

## Technical Approach

### 1. requestLoggerEnabledProvider

```dart
final requestLoggerEnabledProvider = StateProvider<bool>(
  (ref) => kDebugMode,
);
```

### 2. developer_options_page.dart

SwitchListTile 的 onChanged 在 kDebugMode 下设为 null（禁用）：

```dart
SwitchListTile(
  value: enabled,
  onChanged: kDebugMode ? null : (value) =>
      ref.read(requestLoggerEnabledProvider.notifier).state = value,
  // ...
)
```

可附加 subtitle 提示 debug 模式锁定状态。

## Files

- `lib/features/dev_tools/request_logger/presentation/providers/request_logger_providers.dart` (1 行改动)
- `lib/features/dev_tools/request_logger/presentation/pages/developer_options_page.dart` (3-5 行改动)

## Acceptance Criteria

- [ ] kDebugMode 下记录器默认开启
- [ ] kDebugMode 下开关 disabled，无法关闭
- [ ] Release 模式行为不变
- [ ] `flutter analyze` clean

## Definition of Done

- Lint clean
- 现有测试不受影响
