/// Global provider for the split-pane ratio.
///
/// Persists the ratio to Hive (key `split_pane_ratio`) via the existing
/// [keyValueStoreProvider] so it survives app restarts.  The ratio is clamped
/// to [minRatio]–[maxRatio] on read to guard against stale values.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'hive_store.dart';

const _kKey = 'split_pane_ratio';
const kDefaultSplitRatio = 0.4;
const kMinSplitRatio = 0.3;
const kMaxSplitRatio = 0.5;

/// Global split-pane ratio. Defaults to [kDefaultSplitRatio] (40% left).
///
/// Read via `ref.watch(splitPaneRatioProvider)` and write via
/// `ref.read(splitPaneRatioProvider.notifier).setRatio(value)`.
final splitPaneRatioProvider = NotifierProvider<SplitPaneRatioNotifier, double>(
  SplitPaneRatioNotifier.new,
);

/// Notifier that hydrates from Hive and persists on change.
class SplitPaneRatioNotifier extends Notifier<double> {
  @override
  double build() {
    _hydrate();
    return kDefaultSplitRatio;
  }

  Future<void> _hydrate() async {
    final store = ref.read(keyValueStoreProvider);
    final stored = await store.read<double>(_kKey);
    if (stored != null) {
      final clamped = stored.clamp(kMinSplitRatio, kMaxSplitRatio);
      if (clamped != state) state = clamped;
    }
  }

  /// Persists [value] to Hive and updates state.
  Future<void> setRatio(double value) async {
    final clamped = value.clamp(kMinSplitRatio, kMaxSplitRatio);
    if (clamped == state) return;
    state = clamped;
    final store = ref.read(keyValueStoreProvider);
    await store.write(_kKey, clamped);
  }
}
