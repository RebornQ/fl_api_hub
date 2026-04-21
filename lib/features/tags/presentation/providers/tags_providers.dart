/// Riverpod providers for the Tags feature.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../accounts/presentation/providers/accounts_providers.dart';
import '../../data/datasources/tags_local_datasource.dart';
import '../../data/repositories/tags_repository_impl.dart';
import '../../domain/entities/tag.dart';
import '../../domain/repositories/tags_repository.dart';
import 'tags_notifier.dart';

export 'tags_notifier.dart';

/// Provides the [TagsRepository] implementation.
final tagsRepositoryProvider = Provider<TagsRepository>((ref) {
  return TagsRepositoryImpl(
    ref.watch(tagsLocalDataSourceProvider),
    ref.watch(accountsRepositoryProvider),
  );
});

/// Manages the list of [Tag] entities.
///
/// UI code should watch this provider to reactively display the tag list.
/// Mutations (upsert, rename, delete) are performed via the notifier methods.
final tagsProvider = AsyncNotifierProvider<TagsNotifier, List<Tag>>(
  TagsNotifier.new,
);
