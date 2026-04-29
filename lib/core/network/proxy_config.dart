/// HTTP/HTTPS proxy configuration value object.
///
/// Shared between account-level proxy overrides and the global proxy
/// setting. Both consumers serialize this through plain `Map<String,
/// dynamic>` payloads to stay aligned with the rest of the Hive layer.
///
/// Equality is field-based (a value object), but [authority] intentionally
/// omits the password so it can be used as a Dio pool cache key without
/// leaking secrets into log lines or error messages.
library;

/// Transport scheme for the proxy connection.
enum ProxyScheme {
  http,
  https;

  /// Parses a stored string value back to [ProxyScheme].
  ///
  /// Returns [ProxyScheme.http] for unknown or `null` values to keep legacy
  /// payloads working without throwing.
  static ProxyScheme fromString(String? value) => switch (value) {
    'http' => http,
    'https' => https,
    _ => http,
  };
}

/// Immutable HTTP/HTTPS proxy configuration.
///
/// Used by both [Account.proxyConfig] (account-level override) and
/// [GlobalProxySetting.config] (app-wide global proxy).
class ProxyConfig {
  final ProxyScheme scheme;
  final String host;
  final int port;
  final String? username;
  final String? password;

  const ProxyConfig({
    required this.scheme,
    required this.host,
    required this.port,
    this.username,
    this.password,
  });

  ProxyConfig copyWith({
    ProxyScheme? scheme,
    String? host,
    int? port,
    String? username,
    String? password,
  }) {
    return ProxyConfig(
      scheme: scheme ?? this.scheme,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }

  /// Field-by-field equality. Equivalent to [operator ==] for this value
  /// object; kept as a named method to mirror the `deepEquals` convention
  /// used elsewhere in the codebase.
  bool deepEquals(ProxyConfig other) => this == other;

  /// Cache key for Dio instance pooling.
  ///
  /// Format:
  /// - without auth: `scheme://host:port`
  /// - with auth:    `scheme://username@host:port`
  ///
  /// The password is intentionally excluded — different passwords for the
  /// same `(scheme, host, port, username)` triple still map to the same
  /// pool entry, but the password is applied at the [HttpClient] level via
  /// `addProxyCredentials`, not via this string.
  String get authority {
    final schemeStr = scheme.name;
    final user = (username == null || username!.isEmpty) ? '' : '$username@';
    return '$schemeStr://$user$host:$port';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProxyConfig &&
        scheme == other.scheme &&
        host == other.host &&
        port == other.port &&
        username == other.username &&
        password == other.password;
  }

  @override
  int get hashCode => Object.hash(scheme, host, port, username, password);

  /// Debug representation. The password is replaced with a fixed mask so
  /// proxy values can be safely emitted to logs and error messages.
  @override
  String toString() {
    final maskedPassword = (password == null || password!.isEmpty)
        ? 'null'
        : '***';
    return 'ProxyConfig(scheme: ${scheme.name}, host: $host, port: $port, '
        'username: $username, password: $maskedPassword)';
  }
}
