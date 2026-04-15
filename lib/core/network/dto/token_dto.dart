/// DTOs for token-related API endpoints.
///
/// Covers `GET /api/token/` (list), `POST /api/token/` (create),
/// `GET /api/token/{id}` (detail), and `POST /api/token/{id}/key` (secret key).
library;

/// A single API token from the token list or detail endpoint.
class TokenDto {
  /// Server-assigned token ID (numeric string).
  final String? id;

  /// Display name of the token.
  final String? name;

  /// Token key value. Masked in list responses (e.g. "sk-***abc"),
  /// full value from the `/key` endpoint.
  final String? key;

  /// Quota limit for this token. `null` means unlimited.
  final int? quota;

  /// Quota already consumed.
  final int? usedQuota;

  /// Token status (e.g. 1 = enabled, 2 = disabled, 3 = expired).
  final int? status;

  /// When this token was created on the server.
  final DateTime? createdAt;

  /// When this token was last accessed.
  final DateTime? accessedAt;

  /// When this token expires. `null` means never expires.
  final DateTime? expiresAt;

  const TokenDto({
    this.id,
    this.name,
    this.key,
    this.quota,
    this.usedQuota,
    this.status,
    this.createdAt,
    this.accessedAt,
    this.expiresAt,
  });

  /// Parses a raw JSON map into a [TokenDto].
  static TokenDto fromJson(Map<String, dynamic> json) {
    return TokenDto(
      id: json['id']?.toString(),
      name: json['name'] as String?,
      key: json['key'] as String?,
      quota: (json['quota'] as num?)?.toInt(),
      usedQuota: (json['used_quota'] as num?)?.toInt(),
      status: json['status'] as int?,
      createdAt: _parseDateTime(json['created_time']),
      accessedAt: _parseDateTime(json['accessed_time']),
      expiresAt: _parseDateTime(json['expired_time']),
    );
  }

  /// Whether the key value appears to be masked.
  bool get isKeyMasked =>
      key != null && (key!.contains('***') || key!.contains('***'));

  static DateTime? _parseDateTime(dynamic value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

/// Paginated token list response.
class TokenListDto {
  /// Tokens in the current page.
  final List<TokenDto> tokens;

  /// Total number of tokens across all pages.
  final int? total;

  const TokenListDto({required this.tokens, this.total});

  /// Parses a raw JSON map into a [TokenListDto].
  ///
  /// Handles both the standard envelope where `data` contains `items` + `total`,
  /// and the direct array format.
  static TokenListDto fromJson(Map<String, dynamic> json) {
    // Standard format: {"items": [...], "total": N}
    final items = json['items'] ?? json['data'];

    final List<TokenDto> tokens;
    if (items is List<dynamic>) {
      tokens = items
          .map((e) => TokenDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      tokens = const [];
    }

    return TokenListDto(tokens: tokens, total: json['total'] as int?);
  }
}
