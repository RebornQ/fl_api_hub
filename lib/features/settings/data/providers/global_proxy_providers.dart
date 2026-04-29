/// Riverpod providers for the global proxy setting.
///
/// Provides the [GlobalProxyRepository] and a read-only
/// [currentGlobalProxyProvider] for use by the network layer when resolving
/// per-request proxy configuration.
///
/// The full UI notifier (with save/toggle) belongs in S4 and should be added
/// to a separate file or merged here when that subtask is implemented.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/global_proxy_setting.dart';
import '../../domain/repositories/global_proxy_repository.dart';
import '../datasources/global_proxy_local_datasource.dart';
import '../repositories/global_proxy_repository_impl.dart';

/// Provider for the [GlobalProxyRepository] implementation.
final globalProxyRepositoryProvider = Provider<GlobalProxyRepository>((ref) {
  final local = ref.watch(globalProxyLocalDataSourceProvider);
  return GlobalProxyRepositoryImpl(local);
});

/// Reads the current [GlobalProxySetting] from local storage.
///
/// This is a synchronous read because the Hive box is already open and
/// populated during [initHive]. Used by [ProxyResolver] via
/// [ref.read] (not [ref.watch]) since it is consumed inside a method,
/// not a provider build.
final currentGlobalProxyProvider = Provider<GlobalProxySetting>((ref) {
  final local = ref.read(globalProxyLocalDataSourceProvider);
  return local.read();
});
