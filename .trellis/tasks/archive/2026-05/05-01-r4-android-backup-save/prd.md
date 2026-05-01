# R4: 修复 Android 备份保存文件无反应

## Goal

修复 Android 平台上备份功能"保存到文件"按钮点击无反应的问题。

## Root Cause

通过研究发现：`FilePicker.platform.saveFile` 在 Android 和桌面平台行为完全不同：

| 平台 | saveFile with bytes | saveFile without bytes | 返回路径类型 |
|------|---------------------|------------------------|--------------|
| Android | 自动保存 | 什么都不做 | `content://` URI |
| iOS | 自动保存 | 只返回路径 | 文件路径 |
| macOS | 写入 bytes | 只返回路径 | 文件路径 |

**问题根源**：
1. 当前代码没有传递 `bytes` 参数给 `saveFile`
2. Android 上 `saveFile` 无 bytes 时不执行任何操作
3. 然后代码尝试用 `dart:io` 的 `File` 写入 `content://` URI，这在 Android 上会静默失败

## Requirements

1. 将 `bytes` 参数传递给 `FilePicker.platform.saveFile()`
2. 移除 Android 上的手动 `File.writeAsBytes()` 调用（因为 SAF 已经处理了写入）
3. 确保桌面端行为不变

## Acceptance Criteria

- [ ] Android 点击"保存到文件"能成功保存备份文件
- [ ] 保存成功后显示成功提示
- [ ] 桌面端行为不变
- [ ] `flutter analyze` 无错误

## Technical Approach

**文件**：`lib/features/backup/data/datasources/backup_file_datasource.dart`

修改 `saveToFile` 方法：

```dart
Future<String?> saveToFile(Uint8List bytes, String suggestedName) async {
  final selectedPath = await FilePicker.platform.saveFile(
    dialogTitle: '保存备份文件',
    fileName: suggestedName.replaceAll('.flhbkp', ''),
    type: FileType.custom,
    allowedExtensions: ['flhbkp'],
    bytes: bytes,  // 修复：传递 bytes 让 Android 自动保存
  );
  return selectedPath;
}
```

**关键改动**：
- 添加 `bytes: bytes` 参数
- 移除手动 `File.writeAsBytes()` 调用
- 插件会在所有平台上正确处理文件写入

## Files

- `lib/features/backup/data/datasources/backup_file_datasource.dart`

## Out of Scope

- 不修改备份加密逻辑
- 不修改恢复功能
- 不需要添加 Android 权限（SAF 不需要存储权限）

## Research References

- [`research/android-file-picker.md`](research/android-file-picker.md) — file_picker 平台行为差异调研
