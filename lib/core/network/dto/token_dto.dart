/// DTOs for token-related API endpoints.
///
/// Covers `GET /api/token/` (list), `POST /api/token/` (create),
/// `GET /api/token/{id}` (detail), and `POST /api/token/{id}/key` (secret key).
///
/// Supports both Common API fields (`remain_quota`, `used_quota`, `expired_time`)
/// and Sub2API fields (`quota` in USD, `quota_used` in USD, `expires_at`).
library;

/// Internal quota → USD conversion factor (1 USD = 500000 internal units).
const _kQuotaPerUnit = 500000;

/// A single API token from the token list or detail endpoint.
///
/// Fields are normalized to internal quota units regardless of backend family.
/// Sub2API USD values are converted at parse time.
class TokenDto {
  /// Server-assigned token ID (numeric string).
  final String? id;

  /// Display name of the token.
  final String? name;

  /// Token key value. Masked in list responses (e.g. "sk-***abc"),
  /// full value from the `/key` endpoint.
  final String? key;

  /// Remaining quota in internal units. `null` means unlimited.
  ///
  /// Common API: parsed from `remain_quota` (already internal units).
  /// Sub2API: parsed from `quota` (USD) and converted via `× 500000`.
  final int? remainQuota;

  /// Quota already consumed in internal units.
  ///
  /// Common API: parsed from `used_quota`.
  /// Sub2API: parsed from `quota_used` (USD) and converted via `× 500000`.
  final int? usedQuota;

  /// Whether the token has unlimited quota.
  final bool unlimitedQuota;

  /// Token status: 1 = enabled, 0 = disabled.
  ///
  /// Common API returns int (1/2/3). Sub2API returns string ("active"/"inactive").
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
    this.remainQuota,
    this.usedQuota,
    this.unlimitedQuota = false,
    this.status,
    this.createdAt,
    this.accessedAt,
    this.expiresAt,
  });

  /// Parses a raw JSON map into a [TokenDto].
  ///
  /// Handles both Common API and Sub2API field names:
  /// - `remain_quota` (Common) or `quota` (Sub2API, in USD)
  /// - `used_quota` (Common) or `quota_used` (Sub2API, in USD)
  /// - `expired_time` (Common, unix) or `expires_at` (Sub2API, ISO 8601)
  /// - `status` as int (Common) or string (Sub2API)
  static TokenDto fromJson(Map<String, dynamic> json) {
    // Quota: prefer remain_quota (Common), fall back to quota (Sub2API in USD).
    final remainQuota = _parseQuota(
      json['remain_quota'],
      fallbackUsd: json['quota'],
    );

    // Used quota: prefer used_quota (Common), fall back to quota_used (Sub2API USD).
    final usedQuota = _parseQuota(
      json['used_quota'],
      fallbackUsd: json['quota_used'],
    );

    final unlimitedQuota = json['unlimited_quota'] as bool? ?? false;

    return TokenDto(
      id: json['id']?.toString(),
      name: json['name'] as String?,
      key: json['key'] as String?,
      remainQuota: remainQuota,
      usedQuota: usedQuota,
      unlimitedQuota: unlimitedQuota,
      status: _parseStatus(json['status']),
      createdAt: _parseDateTime(json['created_time'] ?? json['created_at']),
      accessedAt: _parseDateTime(json['accessed_time']),
      expiresAt: _parseDateTime(
        json['expired_time'] ?? json['expires_at'],
        neverExpiresSentinel: true,
      ),
    );
  }

  /// Whether the key value appears to be masked by the server.
  bool get isKeyMasked =>
      key != null && (key!.contains('***') || key!.contains('…'));

  /// Parses quota from internal units, or converts USD to internal units.
  ///
  /// Common API provides quota in internal units (int).
  /// Sub2API provides quota in USD (num), which needs `× 500000`.
  static int? _parseQuota(dynamic raw, {dynamic fallbackUsd}) {
    if (raw is num) return raw.toInt();
    // If the Common field is absent, try the Sub2API USD field.
    if (raw == null && fallbackUsd is num) {
      return (fallbackUsd * _kQuotaPerUnit).round();
    }
    return null;
  }

  /// Parses status from either int or string representation.
  ///
  /// Common API: int (1=enabled, 2=disabled, 3=expired).
  /// Sub2API: string ("active", "inactive", "quota_exhausted", "expired").
  static int? _parseStatus(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      return value.toLowerCase() == 'active' ? 1 : 0;
    }
    return null;
  }

  static DateTime? _parseDateTime(
    dynamic value, {
    bool neverExpiresSentinel = false,
  }) {
    if (value is int) {
      // -1 is the sentinel for "never expires".
      if (neverExpiresSentinel && value == -1) return null;
      if (value <= 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

/// Paginated token list response.
///
/// Handles three response formats:
/// 1. Common standard: `{"items": [...], "total": N}`
/// 2. Common direct array: `[...]`
/// 3. OneHub: `{"data": [...], "total_count": N}`
class TokenListDto {
  /// Tokens in the current page.
  final List<TokenDto> tokens;

  /// Total number of tokens across all pages.
  final int? total;

  const TokenListDto({required this.tokens, this.total});

  /// Parses a raw JSON map into a [TokenListDto].
  static TokenListDto fromJson(Map<String, dynamic> json) {
    // Try "items" (Common standard), then "data" (OneHub / direct array body).
    final items = json['items'] ?? json['data'];

    final List<TokenDto> tokens;
    if (items is List<dynamic>) {
      tokens = items
          .map((e) => TokenDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      tokens = const [];
    }

    return TokenListDto(
      tokens: tokens,
      total: (json['total'] ?? json['total_count']) as int?,
    );
  }
}
