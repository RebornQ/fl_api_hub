# Sticky Header + 备份密码二次确认

## Goal

改进签到列表和备份页面的 UX：签到列表上滑时固定分类标签和搜索框在顶部（sticky header），关闭备份加密时增加二次确认弹窗。

## Requirements

### R1: 签到列表 Sticky Header

- **现状**: `_buildMasterColumn` 使用 `SingleChildScrollView` 包裹 SummaryCard → StatsGrid → FilterBar → ResultList，所有内容随滚动一起移动。
- **目标**: 上滑时，FilterBar（分类标签 + 搜索框）固定在顶部不动，SummaryCard 和 StatsGrid 随滚动滚走，ResultList 在 FilterBar 下方继续滚动。
- **实现方案**: 将 `SingleChildScrollView` 改为 `Column` + `Expanded`，FilterBar 之前的区域用可滚动区域，FilterBar 固定在中间，ResultList 用 `Expanded` + `ListView.builder` 独立滚动。
- **宽屏/窄屏**: 两种布局都需要 sticky header 效果。
- **RefreshIndicator**: 需保留下拉刷新功能。

### R2: 备份密码关闭二次确认

- **现状**: `BackupPage._toggleEncryption` 中关闭加密时直接调用 `passwordStore.clearPassword()`，无任何确认。
- **目标**: 关闭备份加密前弹出确认对话框，用户确认后才清除密码；取消则保持不变。
- **对话框风格**: 与项目现有 `AlertDialog` 风格一致（参考 `_openBrowserForFailed` 中的对话框样式）。

## Acceptance Criteria

- [ ] 签到列表窄屏布局：上滑时 FilterBar 固定在顶部，SummaryCard/StatsGrid 滚走，列表继续滚动
- [ ] 签到列表宽屏布局（左栏）：同上效果
- [ ] 下拉刷新仍然正常工作
- [ ] 关闭备份加密时弹出确认 Dialog，确认后才清除密码
- [ ] 取消确认 Dialog 后加密状态不变
- [ ] `flutter analyze` 零警告
- [ ] 现有测试不回归

## Definition of Done

- Lint / typecheck / CI green
- 手工验证两个功能点

## Technical Approach

### R1: Sticky Header

将 `_buildMasterColumn` 从 `SingleChildScrollView(whole column)` 改为：

```
Column(
  children: [
    // 可滚动区域: SummaryCard + StatsGrid
    SingleChildScrollView(reverse: true) 或 shrink-wrap
    // 固定区域: FilterBar
    FilterBar (不滚动)
    // 独立滚动列表: ResultList
    Expanded(
      child: RefreshIndicator(
        child: ListView.builder(...)
      )
    )
  ]
)
```

具体方案：使用 `NestedScrollView` 或简单的 `Column` 拆分。考虑到 RefreshIndicator 需要一个可滚动子组件，最佳方案：

1. 整体使用 `CustomScrollView` + `SliverToBoxAdapter` + `SliverAppBar(pinned: true)` 或 `SliverPersistentHeader`
2. SummaryCard + StatsGrid 放在普通 Sliver 中
3. FilterBar 作为 pinned SliverPersistentHeader
4. ResultList 作为 SliverList

但考虑到 RefreshIndicator 兼容性，更稳妥的方案：

```
Column(
  children: [
    // 上半部分：可滚动的 summary + stats
    Flexible(
      child: SingleChildScrollView(child: Column([SummaryCard, StatsGrid]))
    ),
    // 固定的 FilterBar
    FilterBar,
    // 下半部分：可滚动的 result list（带 RefreshIndicator）
    Expanded(
      child: RefreshIndicator(child: ListView.builder(...))
    )
  ]
)
```

**推荐方案**: 使用 `CustomScrollView` + `SliverAppBar(pinned: true, flexibleSpace: FilterBar)`，这是 Flutter 官方推荐的 sticky header 方案，且 RefreshIndicator 可以包裹整个 CustomScrollView。

### R2: 二次确认

在 `_toggleEncryption` 的 `else` 分支中加入 `showDialog<bool>` 确认：

```dart
final confirmed = await showDialog<bool>(
  context: context,
  builder: (ctx) => AlertDialog(
    title: const Text('关闭备份加密'),
    content: const Text('关闭加密后，新创建的备份文件将不包含密码保护。确定要关闭吗？'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('取消')),
      FilledButton.tonal(onPressed: () => Navigator.pop(ctx, true), child: Text('确认')),
    ],
  ),
);
if (confirmed != true) return;
```

## Out of Scope

- 不修改 FilterBar 组件本身
- 不引入新的第三方库
- 不改动备份加密的数据层逻辑

## Technical Notes

- 关键文件: `check_in_page.dart` (L256-307 `_buildMasterColumn` 方法)
- 关键文件: `backup_page.dart` (L197-217 `_toggleEncryption` 方法)
- FilterBar: `check_in_filter_bar.dart`
- 设计规范: `design_tokens.dart` (AppSpacing, AppRadius)
