/// Repository contract for persisting and reading the global proxy
/// setting.
library;

import '../../../../core/result/result.dart';
import '../entities/global_proxy_setting.dart';

abstract class GlobalProxyRepository {
  /// Returns the currently persisted [GlobalProxySetting], or the default
  /// [GlobalProxySetting.disabled] if nothing has been stored yet.
  Future<Result<GlobalProxySetting>> getCurrent();

  /// Persists [setting] to local storage.
  Future<Result<void>> save(GlobalProxySetting setting);
}
