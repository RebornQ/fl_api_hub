/// DTO for `GET /api/status` response data.
///
/// Contains public site status information such as check-in support
/// and system version.
library;

/// Site status information from the public status endpoint.
class SiteStatusDto {
  /// Whether the daily check-in feature is enabled on this site.
  final bool? checkinEnabled;

  /// System version string (e.g. "v1.2.3").
  final String? version;

  /// System name.
  final String? systemName;

  /// Custom footer text configured by the site admin.
  final String? footer;

  /// Site-reported quota → USD conversion factor (`quota_per_unit`).
  ///
  /// New API and its forks expose account usage in token-unit "quota".
  /// The upstream default is `500000 quota = $1 USD`, but site admins
  /// may override this. Consumers that want to display balances in USD
  /// should fall back to `kDefaultQuotaPerUnit` when this field is null.
  final double? quotaPerUnit;

  const SiteStatusDto({
    this.checkinEnabled,
    this.version,
    this.systemName,
    this.footer,
    this.quotaPerUnit,
  });

  /// Parses a raw JSON map into a [SiteStatusDto].
  static SiteStatusDto fromJson(Map<String, dynamic> json) {
    return SiteStatusDto(
      checkinEnabled: json['checkin_enabled'] as bool?,
      version: json['version'] as String?,
      systemName: json['system_name'] as String?,
      footer: json['footer'] as String?,
      quotaPerUnit: (json['quota_per_unit'] as num?)?.toDouble(),
    );
  }
}
