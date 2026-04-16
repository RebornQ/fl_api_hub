/// Riverpod providers for the Keys feature.
///
/// Wires [KeysRepositoryImpl] to its dependencies and exposes the
/// [keysProvider] family notifier for UI consumption. Keys are always
/// accessed in the context of a specific account, hence the family provider.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/keys_local_datasource.dart';
import '../../data/repositories/keys_repository_impl.dart';
import '../../domain/entities/api_key.dart';
import '../../domain/repositories/keys_repository.dart';
import 'keys_notifier.dart';

export 'keys_notifier.dart';

/// Provides the [KeysRepository] implementation.
final keysRepositoryProvider = Provider<KeysRepository>((ref) {
  return KeysRepositoryImpl(ref.watch(keysLocalDataSourceProvider));
});

/// Manages the list of [ApiKey] entities for a specific account.
///
/// Usage: `ref.watch(keysProvider(accountId))` to get keys for an account.
final keysProvider =
    AsyncNotifierProvider.family<KeysNotifier, List<ApiKey>, String>(
      KeysNotifier.new,
    );
