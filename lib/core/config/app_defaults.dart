/// Application-wide default constants.
///
/// Centralizes "magic values" that have business meaning so they can be
/// tuned from a single place (and eventually fed from remote configuration).
library;

/// Default USD → CNY exchange rate applied when an account has no site-specific
/// override. Mirrors the PRD baseline `7.24` used by the Stitch design.
const double kDefaultUsdToCnyRate = 7.24;
