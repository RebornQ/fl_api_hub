/// Riverpod providers for [SiteAdapter] registration and resolution.
///
/// Maps each [SiteType] to its concrete adapter implementation. Currently
/// only the [CommonApiAdapter] is registered, which serves six site types
/// that share the same API surface. Site-specific adapters will be added
/// in future batches.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'adapters/common_api_adapter.dart';
import 'adapters/veloera_api_adapter.dart';
import 'dio_client.dart';
import 'site_adapter.dart';
import 'site_type.dart';

/// Provider for the map of [SiteType] to [SiteAdapter].
///
/// Currently registers the [CommonApiAdapter] for the new-api compatible
/// family and the [VeloeraApiAdapter] for Veloera-specific check-in path.
/// When additional site-specific adapters are added in later batches, they
/// override entries in this map.
final siteAdapterProvider = Provider<Map<SiteType, SiteAdapter>>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  final commonAdapter = CommonApiAdapter(dioClient);
  final veloeraAdapter = VeloeraApiAdapter(dioClient);
  return {
    SiteType.newApi: commonAdapter,
    SiteType.oneApi: commonAdapter,
    SiteType.oneHub: commonAdapter,
    SiteType.doneHub: commonAdapter,
    SiteType.veloera: veloeraAdapter,
    SiteType.octopus: commonAdapter,
    // Cookie-based sites (sub2api, anyrouter, wongGongyi) will use their
    // own adapters in a future batch.
  };
});

/// Convenience provider that resolves a [SiteAdapter] for a given [SiteType].
///
/// Falls back to the [SiteType.newApi] adapter if the requested site type
/// is not registered.
///
/// Usage:
/// ```dart
/// final adapter = ref.watch(siteAdapterForTypeProvider(SiteType.oneHub));
/// ```
final siteAdapterForTypeProvider = Provider.family<SiteAdapter, SiteType>((
  ref,
  siteType,
) {
  final adapters = ref.watch(siteAdapterProvider);
  return adapters[siteType] ?? adapters[SiteType.newApi]!;
});
