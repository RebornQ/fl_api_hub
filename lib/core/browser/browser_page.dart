/// Full-screen in-app browser page using InAppWebView.
library;

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// A full-screen page that loads [url] in an embedded WebView.
class BrowserPage extends StatefulWidget {
  final String url;
  final String? title;

  const BrowserPage({super.key, required this.url, this.title});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  double _progress = 0;
  String _title = '';
  bool _isLoading = true;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _title.isNotEmpty ? _title : (widget.title ?? widget.url),
          style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        bottom: _isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                ),
              )
            : null,
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(widget.url)),
        onProgressChanged: (controller, progress) {
          setState(() {
            _progress = progress / 100.0;
            _isLoading = progress < 100;
          });
        },
        onUpdateVisitedHistory: (controller, url, androidIsReload) {
          if (url != null) {
            setState(() => _title = url.host);
          }
        },
        onLoadStop: (controller, url) {
          setState(() => _isLoading = false);
        },
      ),
    );
  }
}
