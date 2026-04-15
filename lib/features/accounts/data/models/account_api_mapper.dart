/// Maps [UserInfoDto] fields to domain-level [Account] values.
///
/// Does not create a full [Account] (which needs a local ID, timestamps,
/// and user-editable fields like `name` and `enabled`). Instead, it provides
/// extracted values that the repository uses to update an existing account
/// entity after an API sync.
library;

import '../../../../core/network/dto/user_info_dto.dart';

/// Utility class for extracting domain-level values from [UserInfoDto].
class AccountApiMapper {
  const AccountApiMapper._();

  /// Extracts the cached balance from a [UserInfoDto].
  static double? extractBalance(UserInfoDto dto) => dto.balance;

  /// Extracts the display name from a [UserInfoDto].
  static String? extractUsername(UserInfoDto dto) => dto.username;

  /// Extracts the access token if present in the response.
  ///
  /// Some sites (e.g. one-hub) include the access token in the user info
  /// response, which can be used for token resolution.
  static String? extractAccessToken(UserInfoDto dto) => dto.accessToken;
}
