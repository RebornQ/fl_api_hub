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

  const SiteStatusDto({
    this.checkinEnabled,
    this.version,
    this.systemName,
    this.footer,
  });

  /// Parses a raw JSON map into a [SiteStatusDto].
  static SiteStatusDto fromJson(Map<String, dynamic> json) {
    return SiteStatusDto(
      checkinEnabled: json['checkin_enabled'] as bool?,
      version: json['version'] as String?,
      systemName: json['system_name'] as String?,
      footer: json['footer'] as String?,
    );
  }
}
