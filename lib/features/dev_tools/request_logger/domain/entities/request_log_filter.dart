/// Filter state for the request logger list page.
///
/// Combines a free-form keyword (matched case-insensitively against the
/// full request URL) with a [StatusBucket] quick-filter.
library;

import 'package:meta/meta.dart';

import 'status_bucket.dart';

/// Combined keyword + status filter used by the list page.
@immutable
class RequestLogFilter {
  /// Keyword (case-insensitive substring) matched against the request URL.
  /// Empty string means "no keyword filter".
  final String keyword;

  /// Status-code quick filter.
  final StatusBucket statusBucket;

  const RequestLogFilter({
    this.keyword = '',
    this.statusBucket = StatusBucket.all,
  });

  /// Returns `true` when both sub-filters are in their default state.
  bool get isDefault => keyword.isEmpty && statusBucket == StatusBucket.all;

  RequestLogFilter copyWith({String? keyword, StatusBucket? statusBucket}) {
    return RequestLogFilter(
      keyword: keyword ?? this.keyword,
      statusBucket: statusBucket ?? this.statusBucket,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RequestLogFilter &&
        other.keyword == keyword &&
        other.statusBucket == statusBucket;
  }

  @override
  int get hashCode => Object.hash(keyword, statusBucket);
}
