/// Application-wide default constants.
///
/// Centralizes "magic values" that have business meaning so they can be
/// tuned from a single place (and eventually fed from remote configuration).
library;

/// Default USD → CNY exchange rate applied when an account has no site-specific
/// override. Mirrors the PRD baseline `7.24` used by the Stitch design.
const double kDefaultUsdToCnyRate = 7.24;

/// Default quota → USD conversion factor for New API compatible backends.
///
/// New API and its forks (OneHub, DoneHub, Veloera, Octopus, …) expose account
/// usage in a token-unit "quota" rather than currency. The upstream convention
/// is `500000 quota = $1 USD`, which the site admin may override via the
/// `quota_per_unit` field returned from `GET /api/status`.
///
/// This constant is the fallback used when `/api/status` is unreachable or
/// does not report `quota_per_unit`.
const double kDefaultQuotaPerUnit = 500000.0;
