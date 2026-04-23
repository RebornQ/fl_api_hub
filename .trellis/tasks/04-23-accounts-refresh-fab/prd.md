1	# 账号刷新 FAB + 保存后可达性检测
2
3	## Goal
4
5	1. 将账号列表页的搜索 FAB 替换为刷新按钮，点击触发 `checkAll(force: true)`，带旋转动画反馈
6	2. 账号编辑保存后对已启用账号自动触发 `checkOne` 可达性检测，更新余额等实时数据
7
8	## Deliverables
9
10	**Modify**: `lib/features/accounts/presentation/pages/accounts_page.dart`
11	- 混入 `SingleTickerProviderStateMixin`
12	- 添加 `AnimationController _refreshController` + `bool _isRefreshing`
13	- 替换搜索 FAB：`Icons.search` → `Icons.refresh`，`heroTag` 改为 `'accounts_refresh'`
14	- `onPressed` → 调用 `_handleRefresh()`，触发 `checkAll(force: true)` 并驱动旋转动画
15	- `child` → `RotationTransition(turns: _refreshController, child: Icon(Icons.refresh))`
16	- 刷新期间禁用按钮（`onPressed: _isRefreshing ? null : _handleRefresh`）
17	- 空列表时静默处理
18
19	**Modify**: `lib/features/accounts/presentation/widgets/account_edit_form.dart`
20	- 放宽 `shouldRecheck` 条件：`account.enabled && (!_isEditing || !wasEnabledBefore)` → `account.enabled`
21	- 即：任何已启用账号保存后都触发 `checkOne`
22
23	## Verification
24
25	- `flutter analyze` clean
26	- 手动：点击刷新按钮 → 图标旋转 → 所有启用账号检测完成 → 图标停止
27	- 手动：编辑账号保存后 → 该账号自动触发可达性检测
28	- 手动：空列表点击刷新 → 静默无报错
29	- 手动：节流内再次点击刷新 → 仍然触发（force: true）
30
31	## Out of scope
32
33	- 签到页刷新按钮的旋转动画（仅改账号页）
34	- 批量刷新进度提示（SnackBar 等）
