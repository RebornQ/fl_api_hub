/// Application navigation constants.
///
/// For now the only routes are the bottom-navigation tabs managed by
/// [IndexedStack] in [AppShell]. When deep navigation is needed, a routing
/// package (e.g. go_router) can be introduced and this file will expand.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tab index constants for the bottom navigation bar.
abstract final class AppRoutes {
  static const int checkInTab = 0;
  static const int accountsTab = 1;
  static const int keysTab = 2;
  static const int settingsTab = 3;
}

/// Currently selected bottom-navigation tab index.
final tabIndexProvider = StateProvider<int>((ref) => 0);
