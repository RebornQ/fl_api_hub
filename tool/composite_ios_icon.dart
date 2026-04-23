// ignore_for_file: avoid_print, depend_on_referenced_packages
import 'dart:io';
import 'package:image/image.dart';

void main() {
  final srcBytes = File('icons/icon-hub-1024-new.png').readAsBytesSync();
  final src = decodeImage(srcBytes)!;

  final bg = Image(width: src.width, height: src.height, numChannels: 4);
  fill(bg, color: ColorRgba8(0xD2, 0xD0, 0xE8, 0xFF));

  compositeImage(bg, src, dstX: 0, dstY: 0, srcX: 0, srcY: 0);

  File('icons/icon-hub-1024-ios.png')
      .writeAsBytesSync(encodePng(bg, level: 9));
  print('Created icons/icon-hub-1024-ios.png');
}
