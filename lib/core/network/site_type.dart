/// Site type enumeration with authentication method mapping.
///
/// Each [SiteType] corresponds to a backend implementation variant defined in
/// the PRD (Section 11.2). The [defaultAuthType] determines how auth headers
/// are injected for that site. The [isManaged] flag indicates whether the site
/// supports channel management and model synchronization.
library;

/// Authentication method for API requests.
enum AuthType {
  /// Bearer token in Authorization header.
  accessToken,

  /// Cookie-based authentication.
  cookie,

  /// No authentication required.
  none,
}

/// Supported site backend types.
enum SiteType {
  newApi('new-api', AuthType.accessToken, isManaged: true),
  oneApi('one-api', AuthType.accessToken, isManaged: false),
  oneHub('one-hub', AuthType.accessToken, isManaged: false),
  doneHub('done-hub', AuthType.accessToken, isManaged: true),
  veloera('Veloera', AuthType.accessToken, isManaged: true),
  octopus('octopus', AuthType.accessToken, isManaged: true),
  sub2api('sub2api', AuthType.cookie, isManaged: false),
  anyrouter('anyrouter', AuthType.cookie, isManaged: false),
  wongGongyi('wong-gongyi', AuthType.cookie, isManaged: false),

  /// Placeholder for accounts whose backend type has not been confirmed yet.
  ///
  /// Persisted as `'unknown'`. Calls fall back to the [SiteType.newApi]
  /// adapter via [siteAdapterForTypeProvider], so the account remains
  /// functional while the user later confirms the real type through the
  /// "re-detect" flow in the edit sheet.
  unknown('unknown', AuthType.accessToken, isManaged: false);

  const SiteType(this.value, this.defaultAuthType, {required this.isManaged});

  /// String value used for persistence / API serialization.
  final String value;

  /// Default authentication method for this site type.
  final AuthType defaultAuthType;

  /// Whether this site supports channel management and model sync.
  final bool isManaged;

  /// Reverse lookup from stored string value.
  ///
  /// Throws [ArgumentError] if [value] does not match any known site type.
  static SiteType fromValue(String value) {
    return SiteType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError('Unknown SiteType: $value'),
    );
  }

  /// Human-readable display label for UI.
  String get displayName => switch (this) {
    SiteType.newApi => 'New API',
    SiteType.oneApi => 'One API',
    SiteType.oneHub => 'One Hub',
    SiteType.doneHub => 'Done Hub',
    SiteType.veloera => 'Veloera',
    SiteType.octopus => 'Octopus',
    SiteType.sub2api => 'Sub2API',
    SiteType.anyrouter => 'AnyRouter',
    SiteType.wongGongyi => 'Wong Gongyi',
    SiteType.unknown => 'Unknown',
  };
}

/// Human-readable display label for [AuthType].
extension AuthTypeDisplayName on AuthType {
  /// Label shown in dropdowns and cards.
  String get displayName => switch (this) {
    AuthType.accessToken => 'Access Token',
    AuthType.cookie => 'Cookie',
    AuthType.none => '无',
  };
}
