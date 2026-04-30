/// Local data source for browser preferences stored in Hive [app_data] box.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../domain/entities/browser_preference.dart';

class BrowserLocalDataSource {
  static const _keyUseInAppBrowser = 'browser_use_in_app';

  final Box _box;

  BrowserLocalDataSource(this._box);

  BrowserPreference read() {
    final useInApp = _box.get(_keyUseInAppBrowser) as bool?;
    return BrowserPreference(useInAppBrowser: useInApp ?? true);
  }

  Future<void> write(BrowserPreference preference) async {
    await _box.put(_keyUseInAppBrowser, preference.useInAppBrowser);
  }
}

final browserLocalDataSourceProvider = Provider<BrowserLocalDataSource>((ref) {
  return BrowserLocalDataSource(Hive.box('app_data'));
});
