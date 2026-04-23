/// Riverpod providers for the request logger feature.
///
/// Three pieces of state plus one derived view:
///
/// - [requestLoggerEnabledProvider] — the on/off switch. A plain
///   `StateProvider<bool>`; not persisted, defaults to `false` on every
///   cold start.
/// - [requestLogBufferProvider] — the 500-entry FIFO ring buffer backed by
///   a `ListQueue` so `addLast` / `removeFirst` stay O(1). Exposes
///   `add(entry)` and `clear()` methods through its `Notifier`.
/// - [requestLogFilterProvider] — current keyword + status quick-filter.
/// - [filteredRequestLogsProvider] — newest-first view over the buffer
///   after applying the filter. Rebuilt whenever the buffer or filter
///   changes.
library;

import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/request_log_entry.dart';
import '../../domain/entities/request_log_filter.dart';
import '../../domain/entities/status_bucket.dart';

/// Maximum number of entries kept in the in-memory ring buffer.
const int kRequestLogBufferCapacity = 500;

/// On/off switch. Not persisted — every cold start is `false`.
final requestLoggerEnabledProvider = StateProvider<bool>((ref) => false);

/// Current filter (keyword + status bucket) applied to the list view.
final requestLogFilterProvider = StateProvider<RequestLogFilter>(
  (ref) => const RequestLogFilter(),
);

/// Id of the entry currently selected in the wide-layout master-detail view.
///
/// `null` means nothing is selected yet. The narrow layout routes through
/// `Navigator.push` instead and does not consult this provider.
final selectedRequestLogIdProvider = StateProvider<int?>((ref) => null);

/// In-memory FIFO ring buffer of captured request entries.
///
/// Entries are stored oldest-first; [filteredRequestLogsProvider] reverses
/// them for display so the newest request appears at the top of the list.
class RequestLogBufferNotifier extends Notifier<List<RequestLogEntry>> {
  final ListQueue<RequestLogEntry> _queue = ListQueue<RequestLogEntry>();

  @override
  List<RequestLogEntry> build() {
    return List<RequestLogEntry>.unmodifiable(_queue);
  }

  /// Appends [entry] to the buffer, evicting the oldest entries until the
  /// buffer size is within [kRequestLogBufferCapacity].
  void add(RequestLogEntry entry) {
    while (_queue.length >= kRequestLogBufferCapacity) {
      _queue.removeFirst();
    }
    _queue.addLast(entry);
    state = List<RequestLogEntry>.unmodifiable(_queue);
  }

  /// Empties the buffer. Called from the list-page "clear" action; does
  /// **not** change the enabled switch.
  void clear() {
    if (_queue.isEmpty) return;
    _queue.clear();
    state = const [];
  }
}

/// Provider for the ring buffer. Holds captured entries (oldest first).
final requestLogBufferProvider =
    NotifierProvider<RequestLogBufferNotifier, List<RequestLogEntry>>(
      RequestLogBufferNotifier.new,
    );

/// Derived view: newest-first, filter applied.
final filteredRequestLogsProvider = Provider<List<RequestLogEntry>>((ref) {
  final entries = ref.watch(requestLogBufferProvider);
  final filter = ref.watch(requestLogFilterProvider);

  if (entries.isEmpty) return const [];

  // Materialise the newest-first view once.
  final reversed = entries.reversed.toList(growable: false);
  if (filter.isDefault) return reversed;

  final keyword = filter.keyword.trim().toLowerCase();
  return reversed
      .where((entry) {
        if (keyword.isNotEmpty && !entry.url.toLowerCase().contains(keyword)) {
          return false;
        }
        switch (filter.statusBucket) {
          case StatusBucket.all:
            return true;
          case StatusBucket.success:
            return entry.isSuccess;
          case StatusBucket.clientError:
            return entry.isClientError;
          case StatusBucket.serverError:
            return entry.isServerError;
          case StatusBucket.error:
            return entry.isError;
        }
      })
      .toList(growable: false);
});
