/// Narrow-layout detail page pushed from the request logger list.
///
/// Looks up the entry from the buffer by id so late arrivals / eviction
/// are handled gracefully — an evicted entry shows a friendly placeholder
/// instead of a blank page.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/request_logger_providers.dart';
import '../widgets/request_log_detail_placeholder.dart';

class RequestLogDetailPage extends ConsumerWidget {
  final int entryId;

  const RequestLogDetailPage({super.key, required this.entryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(requestLogBufferProvider);
    final entry = entries.where((e) => e.id == entryId).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('请求详情')),
      body: entry == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('该记录已被清空或超出缓存上限', textAlign: TextAlign.center),
              ),
            )
          : RequestLogDetailView(entry: entry),
    );
  }
}
