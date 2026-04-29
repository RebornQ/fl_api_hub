# S2 · 网络层 — Dio Pool & Proxy Resolver

> 父任务：`04-30-04-30-proxy-config`
> 依赖：S1（需要 `ProxyConfig` 实体）

## Goal

把 `DioClient` 从单 Dio 实例改造为按代理键缓存的 Dio 池；新增
`ProxyResolver` 计算运行时生效的 ProxyConfig；在所有 SiteAdapter 链路
透传 proxy；提供「测试代理连通性」的领域能力。

## Scope

- `lib/core/network/`、`lib/features/accounts/data/repositories/`
  以及调用链上的 `repositories/notifiers`。
- 不动 UI（presentation）；不动 backup；不动 settings 的 UI。

## Requirements

### R1: DioClient 改造为代理池

`lib/core/network/dio_client.dart`：

```dart
class DioClient {
  final Map<String, Dio> _pool = {};
  final void Function(Dio) _configureInterceptors;

  DioClient(this._configureInterceptors) {
    _pool[_directKey] = _buildDio(proxy: null);
  }

  Dio getDio({ProxyConfig? proxy}) {
    final key = _keyFor(proxy);
    return _pool.putIfAbsent(key, () => _buildDio(proxy: proxy));
  }

  Dio _buildDio({ProxyConfig? proxy}) { ... }
  static String _keyFor(ProxyConfig? p) => p == null
      ? _directKey
      : '${p.scheme.name}://${p.host}:${p.port}';
}
```

要点：
- `_buildDio` 内部必须使用 `IOHttpClientAdapter`（dart:io 平台），
  设置 `httpClient.findProxy = (uri) => 'PROXY host:port'`，并通过
  `httpClient.addProxyCredentials` 添加 BasicAuth（仅 user+pass 都
  非空时）。
- Web 平台（`kIsWeb`）→ `BrowserHttpClientAdapter`；不设置 proxy（浏览器
  自决），但保持池接口对称。
- 每个 Dio 都挂 `AuthInterceptor` + `RequestLoggerInterceptor`，
  interceptor 的注入方式从 provider 提取为函数注入（`_configureInterceptors`）。
- 移除现有 `addInterceptor` / `removeInterceptorsOfType` 公开 API
  会破坏 request_logger 的开关，需要保留——但是要应用到池中所有
  Dio。建议改为：interceptor 工厂在池每次 `_buildDio` 时被调用，
  状态由外部 ref 控制（ref.read(requestLoggerEnabledProvider) 已经是
  动态读取，所以新建 Dio 时只要按相同方式注入即可）。

### R2: dioClientProvider 适配

- 仍然返回单一 `DioClient` 实例（池在内部）；调用方不需要知道有池。
- 调用方从 `client.dio.get(...)` 改为：
  ```dart
  client.getDio(proxy: request.proxy).get(...);
  ```
  → 修改 6 个 SiteAdapter 中所有 `dio.get/post/put/delete` 调用点。

### R3: ProxyResolver

新增 `lib/core/network/proxy_resolver.dart`：

```dart
class ProxyResolver {
  ProxyConfig? resolve(Account account, GlobalProxySetting global) {
    switch (account.proxyMode) {
      case AccountProxyMode.direct:       return null;
      case AccountProxyMode.custom:       return account.proxyConfig;
      case AccountProxyMode.followGlobal:
        return global.enabled ? global.config : null;
    }
  }
}
```

并提供 Riverpod 入口：
```dart
final proxyResolverProvider = Provider((ref) => const ProxyResolver());
```

不在 resolver 里读取 provider；保持纯函数语义。

### R4: ApiRequest.proxy 透传

`lib/core/network/api_request.dart`：
```dart
class ApiRequest {
  ...
  final ProxyConfig? proxy;
  const ApiRequest({..., this.proxy});
}
```

构造点（多在 `lib/features/accounts/data/repositories/`、
`lib/features/keys/.../repositories/`、`lib/features/check_in/...`）：
- 仓储构造 `ApiRequest` 之前，先 `ref.read` 全局代理 settings 和
  目标 account → 调用 `ProxyResolver.resolve` → 注入 `proxy`。

### R5: 6 个 SiteAdapter 切换 Dio 取得方式

