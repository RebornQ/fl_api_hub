/// Riverpod providers for the Accounts feature.
///
/// Wires [AccountsRepositoryImpl] to its dependencies and exposes the
/// [accountsProvider] notifier for UI consumption.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/accounts_local_datasource.dart';
import '../../data/repositories/accounts_repository_impl.dart';
import '../../domain/entities/account.dart';
import '../../domain/repositories/accounts_repository.dart';
import 'accounts_notifier.dart';

export 'accounts_notifier.dart';

/// Provides the [AccountsRepository] implementation.
final accountsRepositoryProvider = Provider<AccountsRepository>((ref) {
  return AccountsRepositoryImpl(ref.watch(accountsLocalDataSourceProvider));
});

/// Manages the list of [Account] entities.
///
/// UI code should watch this provider to reactively display the account list.
/// Mutations (create, update, delete) are performed via the notifier methods.
final accountsProvider = AsyncNotifierProvider<AccountsNotifier, List<Account>>(
  AccountsNotifier.new,
);
