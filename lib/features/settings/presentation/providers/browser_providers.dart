library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/browser_local_datasource.dart' as data;
import '../../data/repositories/browser_repository_impl.dart';
import '../../domain/entities/browser_preference.dart';
import '../../domain/repositories/browser_repository.dart';
import 'browser_notifier.dart';

final browserRepositoryProvider = Provider<BrowserRepository>((ref) {
  return BrowserRepositoryImpl(ref.read(data.browserLocalDataSourceProvider));
});

final browserProvider =
    AsyncNotifierProvider<BrowserNotifier, BrowserPreference>(
      BrowserNotifier.new,
    );

final useInAppBrowserProvider = Provider<bool>((ref) {
  final asyncPref = ref.watch(browserProvider);
  return asyncPref.valueOrNull?.useInAppBrowser ?? true;
});
