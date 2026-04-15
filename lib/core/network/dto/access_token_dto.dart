/// DTO for `GET /api/user/token` response data.
///
/// Used when creating an access token from a cookie-based session.
/// The common/new-api endpoint returns the newly created token in the
/// response data field.
library;

/// Access token created from a cookie session.
class AccessTokenDto {
  /// The newly created access token string.
  final String? token;

  const AccessTokenDto({this.token});

  /// Parses a raw JSON map into an [AccessTokenDto].
  static AccessTokenDto fromJson(Map<String, dynamic> json) {
    return AccessTokenDto(
      token: json['token'] as String? ?? json['key'] as String?,
    );
  }
}
