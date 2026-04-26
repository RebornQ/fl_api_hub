/// Riverpod providers for the Keys feature.
///
/// Wires [KeysRepositoryImpl] to its dependencies and exposes the
/// [keysProvider] family notifier for UI consumption. Keys are always
/// accessed in the context of a specific account, hence the family provider.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../accounts/presentation/providers/accounts_providers.dart';
import '../../../../core/network/api_request.dart';
import '../../../../core/network/site_adapter_provider.dart';
import '../../data/datasources/keys_local_datasource.dart';
import '../../data/datasources/keys_remote_datasource.dart';
import '../../data/repositories/keys_repository_impl.dart';
import '../../domain/entities/api_key.dart';
import '../../domain/repositories/keys_repository.dart';
import 'keys_notifier.dart';

/// Provides the [KeysRepository] for a specific [accountId].
///
/// When the account is found and has valid auth, creates a remote-enabled
/// repository. Otherwise falls back to local-only mode.
final keysRepositoryProvider =
    Provider.family<KeysRepository, String>((ref, accountId) {
  final local = ref.watch(keysLocalDataSourceProvider);
  final accounts = ref.watch(accountsProvider).valueOrNull ?? [];
  final account = accounts.where((a) => a.id == accountId).firstOrNull;

  if (account == null) {
    return KeysRepositoryImpl.localOnly(local);
  }

  final adapter = ref.watch(siteAdapterForTypeProvider(account.siteType));
  final remote = KeysRemoteDataSource(adapter);
  final request = ApiRequest(
    baseUrl: account.baseUrl,
    authToken: account.accessToken,
    authType: account.authType,
    userId: account.userId > 0 ? account.userId : null,
  );

  return KeysRepositoryImpl(remote: remote, request: request, local: local);
});

/// Manages the list of [ApiKey] entities for a specific account.
///
/// Usage: `ref.watch(keysProvider(accountId))` to get keys for an account.
final keysProvider =
    AsyncNotifierProvider.family<KeysNotifier, List<ApiKey>, String>(
      KeysNotifier.new,
    );
