/// DTO for `GET /api/user/self` response data.
///
/// Represents the user account information returned by the common/new-api
/// compatible endpoints. Fields are nullable because different site
/// implementations may return different subsets.
library;

/// User account information from the API.
class UserInfoDto {
  /// Server-assigned user ID.
  final int? id;

  /// Display name.
  final String? username;

  /// Email address.
  final String? email;

  /// Total quota allocation.
  final double? quota;

  /// Quota already consumed.
  final double? usedQuota;

  /// Current account balance.
  final double? balance;

  /// Access token present in some site responses (e.g. one-hub).
  final String? accessToken;

  /// Avatar URL.
  final String? avatar;

  const UserInfoDto({
    this.id,
    this.username,
    this.email,
    this.quota,
    this.usedQuota,
    this.balance,
    this.accessToken,
    this.avatar,
  });

  /// Parses a raw JSON map into a [UserInfoDto].
  static UserInfoDto fromJson(Map<String, dynamic> json) {
    return UserInfoDto(
      id: json['id'] as int?,
      username: json['username'] as String?,
      email: json['email'] as String?,
      quota: (json['quota'] as num?)?.toDouble(),
      usedQuota: (json['used_quota'] as num?)?.toDouble(),
      balance: (json['balance'] as num?)?.toDouble(),
      accessToken: json['access_token'] as String?,
      avatar: json['avatar'] as String?,
    );
  }
}
