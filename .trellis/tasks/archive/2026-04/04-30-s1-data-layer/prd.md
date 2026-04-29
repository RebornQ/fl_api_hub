# S1 · 数据层 — Proxy Entity & Storage

> 父任务：`04-30-04-30-proxy-config`

## Goal

实现代理配置的领域模型、Hive 持久化和备份序列化，为后续网络层 + UI
提供稳定的数据契约。

## Scope

- **限定在 `domain/` + `data/` 两层**，不动 `presentation/` 与
  `core/network/`。
- 不创建任何 Riverpod UI provider；只暴露仓储接口和数据源 provider。
- 备份/恢复仅做 schema 改造（写入 + 读取），不做迁移工具。

## Requirements

### R1: ProxyConfig Entity

新增 `lib/core/network/proxy_config.dart`（放 core 层而非 feature 层，
因为账号 + 全局都共用）：

```dart
enum ProxyScheme { http, https }

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

  ProxyConfig copyWith({...});
  bool deepEquals(ProxyConfig other);
  String get authority; // "http://host:port"，用于 Dio 池缓存键
}
```

值对象语义：`==` / `hashCode` 按全字段；`authority` 不含密码；
`toString` 隐藏密码。

### R2: AccountProxyMode 枚举

放在 `lib/features/accounts/domain/entities/account.dart` 同文件或
新建 `account_proxy_mode.dart`：

```dart
enum AccountProxyMode {
  followGlobal, // 默认
  direct,       // 显式直连
  custom,       // 使用 account.proxyConfig
}
```

### R3: Account 字段扩展

- 新增 `final AccountProxyMode proxyMode;`（default `followGlobal`）
- 新增 `final ProxyConfig? proxyConfig;`
- 更新 `copyWith` / `deepEquals` / `==` 不变（仍 id 相等语义）。

### R4: AccountMapper 序列化兼容

- `toMap`：写入 `proxyMode` 字符串（`name` 形式）+ 嵌套 map
  `proxyConfig`。
- `fromMap`：缺失字段回退为 `followGlobal` + null（旧记录无痛升级）。
- `proxyConfig` 子 map 字段：`scheme`/`host`/`port`/`username`/
  `password`。
- 提取 `_proxyConfigToMap` / `_proxyConfigFromMap` 静态辅助方法。

### R5: GlobalProxySetting Entity & 仓储

按 `browser_preference` 三件套对齐：

- `lib/features/settings/domain/entities/global_proxy_setting.dart`：
  ```dart
  class GlobalProxySetting {
    final bool enabled;
    final ProxyConfig? config;
    const GlobalProxySetting({this.enabled = false, this.config});
    GlobalProxySetting copyWith({...});
    static const disabled = GlobalProxySetting();
  }
  ```
- `lib/features/settings/domain/repositories/global_proxy_repository.dart`：
  接口（getCurrent / save）。
- `lib/features/settings/data/datasources/global_proxy_local_datasource.dart`：
  Hive box（`network_proxy`，复用 settings box 也行——选定后写明）。
- `lib/features/settings/data/repositories/global_proxy_repository_impl.dart`。
- 暂不创建 Riverpod notifier（留给 S4）；只提供 datasource provider 给
  下层使用。

### R6: 备份 / 恢复 schema

- 找到现有 backup 序列化代码（多半在
  `lib/features/backup/data/...`），追加：
  - account 备份：透传新增字段
  - settings 备份：新增 `globalProxy` 顶级字段
- 旧版本备份导入：缺失字段自动回退默认（保持向后兼容）。
- 备份 schema 若有 `version` 字段，bump +1 并在 PRD/Code 注释中记录。

### R7: Hive 初始化

- 若使用新 box，需在 `initHive()` 里 `await Hive.openBox('network_proxy')`。
- 不引入 hive 类型适配器（保持 Map 序列化习惯，与现有模式一致）。

## Acceptance Criteria

- [ ] `Account` 新字段默认值生效；`copyWith` / `deepEquals` 已覆盖
- [ ] `AccountMapper.fromMap(toMap(a)) == a` 字段全等
- [ ] 旧 hive 记录（无 `proxyMode` 字段）能正常读取，回退默认值
- [ ] `GlobalProxyRepository` save/get 闭环工作（dart 层手测或单测）
- [ ] 备份导出 → 解析 json，能看到 `proxyMode` / `proxyConfig` /
      `globalProxy` 字段
- [ ] 备份恢复：旧版本备份不报错，缺失字段回退默认
- [ ] `flutter analyze` 0 警告
- [ ] `dart format .` 已应用

## Out of Scope

- 不写 Riverpod UI provider（S4 负责）
- 不改 `core/network/` 任何文件（S2 负责）
- 不写 UI

## Files to Touch

**新增：**
- `lib/core/network/proxy_config.dart`
- `lib/features/settings/domain/entities/global_proxy_setting.dart`
- `lib/features/settings/domain/repositories/global_proxy_repository.dart`
- `lib/features/settings/data/datasources/global_proxy_local_datasource.dart`
- `lib/features/settings/data/repositories/global_proxy_repository_impl.dart`

**修改：**
- `lib/features/accounts/domain/entities/account.dart`
- `lib/features/accounts/data/models/account_mapper.dart`
- `lib/features/backup/...`（具体路径在实现时定位）
- `lib/main.dart` 或 hive 初始化处（若新建 box）

## Definition of Done

- 全部新增/修改文件通过 analyze + format
- 主任务父级 PRD 的 R1 + R7 + R8 在数据层视角下完成
- 留给 S2 的接口稳定（ProxyConfig + GlobalProxySetting + Account 字段）
