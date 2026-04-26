/// Service for opening URLs in the built-in browser or system browser.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'browser_page.dart';

/// Whether the current platform supports [InAppWebView].
bool get _platformSupportsInAppWebView {
  return !defaultTargetPlatform.isLinux;
}

/// Extension to check platform type.
extension on TargetPlatform {
  bool get isLinux => this == TargetPlatform.linux;
}

/// Opens [url] according to user preferences and platform capabilities.
///
/// 1. If in-app browser is disabled in settings → system browser.
/// 2. If platform doesn't support InAppWebView → system browser with a hint.
/// 3. Otherwise → in-app browser page.
Future<void> openUrlInBrowser(
  BuildContext context,
  String url, {
  required bool useInAppBrowser,
  String? title,
}) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无效的 URL: $url')));
    }
    return;
  }

  if (!useInAppBrowser || !_platformSupportsInAppWebView) {
    if (context.mounted && !_platformSupportsInAppWebView && useInAppBrowser) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前平台不支持内置浏览器，已使用系统浏览器打开')));
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return;
  }

  if (context.mounted) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BrowserPage(url: url, title: title),
      ),
    );
  }
}
