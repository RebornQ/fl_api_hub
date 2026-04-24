// ignore_for_file: avoid_print, depend_on_referenced_packages
import 'dart:io';
import 'package:image/image.dart';

void main() {
  final srcBytes = File('assets/icon-hub-1024.png').readAsBytesSync();
  final src = decodeImage(srcBytes)!;
  final w = src.width, h = src.height;

  // Find content bounding box (non-transparent pixels)
  int minX = w, minY = h, maxX = 0, maxY = 0;
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final pixel = src.getPixel(x, y);
      if (pixel.a > 0) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }

  print('Image size: ${w}x$h');
  print('Content bounds: ($minX, $minY) -> ($maxX, $maxY)');
  print('Content size: ${maxX - minX + 1} x ${maxY - minY + 1}');
  print(
    'Padding: left=$minX right=${w - maxX - 1} top=$minY bottom=${h - maxY - 1}',
  );

  // Crop with a small margin (3% of content size for breathing room)
  final contentW = maxX - minX + 1;
  final contentH = maxY - minY + 1;
  final margin = (contentW * 0.03).round();

  final cropX = (minX - margin).clamp(0, w);
  final cropY = (minY - margin).clamp(0, h);
  final cropW = (contentW + margin * 2).clamp(0, w - cropX);
  final cropH = (contentH + margin * 2).clamp(0, h - cropY);

  print('Crop region: ($cropX, $cropY) ${cropW}x$cropH (with 3% margin)');

  final cropped = copyCrop(
    src,
    x: cropX,
    y: cropY,
    width: cropW,
    height: cropH,
  );
  final result = copyResize(
    cropped,
    width: 1024,
    height: 1024,
    interpolation: Interpolation.average,
  );

  // Ensure output directory exists
  final outDir = Directory('icons');
  if (!outDir.existsSync()) outDir.createSync();

  File(
    'icons/icon-hub-1024-new.png',
  ).writeAsBytesSync(encodePng(result, level: 9));

  print('Saved icons/icon-hub-1024-new.png (1024x1024)');
}
