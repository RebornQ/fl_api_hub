/// Reachability status model for per-account website health tracking.
///
/// A [ReachabilityRecord] captures whether the last attempt to reach an
/// account's site succeeded, failed, or has never been checked. A
/// [FailCategory] is preserved when the status is [ReachabilityStatus.fail]
/// so the UI can later decide on finer-grained colors (e.g. 4xx token
/// failure vs 5xx server outage) without changing the storage schema.
library;

import 'package:dio/dio.dart';

import '../error/app_exception.dart';

/// Coarse reachability outcome for a single account.
enum ReachabilityStatus { unknown, ok, fail }

/// Sub-category of failure. Reserved for future UI expansion — the current
/// card UI collapses all three values into a single red dot.
enum FailCategory { network, http4xx, http5xx }

/// Immutable record of the last reachability check for a single account.
class ReachabilityRecord {
  final ReachabilityStatus status;
  final DateTime checkedAt;
  final FailCategory? failCategory;

  /// Whether the account has checked in today according to API.
  /// `null` means the check-in status was not fetched or is unknown.
  final bool? checkInStatusToday;

  const ReachabilityRecord({
    required this.status,
    required this.checkedAt,
    this.failCategory,
    this.checkInStatusToday,
  });

  /// Convenience constructor for a successful check.
  factory ReachabilityRecord.ok(DateTime at, {bool? checkInStatusToday}) =>
      ReachabilityRecord(
        status: ReachabilityStatus.ok,
        checkedAt: at,
        checkInStatusToday: checkInStatusToday,
      );

  /// Convenience constructor for a failed check.
  factory ReachabilityRecord.fail(DateTime at, FailCategory category) =>
      ReachabilityRecord(
        status: ReachabilityStatus.fail,
        checkedAt: at,
        failCategory: category,
      );

  /// Serializes to a Hive-friendly map.
  Map<String, dynamic> toMap() => {
    'status': status.name,
    'checkedAt': checkedAt.toIso8601String(),
    'failCategory': failCategory?.name,
    'checkInStatusToday': checkInStatusToday,
  };

  /// Deserializes from a Hive-stored map. Returns `null` if the map is
  /// malformed — callers should treat that as [ReachabilityStatus.unknown].
  static ReachabilityRecord? fromMap(Map<String, dynamic> map) {
    final statusName = map['status'] as String?;
    final checkedAtStr = map['checkedAt'] as String?;
    if (statusName == null || checkedAtStr == null) return null;
    final status = ReachabilityStatus.values.firstWhere(
      (e) => e.name == statusName,
      orElse: () => ReachabilityStatus.unknown,
    );
    final checkedAt = DateTime.tryParse(checkedAtStr);
    if (checkedAt == null) return null;
    final failName = map['failCategory'] as String?;
    final failCategory = failName == null
        ? null
        : FailCategory.values.firstWhere(
            (e) => e.name == failName,
            orElse: () => FailCategory.network,
          );
    return ReachabilityRecord(
      status: status,
      checkedAt: checkedAt,
      failCategory: failCategory,
      checkInStatusToday: map['checkInStatusToday'] as bool?,
    );
  }
}

/// Classifies an error from a network/API call into a [FailCategory].
///
/// Accepts both raw [DioException]s and mapped [AppException]s:
///  * [AuthException] (401/403) → [FailCategory.http4xx].
///  * [NetworkException] with `statusCode` in 500–599 → [FailCategory.http5xx].
///  * [NetworkException] with `statusCode` in 400–499 → [FailCategory.http4xx].
///  * Anything else (timeout, DNS, connection reset, unknown) falls back
///    to [FailCategory.network].
///
/// The current card UI collapses all three values into a single red dot;
/// this function exists so the split can happen later without schema
/// changes.
FailCategory categorizeFailure(Object error) {
  int? status;
  if (error is DioException) {
    status = error.response?.statusCode;
  } else if (error is AuthException) {
    status = error.statusCode;
  } else if (error is NetworkException) {
    status = error.statusCode;
  }
  if (status != null) {
    if (status >= 500 && status < 600) return FailCategory.http5xx;
    if (status >= 400 && status < 500) return FailCategory.http4xx;
  }
  return FailCategory.network;
}
