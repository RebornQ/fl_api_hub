import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/accounts/presentation/pages/accounts_page.dart';
import '../../features/check_in/presentation/pages/check_in_page.dart';
import '../../features/keys/presentation/pages/keys_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../router.dart';

/// Time window for the double-back-to-exit gesture on the home tab.
const _exitTimeout = Duration(seconds: 2);

/// Root shell with global top app bar and bottom navigation bar.
///
/// Uses [IndexedStack] to preserve page state across tab switches.
/// Tab order: Check-in → Accounts → Keys → Settings.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _pages = <Widget>[
    CheckInPage(),
    AccountsPage(),
    KeysPage(),
    SettingsPage(),
  ];

  /// Whether the first back-press on the home tab has occurred and the
  /// exit countdown is active.
  bool _exitCountdownActive = false;
  Timer? _exitTimer;

  @override
  void dispose() {
    _exitTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(tabIndexProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // Only allow the route to pop (i.e. exit the app) when on the home tab
    // AND the user has pressed back twice within the timeout window.
    final canPop = currentIndex == AppRoutes.checkInTab && _exitCountdownActive;

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        if (currentIndex != AppRoutes.checkInTab) {
          // On a non-home tab — switch to home.
          ref.read(tabIndexProvider.notifier).state = AppRoutes.checkInTab;
          return;
        }

        // On home tab — handle double-back-to-exit.
        if (_exitCountdownActive) {
          // Second press within the window — exit.
          // This shouldn't normally be reached because canPop is true,
          // but handle it defensively.
          Navigator.of(context).pop();
          return;
        }

        // First press — show snackbar and start countdown.
        setState(() => _exitCountdownActive = true);
        _exitTimer = Timer(_exitTimeout, () {
          if (mounted) {
            setState(() => _exitCountdownActive = false);
          }
        });
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('再按一次退出应用'),
            behavior: SnackBarBehavior.floating,
            duration: _exitTimeout,
          ),
        );
      },
      child: Scaffold(
        appBar: _buildAppBar(context, colorScheme),
        body: IndexedStack(index: currentIndex, children: _pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (index) {
            ref.read(tabIndexProvider.notifier).state = index;
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