文件清单：
- `lib/core/network/adapters/common_api_adapter.dart`
- `lib/core/network/adapters/onehub_adapter.dart`
- `lib/core/network/adapters/donehub_adapter.dart`
- `lib/core/network/adapters/veloera_api_adapter.dart`
- `lib/core/network/adapters/sub2api_adapter.dart`
- `lib/core/network/adapters/wong_api_adapter.dart`

每处使用 `dioClient.dio.get(...)` 改为 `dioClient.getDio(proxy: request.proxy).get(...)`。

### R6: 测试连通性 use case

新增 `lib/core/network/proxy_test_service.dart`：

```dart
class ProxyTestService {
  final DioClient _client;
  ProxyTestService(this._client);

  Future<ProxyTestResult> test({
    required ProxyConfig? proxy,
    required String targetUrl, // 可空时用默认探针
    Duration timeout = const Duration(seconds: 8),
  }) async { ... }
}

sealed class ProxyTestResult {
  const ProxyTestResult();
}
class ProxyTestSuccess extends ProxyTestResult {
  final int statusCode;
  final Duration latency;
  const ProxyTestSuccess(this.statusCode, this.latency);
}
class ProxyTestFailure extends ProxyTestResult {
  final String reason;     // 用户可读
  final Object? cause;     // 原始 exception
  const ProxyTestFailure(this.reason, [this.cause]);
}
```

- 默认探针 URL：`https://www.gstatic.com/generate_204`（成功条件
  `statusCode == 204`）；账号场景下传 `account.baseUrl`。
- 不绕过 SSL 校验。
- Riverpod provider：`proxyTestServiceProvider`。

### R7: Web 平台兜底

- `kIsWeb` 时 `_buildDio` 跳过 proxy 配置；
- `ProxyTestService` 在 Web 直接返回
  `ProxyTestFailure('Web 平台代理由浏览器决定，无法测试')`。

## Acceptance Criteria

- [ ] `DioClient.getDio()` / `getDio(proxy: same)` 返回同一实例；不同
      proxy 返回不同实例
- [ ] 已有 `request_logger` 开关在池 Dio 中仍正常工作
- [ ] 6 个 SiteAdapter 全部切换到 `getDio(proxy:)`，无残留
      `dioClient.dio` 调用
- [ ] `ProxyResolver` 三态优先级单测覆盖（建议加 `test/`）
- [ ] `ProxyTestService.test` 可识别成功 / 超时 / 认证失败 / DNS 失败
      四类结果
- [ ] 现有签到 / 余额刷新 / token 列表流程在 `proxy: null` 下行为一致
- [ ] `flutter analyze` 0 警告

## Out of Scope

- 不写 UI
- 不动 backup（S1 已处理）
- 不实现 SOCKS5

## Files to Touch

**新增：**
- `lib/core/network/proxy_resolver.dart`
- `lib/core/network/proxy_test_service.dart`
- 测试文件：`test/core/network/proxy_resolver_test.dart`

**修改：**
- `lib/core/network/dio_client.dart`（重构为池）
- `lib/core/network/api_request.dart`（新增 proxy 字段）
- 6 个 `lib/core/network/adapters/*.dart`
- 仓储构造 `ApiRequest` 处（按 grep 结果定位）

## Definition of Done

- 父 PRD 的 R2 / R3 / R4 / R9 在网络层视角下完成
- 单测：`ProxyResolver` 三态语义验证通过
- 手测：自定义代理 + 测试按钮在 S3 接入后可端到端跑通

## Technical Notes

- dart:io HttpClient 代理设置 reference：
  - `findProxy: (Uri uri) => 'PROXY user:pass@host:port'` ❌
    （dart:io 不支持串内置认证）
  - `findProxy: (Uri uri) => 'PROXY host:port'` ✅
  - 认证用 `addProxyCredentials(host, port, realm, credentials)`，
    `realm` 一般传空串 `''`，`credentials = HttpClientBasicCredentials(user, pass)`
- 密码字段不进入池缓存键（避免内存里多份同 host:port 但不同密码
  的 Dio）；同 host:port 不同账号传不同密码时，本设计假定「密码与
  代理终结点 1:1」。若未来发现冲突，再扩展键。
