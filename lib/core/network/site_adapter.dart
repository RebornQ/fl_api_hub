/// Abstract interface for site-specific API adapters.
///
/// Each [SiteType] will have its own [SiteAdapter] implementation that
/// translates the common API surface into site-specific request/response
/// handling. The adapter pattern decouples business logic from individual
/// site quirks.
library;

import '../result/result.dart';
import 'site_type.dart';

/// Interface that every site-specific API adapter must implement.
///
/// Return types currently use [Map<String, dynamic>] as placeholders.
/// TODO: Replace with typed domain models once they are defined in Batch 3.
abstract class SiteAdapter {
  /// The site type this adapter handles.
  SiteType get siteType;

  /// Fetches account information (balance, usage, etc.).
  Future<Result<Map<String, dynamic>>> fetchAccountInfo({
    required String baseUrl,
    required String authToken,
    required AuthType authType,
  });

  /// Performs a daily check-in.
  Future<Result<Map<String, dynamic>>> checkIn({
    required String baseUrl,
    required String authToken,
    required AuthType authType,
  });

  /// Lists API tokens / keys for the account.
  Future<Result<List<Map<String, dynamic>>>> listTokens({
    required String baseUrl,
    required String authToken,
    required AuthType authType,
  });
}
