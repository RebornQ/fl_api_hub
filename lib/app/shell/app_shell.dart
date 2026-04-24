import 'package:flutter/material.dart';

import '../../features/accounts/presentation/pages/accounts_page.dart';
import '../../features/check_in/presentation/pages/check_in_page.dart';
import '../../features/keys/presentation/pages/keys_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';

/// Root shell with global top app bar and bottom navigation bar.
///
/// Uses [IndexedStack] to preserve page state across tab switches.
/// Tab order: Check-in → Accounts → Keys → Settings.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  static const _pages = <Widget>[
    CheckInPage(),
    AccountsPage(),
    KeysPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: _buildAppBar(context, colorScheme),
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.event_available_outlined),
            selectedIcon: Icon(Icons.event_available),
            label: '签到',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: '账号',
          ),
          NavigationDestination(
            icon: Icon(Icons.vpn_key_outlined),
            selectedIcon: Icon(Icons.vpn_key),
            label: '密钥',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }

  /// Global brand app bar: "Fl API HUB" logo + wordmark on the left.
  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return AppBar(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: colorScheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 20,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hub, color: colorScheme.primary, size: 24),
          const SizedBox(width: 12),
          Text(
            'Fl API HUB',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: colorScheme.outlineVariant.withValues(alpha: 0.15),
        ),
      ),
    );
  }
}
