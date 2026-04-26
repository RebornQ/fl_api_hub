library;

import '../../../../core/result/result.dart';
import '../entities/browser_preference.dart';

abstract class BrowserRepository {
  Future<Result<BrowserPreference>> getPreference();
  Future<Result<void>> savePreference(BrowserPreference preference);
}
