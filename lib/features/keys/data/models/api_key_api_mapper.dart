/// Maps [TokenDto] to domain [ApiKey] entity.
///
/// Converts API-level token representations (which use server-specific
/// field names like `used_quota`, `expired_time`) into the domain entity
/// format used throughout the application.
library;

import '../../../../core/network/dto/token_dto.dart';
import '../../domain/entities/api_key.dart';

/// Utility class for converting [TokenDto] to [ApiKey] entities.
class ApiKeyApiMapper {
  const ApiKeyApiMapper._();

  /// Converts a single [TokenDto] to an [ApiKey] entity.
  ///
  /// [accountId] is required because the API response does not include
  /// the account association — it must be provided by the caller.
  static ApiKey toEntity(TokenDto dto, {required String accountId}) {
    return ApiKey(
      id: dto.id ?? '',
      accountId: accountId,
      name: dto.name ?? 'Unnamed',
      keyValue: dto.key,
      quota: dto.unlimitedQuota ? null : dto.remainQuota,
      usedQuota: dto.usedQuota ?? 0,
      expiresAt: dto.expiresAt,
      createdAt: dto.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      group: dto.group,
    );
  }

  /// Converts a list of [TokenDto]s to [ApiKey] entities.
  static List<ApiKey> toEntityList(
    List<TokenDto> dtos, {
    required String accountId,
  }) {
    return dtos.map((dto) => toEntity(dto, accountId: accountId)).toList();
  }
}
