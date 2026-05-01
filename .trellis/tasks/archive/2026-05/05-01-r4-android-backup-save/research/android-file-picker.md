# Research: Android file_picker saveFile Behavior

- **Query**: How does `FilePicker.platform.saveFile` behave on Android platform?
- **Scope**: Mixed (internal code analysis + external documentation/issues)
- **Date**: 2026-05-01

## Findings

### Critical Discovery: Platform-Specific Behavior Difference

**The `saveFile` method behaves DIFFERENTLY on Android vs Desktop platforms.**

#### Android Behavior (file_picker 9.0.0)

On Android, `saveFile` **automatically saves the file** when you provide the `bytes` parameter:
- Uses Android's Storage Access Framework (SAF) with `Intent.ACTION_CREATE_DOCUMENT`
- The native Android code writes the bytes to the user-selected location
- Returns the saved file path URI

From `FilePickerDelegate.kt` (lines 44-57):
```kotlin
private fun saveFile(uri: Uri?): Boolean {
    uri ?: return false
    dispatchEventStatus(true)
    return try {
        val savedUri = FileUtils.writeBytesData(context = activity, uri, bytes) ?: uri
        val renamedUri = maybeRenameGenericMimeDuplicate(
            context = activity,
            uri = savedUri,
            originalFileName = saveFileName,
            mimeType = saveMimeType
        )
        finishWithSuccess(renamedUri.path)
        true
    } catch (e: IOException) {
        Log.e(TAG, "Error while saving file", e)
        finishWithError("Error while saving file", e.message)
        false
    }
}
```

#### Desktop Behavior (Windows, macOS, Linux)

On desktop platforms, `saveFile` only returns a path:
- Opens a file save dialog
- Returns the user-selected path
- If `bytes` are provided, the plugin writes them to the chosen path (in newer versions)
- Historically, developers had to write bytes manually

### Current Implementation Issue

The current code at `lib/features/backup/data/datasources/backup_file_datasource.dart`:

```dart
Future<String?> saveToFile(Uint8List bytes, String suggestedName) async {
  final selectedPath = await FilePicker.platform.saveFile(
    dialogTitle: '保存备份文件',
    fileName: suggestedName.replaceAll('.flhbkp', ''),
    type: FileType.custom,
    allowedExtensions: ['flhbkp'],
  );
  if (selectedPath == null) return null;
  final file = File(selectedPath);  // <-- PROBLEM: Tries to write to content:// URI
  await file.writeAsBytes(bytes);
  return selectedPath;
}
```

**Problem**: The code does NOT pass the `bytes` parameter to `saveFile`, then attempts to manually write to the returned path. On Android, this fails because:

1. The returned path is a `content://` URI (SAF), not a filesystem path
2. `File(selectedPath).writeAsBytes()` cannot write to `content://` URIs
3. Without passing `bytes`, Android's save dialog appears but does nothing after user selects location

### Solution: Pass bytes Parameter

```dart
Future<String?> saveToFile(Uint8List bytes, String suggestedName) async {
  final selectedPath = await FilePicker.platform.saveFile(
    dialogTitle: '保存备份文件',
    fileName: suggestedName.replaceAll('.flhbkp', ''),
    type: FileType.custom,
    allowedExtensions: ['flhbkp'],
    bytes: bytes,  // <-- FIX: Pass bytes to let Android handle the save
  );
  return selectedPath;
}
```

### Files Found

| File Path | Description |
|---|---|
| `lib/features/backup/data/datasources/backup_file_datasource.dart` | Current implementation with the bug |
| `pubspec.yaml` | file_picker: ^9.0.0 |
| `android/app/src/main/AndroidManifest.xml` | No special storage permissions configured |

### Code Patterns

The issue is in `BackupFileDataSource.saveToFile()`:
- Line 44-54: Calls `saveFile` without `bytes` parameter
- Line 51-52: Attempts to write to returned path using `dart:io` File
- This pattern works on desktop but fails on Android

### External References

- [file_picker README - saveFile](https://github.com/miguelpruivo/flutter_file_picker/blob/master/README.md) - Documents platform differences
- [file_picker Dart source](https://github.com/miguelpruivo/flutter_file_picker/blob/master/lib/src/file_picker.dart) - API documentation stating: "For mobile, this function will save a file with the given [fileName] and [bytes] and return the path"
- [GitHub Issue #1524](https://github.com/miguelpruivo/flutter_file_picker/issues/1524) - Documents the platform behavior difference:
  > "On iOS, the saveFile method returns a String. The file then needs to be saved to the path described by this string. The 'bytes' parameter has no effect. On Android however, the Data is given by the 'bytes' parameter and this given data is saved instead."
- [FilePickerDelegate.kt](https://github.com/miguelpruivo/flutter_file_picker/blob/master/android/src/main/kotlin/com/mr/flutter/plugin/filepicker/FilePickerDelegate.kt) - Android native implementation
- [FileUtils.kt](https://github.com/miguelpruivo/flutter_file_picker/blob/master/android/src/main/kotlin/com/mr/flutter/plugin/filepicker/FileUtils.kt) - Contains `writeBytesData` function

### Android Permissions

For Android 10+ (API 29+), no special permissions are needed when using Storage Access Framework:
- `ACTION_CREATE_DOCUMENT` works without any storage permissions
- The system handles file creation through SAF
- No need for `WRITE_EXTERNAL_STORAGE` or `MANAGE_EXTERNAL_STORAGE`

Current `AndroidManifest.xml` only has `INTERNET` permission, which is sufficient for SAF-based file saving.

### Alternative Approaches

If `file_picker` solution doesn't work, alternatives include:

1. **share_plus** (already in project):
   - Write to temp file, then share
   - User can save via system share sheet
   - Already implemented in `shareFile` method

2. **path_provider + direct write**:
   - Save to app's external storage directory
   - Only works for app-private files
   - Not suitable for user-chosen locations

3. **saf_stream** or **saf_util** packages:
   - Specialized SAF handling packages
   - More control over file operations
   - Additional dependency

## Summary

| Platform | saveFile with bytes | saveFile without bytes | Returned Path Type |
|----------|---------------------|------------------------|-------------------|
| Android | Saves automatically | Does nothing | `content://` URI |
| iOS | Saves automatically | Returns path only | File path |
| macOS | Writes bytes if provided | Returns path only | File path |
| Windows | Writes bytes if provided | Returns path only | File path |
| Linux | Writes bytes if provided | Returns path only | File path |

## Recommended Fix

Pass the `bytes` parameter to `FilePicker.platform.saveFile()` on all platforms. The plugin handles platform differences internally:
- Android/iOS: Saves automatically
- Desktop: Writes bytes to chosen path or returns path for manual writing

Remove the manual `File.writeAsBytes()` call on Android since it cannot write to `content://` URIs.

## Caveats / Not Found

- No specific issues found for "clicking save does nothing" symptom in file_picker GitHub issues
- The documentation in README is not very explicit about this behavior difference
- Need to verify that iOS also works with the same approach (passing bytes)
