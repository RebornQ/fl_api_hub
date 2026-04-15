/// Application navigation constants.
///
/// For now the only routes are the three bottom-navigation tabs managed by
/// [IndexedStack] in [AppShell]. When deep navigation is needed, a routing
/// package (e.g. go_router) can be introduced and this file will expand.
library;

/// Tab index constants for the bottom navigation bar.
abstract final class AppRoutes {
  static const int checkInTab = 0;
  static const int accountsTab = 1;
  static const int keysTab = 2;
}
