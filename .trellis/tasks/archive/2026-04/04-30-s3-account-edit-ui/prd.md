# S3 · 账号编辑 UI — Proxy SectionCard

> 父任务：`04-30-04-30-proxy-config`
> 依赖：S1（实体）+ S2（ProxyTestService）

## Goal

在账号编辑表单中新增「网络代理」SectionCard，支持账号级三态切换、
代理字段录入、连通性测试，并集成到现有 dirty 检测 / submit 流程。

## Scope

- 仅修改 `lib/features/accounts/presentation/`（widgets + 必要时
  providers）。
- 不动 entity / mapper / 仓储 / 网络层（前置 subtask 已完成）。

## Requirements

### R1: 折叠 SectionCard

新增 `lib/features/accounts/presentation/widgets/proxy_config_section.dart`：

- 标题：「网络代理」，icon `Icons.lan_outlined`
- **默认折叠**（`ExpansionTile` 或自定义点击切换）；折叠态展示一行
  摘要：`跟随全局` / `自定义：scheme://host:port` / `显式直连`
- 与现有 `SectionCard` 视觉一致（参考 `check_in_config_section.dart`
  实现风格）

### R2: 模式切换控件

`SegmentedButton<AccountProxyMode>`：
- `跟随全局`（followGlobal）
- `自定义`（custom）
- `显式直连`（direct）

切换时：
- `followGlobal` / `direct`：隐藏字段区
- `custom`：展开字段区 + 测试按钮

### R3: 代理字段（custom 模式）

字段排布（响应式 Row 拆分）：
1. `scheme` 下拉（http / https）+ `host` 文本（必填，去前后空格）
2. `port` 数字字段（1-65535，整数，validator）
3. `username` 文本字段（可空）
4. `password` 文本字段（可空，`obscureText: true` + 可见性切换图标）

校验：
- `host` 必填，且不允许包含 `://` 协议前缀（提示「不要带 http:// 前缀」）
- `port` int.tryParse → 范围检查
- `username` 与 `password` 必须同时为空或同时非空（任一非空时另一也必填）

### R4: 测试代理按钮

- 位置：字段区下方，靠右对齐
- 文案：「测试代理」
- 行为：
  - 收集当前表单输入构造一个临时 `ProxyConfig`（不保存账号）
  - 调用 `ProxyTestService.test(proxy: tempConfig, targetUrl: account.baseUrl)`
  - 加载中：按钮显示 spinner
  - 完成：底部 `SnackBar` 反馈
    - 成功：「✓ 代理可用，延迟 123ms」（不要带 emoji，用图标）
    - 失败：「× 代理测试失败：<reason>」
- Web 平台：按钮隐藏，文案改为「Web 端代理由浏览器决定」

### R5: 表单状态集成

`account_edit_form.dart` 改造：
- `_FormSnapshot` 新增 4 个字段：`proxyMode` + 4 个 proxy 字段
  （或一个嵌套 `ProxyConfig?` 对象）
- 控件：`_proxyHostController` / `_proxyPortController` /
  `_proxyUserController` / `_proxyPasswordController` + `_proxyMode` /
  `_proxyScheme`
- 在 `initState` 用 `widget.account?.proxyMode` /
  `account?.proxyConfig` 初始化
- `_buildAccountPayload()` 按当前模式构造最终 `proxyConfig`：
  - `direct` / `followGlobal` → `proxyConfig = null`
  - `custom` → 用控件值构造（trim host）

### R6: 在 form 中插入 SectionCard

`account_edit_form.dart` `build` 方法的 `Column.children` 中，在
「元数据」SectionCard 前后选一个合适位置插入「网络代理」SectionCard。
推荐在「认证凭据」之后、「签到配置」之前——逻辑相邻（都是连接性
配置）。

### R7: dirty 检测

- 改动任意 proxy 控件 → `_FormSnapshot` 不等 → `isDirty = true`
- `PopScope` 提示已自动覆盖

## Acceptance Criteria

- [ ] 添加新账号默认 `followGlobal`；表单首次渲染折叠
- [ ] 编辑现有账号：根据 `account.proxyMode` 初始化分段按钮位置
- [ ] 切换为 `custom` → 字段展开 → 录入合法值 → `isDirty = true`
- [ ] 切换为 `direct`：分段按钮变更也触发 `isDirty`
- [ ] 测试代理按钮：
  - host 留空时灰显 / 提示
  - 调用成功后展示延迟
  - 调用失败展示 reason
- [ ] 保存后再次进入编辑：所有字段还原一致
- [ ] 取消未保存编辑：PopScope 提示「放弃未保存的更改？」生效
- [ ] `flutter analyze` 0 警告，`dart format .` 已应用

## Out of Scope

- 不改全局设置 UI（S4）
- 不改实体 / mapper（S1）
- 不改网络层（S2）
- 不写代理字符串解析（host 字段拒绝带协议前缀，引导用户分字段填写）

## Files to Touch

**新增：**
- `lib/features/accounts/presentation/widgets/proxy_config_section.dart`

**修改：**
- `lib/features/accounts/presentation/widgets/account_edit_form.dart`

## Definition of Done

- 父 PRD 的 R5 完成
- 视觉与现有 SectionCard 风格统一（同样的圆角、间距、配色）
- 编辑流（新增 / 修改 / 取消 / 保存）四种路径均验证通过
