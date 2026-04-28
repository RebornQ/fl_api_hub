/// Riverpod providers for group selection in the key form.
///
/// Provides a family provider that fetches available groups for a specific
/// account. Groups are fetched on demand when the key form opens.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../accounts/presentation/providers/accounts_providers.dart';
import '../../../../core/network/api_request.dart';
import '../../../../core/network/dto/group_dto.dart';
import '../../../../core/network/site_adapter_provider.dart';
import '../../../../core/result/result.dart';

/// Fetches available groups for a specific [accountId].
///
/// Returns a list of [GroupDto] on success, or an empty list on failure
/// (graceful degradation for offline/network errors).
final groupsProvider = FutureProvider.family<List<GroupDto>, String>((
  ref,
  accountId,
) async {
  final accounts = ref.watch(accountsProvider).valueOrNull ?? [];
  final account = accounts.where((a) => a.id == accountId).firstOrNull;

  if (account == null) {
    return [];
  }

  final adapter = ref.watch(siteAdapterForTypeProvider(account.siteType));
  final request = ApiRequest(
    baseUrl: account.baseUrl,
    authToken: account.accessToken,
    authType: account.authType,
    userId: account.userId > 0 ? account.userId : null,
  );

  final result = await adapter.fetchGroups(request);
  return result.when(
    onSuccess: (groupList) => groupList.groups,
    onFailure: (_) => [],
  );
});
