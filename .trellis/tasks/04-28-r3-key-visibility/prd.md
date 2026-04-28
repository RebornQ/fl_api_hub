# R3: 密钥脱敏前隐藏 visibility toggle

## Goal

服务端脱敏密钥（含 `***`/`…`）不显示 visibility toggle 按钮，避免用户困惑。

## Requirements

- `_isServerMasked == true` 时隐藏 visibility toggle
- 只显示 resolve（解析）按钮
- 解析成功后自动显示 visibility toggle（已有逻辑，`_isServerMasked` 会变 false）
- 非脱敏密钥行为不变

## Modified Files

- `lib/features/keys/presentation/widgets/key_value_row.dart`
  - 第 99 行 visibility toggle 外加 `if (!_isServerMasked)` 条件

## Implementation

将第 99-111 行的 `GestureDetector` 包裹在条件判断中：
```dart
if (!_isServerMasked)
  GestureDetector(
    onTap: _hasValue
        ? () => setState(() => _isVisible = !_isVisible)
        : null,
    child: Icon(
      _isVisible ? Icons.visibility_off : Icons.visibility,
      size: 18,
      color: _hasValue
          ? colorScheme.outline
          : colorScheme.outlineVariant,
    ),
  ),
```
