/// File I/O for backup files — read, write, share, and save.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Handles reading, writing, sharing, and saving backup files.
class BackupFileDataSource {
  /// Writes [bytes] to a temp file and returns the path.
  Future<String> writeToTempFile(Uint8List bytes, String filename) async {
    final dir = await getTemporaryDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// Reads a file at [path] and returns its bytes.
  Future<Uint8List> readFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('File not found', path);
    }
    return await file.readAsBytes();
  }

  /// Shares a file via system share sheet.
  Future<void> shareFile(String path, {String? subject}) async {
    await Share.shareXFiles([XFile(path)], subject: subject);
  }

  /// Saves [bytes] to a user-chosen location via save dialog.
  ///
  /// On desktop platforms, [saveFile] only returns the selected path —
  /// we must write the bytes ourselves.
  /// Returns the saved file path, or `null` if the user cancelled.
  Future<String?> saveToFile(Uint8List bytes, String suggestedName) async {
    final selectedPath = await FilePicker.platform.saveFile(
      dialogTitle: '保存备份文件',
      fileName: suggestedName.replaceAll('.flhbkp', ''),
      type: FileType.custom,
      allowedExtensions: ['flhbkp'],
    );
    if (selectedPath == null) return null;
    final file = File(selectedPath);
    await file.writeAsBytes(bytes);
    return selectedPath;
  }

  /// Opens a file picker for selecting a backup file.
  ///
  /// Returns the selected file path, or `null` if cancelled.
  Future<String?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择备份文件',
      type: FileType.custom,
      allowedExtensions: ['flhbkp', 'json'],
    );
    return result?.files.single.path;
  }

  /// Deletes a temp file (silent if not found).
  Future<void> deleteTempFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
