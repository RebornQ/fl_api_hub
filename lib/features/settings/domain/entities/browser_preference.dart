/// User preference for built-in browser behavior.
library;

/// Immutable snapshot of browser preferences.
class BrowserPreference {
  /// Whether to use the built-in in-app browser instead of the system browser.
  final bool useInAppBrowser;

  const BrowserPreference({this.useInAppBrowser = true});

  BrowserPreference copyWith({bool? useInAppBrowser}) => BrowserPreference(
    useInAppBrowser: useInAppBrowser ?? this.useInAppBrowser,
  );
}
