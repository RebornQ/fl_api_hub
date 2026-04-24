import 'package:flutter/services.dart';

class AppMethodChannel {
  static const _channel = MethodChannel('com.mallotec.reb.flapihub/app');
  static VoidCallback? onOpenSettings;

  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openSettings') {
        onOpenSettings?.call();
      }
    });
  }
}
