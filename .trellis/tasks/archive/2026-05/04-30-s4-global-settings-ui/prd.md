# S4 · 全局设置 UI — Network Proxy Settings Page

> 父任务：`04-30-04-30-proxy-config`
> 依赖：S1（GlobalProxySetting + 仓储）+ S2（ProxyTestService）

## Goal

在 Settings 页新增「网络代理」入口；点击进入二级页面，提供启用开关、
代理字段编辑、连通性测试，全部更改持久化到 hive。

## Scope

- `lib/features/settings/presentation/`（新增 page + widget +
  notifier + provider）
- 不动 entity / repository（S1 已建好）

## Requirements

### R1: Settings 页面新增 tile

`lib/features/settings/presentation/pages/settings_page.dart`：
- 在合适位置（推荐：浏览器 tile 之后、关于 tile 之前）追加：
  ```dart
  ListTile(
    leading: const Icon(Icons.lan_outlined),
    title: const Text('网络代理'),
    subtitle: Text(_proxySummary),  // 例如 "已启用 · http://10.0.0.1:7890" / "未启用"
    trailing: const Icon(Icons.chevron_right),
    onTap: () => Navigator.push(...NetworkProxySettingsPage),
  )
  ```
- subtitle 实时反映 `globalProxyProvider` 状态。

### R2: NetworkProxySettingsPage

新建 `lib/features/settings/presentation/pages/network_proxy_settings_page.dart`：

页面结构：
- AppBar：「网络代理」+ 返回按钮 + 保存按钮（dirty 时高亮）
- Body：
  1. 「启用全局代理」`SwitchListTile`（绑定 `enabled`）
  2. SectionCard「代理服务器」：
     - `scheme` 下拉
     - `host` 文本（必填，校验同 S3）
     - `port` 数字字段（1-65535）
  3. SectionCard「认证（可选）」：
     - `username` / `password`（可见性切换）
  4. 「测试代理」按钮（FilledButton.tonal，居中）
- 底部：未保存时 PopScope 二次确认（复用 account 编辑页风格）

### R3: 启用开关行为

- 关闭 `enabled` 时：所有字段保持显示但**禁用**（避免误删配置）
- 开启 `enabled` 时但 host/port 未填：保存按钮禁用 + 提示
- 启用 + 配置有效时：保存后 followGlobal 账号下次请求即生效

### R4: 测试代理按钮

复用 S2 的 `ProxyTestService`：
- 默认目标 URL：`https://www.gstatic.com/generate_204`
- 表单内构造临时 `ProxyConfig`（不依赖保存）
- 反馈方式同 S3（SnackBar + 延迟显示）

### R5: Riverpod 三件套

`lib/features/settings/presentation/providers/global_proxy_providers.dart`：

```dart
final globalProxyRepositoryProvider = Provider<GlobalProxyRepository>((ref) {
  return GlobalProxyRepositoryImpl(
    ref.watch(globalProxyLocalDataSourceProvider),
  );
});

final globalProxyProvider =
    StateNotifierProvider<GlobalProxyNotifier, GlobalProxySetting>((ref) {
  return GlobalProxyNotifier(ref.watch(globalProxyRepositoryProvider));
});
```

`global_proxy_notifier.dart`：实现 load / setEnabled / saveConfig
方法，每次写入持久化。

### R6: Web 平台兜底

- 启用开关可切换；字段可填可保存（保留配置）
- 「测试代理」按钮替换为禁用状态 + 文案「Web 端代理由浏览器决定」

## Acceptance Criteria

- [ ] Settings 页可见「网络代理」tile，subtitle 实时反映启停状态
- [ ] 进入二级页面后开关 + 字段交互流畅，无卡顿
- [ ] 保存成功后回到 Settings：subtitle 立即更新
- [ ] PopScope 在 dirty 时弹出确认；放弃 / 取消两路径都正确
- [ ] 全局代理启用 + 一个 followGlobal 账号 → 触发刷新走代理（端到端
      验证，可能需要本地 proxy 工具如 mitmproxy / 代理服务器辅助）
- [ ] 全局代理关闭：followGlobal 账号自动直连
- [ ] 应用重启后配置保留（hive 持久化生效）
- [ ] `flutter analyze` 0 警告，`dart format .` 已应用

## Out of Scope

- 不实现「PAC 自动配置」/「系统代理读取」
- 不实现「代理黑白名单」
- 不动账号编辑 UI（S3）
- 不实现「云同步」全局代理

## Files to Touch

**新增：**
- `lib/features/settings/presentation/pages/network_proxy_settings_page.dart`
- `lib/features/settings/presentation/providers/global_proxy_providers.dart`
- `lib/features/settings/presentation/providers/global_proxy_notifier.dart`
- `lib/features/settings/presentation/widgets/network_proxy_settings.dart`（可选，按需提取）

**修改：**
- `lib/features/settings/presentation/pages/settings_page.dart`

## Definition of Done

- 父 PRD 的 R6 完成
- 视觉与现有 settings 风格统一
- 端到端：保存后立即影响 followGlobal 账号请求路径
- 应用重启后配置仍在
