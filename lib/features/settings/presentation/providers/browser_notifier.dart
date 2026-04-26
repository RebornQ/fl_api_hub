library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/result/result.dart';
import '../../domain/entities/browser_preference.dart';
import '../../domain/repositories/browser_repository.dart';
import 'browser_providers.dart';

class BrowserNotifier extends AsyncNotifier<BrowserPreference> {
  @override
  Future<BrowserPreference> build() async {
    final result = await _repo.getPreference();
    return switch (result) {
      Success(:final data) => data,
      Failure() => const BrowserPreference(),
    };
  }

  BrowserRepository get _repo => ref.read(browserRepositoryProvider);

  Future<void> setUseInAppBrowser(bool enabled) async {
    final current = state.valueOrNull ?? const BrowserPreference();
    final updated = current.copyWith(useInAppBrowser: enabled);
    state = AsyncData(updated);
    await _repo.savePreference(updated);
  }
}
