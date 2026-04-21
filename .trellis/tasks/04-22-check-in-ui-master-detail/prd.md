# Batch 2: Check-In UI Refactor (Master-Detail + Paginated History)

> 依赖 Batch 1（`check-in-data-layer-cap`）提供的 repository 新接口。Batch 1 合入后再执行本批次。

---

## 背景

Batch 1 完成数据层：每账号 50 条上限 + 分页查询 + 启动迁移。本批次落地产品形态：把签到主列表从"全部结果按时间倒序"改为"每个账号只展示最新一次"，并为单账号历史提供专属详情页（无限滚动 + 统计摘要 + 一键清空）。响应式布局兼顾宽屏双列和手机端推页。

## 业务需求

1. **主列表按账号聚合**：每个账号一张卡，内容保留现有 `CheckInResultCard` 外观（账号名、状态、消息、时间）；未签到过的账号不出现在列表；账号被删但仍有历史结果（孤儿记录）也跳过不显示。
2. **筛选/搜索口径一致**：`CheckInFilterBar` 的状态 chip 计数和搜索都作用于"每账号最新一次"集合，与主列表所见即所得。
3. **详情页纯列表**：不提供二次筛选，newest-first 排序，20 条/页，`ScrollController` 监听触底 200px 触发加载下一页；加载中显示 spinner，加载完显示"— 没有更多 —"。
4. **顶部统计摘要卡片**：展示该账号的总次数、成功/失败/跳过计数、最近一次签到时间。
5. **一键清空该账号所有记录**：AppBar 尾部按钮，点击弹二次确认 Dialog，确认后调用 `deleteAllResultsByAccountId` → 主列表 `latestResultPerAccountProvider` invalidate → 手机端 `Navigator.maybePop`，宽屏把 `selectedAccountIdProvider` 置 null 回空态。
6. **响应式导航**：
   - 宽屏 ≥ 900px：master-detail 双列，左列主列表，右列详情；初始右列空态占位。
   - 窄屏：`Navigator.push` 推入 `CheckInAccountDetailPage`。
7. **Execute-all 同步刷新**：主列表 FAB "执行全部" 触发后，master 列表刷新；若详情正打开也同步刷新（通过 `ref.listen` 监听 master provider 变动）。

## UI / 交互细节

- 保留 Summary Card + Stats Grid 作为 sidebar（宽屏左列）/ 顶部（窄屏）。
- `CheckInFilterBar` 传入的 `totalCount/success/failed/skipped` 改为从"最新一次"集合现算（非全量统计）。
- 详情页 AppBar 标题："签到记录"（或"<账号名>"）。
- 摘要卡片风格与 `CheckInSummaryCard` 保持一致（MD3 surface container + rounded-lg + outline variant border）。
- 详情页点击"清空"→ 二次确认 Dialog "确定清空 <账号名> 的全部签到记录吗？此操作不可恢复"。

## 技术约束

- **不引入 GoRouter**，继续使用 `Navigator.push(MaterialPageRoute(...))`。
- **保留现有 providers 的对外 symbol**（`checkInDashboardProvider` 打 `@Deprecated`，不删），避免现有依赖/测试大面积崩。
- **宽屏选中状态使用全局 `StateProvider`**：`selectedAccountIdProvider` 放在 `check_in_providers.dart`，避免 `LayoutBuilder` 重建丢失。
- **`CheckInResultCard` API 不改**：详情页每行外包 `CheckInResultDisplay(result, accountName)` 即可复用。
- **`CheckInNotifier` 内 invalidate 调用统一切到新 provider**：`allCheckInResultsProvider` → `latestResultPerAccountProvider`；同时处理 `executeAll` / `executeAllDue` / `executeCheckIn` 内部的 `_refreshTasks` 路径。
- **`checkInStatsProvider`** 依赖源从 `allCheckInResultsProvider` 切到 `latestResultPerAccountProvider`，口径和主列表一致。

## 交付范围

### 新增文件

| 文件 | 说明 |
|---|---|
| `lib/features/check_in/presentation/providers/account_check_in_history_notifier.dart` | `AccountCheckInHistoryNotifier`（family）+ `AccountCheckInHistoryState` + `accountCheckInHistoryProvider` + `accountCheckInStatsProvider`（family）+ `AccountCheckInStats` + 常量 `kCheckInDetailPageSize = 20` |
| `lib/features/check_in/presentation/pages/check_in_account_detail_page.dart` | 窄屏用 `Scaffold` 壳，body 委托给 `CheckInDetailView` |
| `lib/features/check_in/presentation/widgets/check_in_detail_view.dart` | 共享详情视图（宽屏右栏 + 窄屏 Scaffold 共用）：摘要卡 + 清空按钮 + 分页列表 |
| `lib/features/check_in/presentation/widgets/account_check_in_summary_card.dart` | 单账号统计摘要卡（总次数/成功/失败/跳过/最近时间） |

### 修改文件

| 文件 | 修改要点 |
|---|---|
| `lib/features/check_in/presentation/providers/check_in_providers.dart` | 新增 `latestResultPerAccountProvider`、`checkInAccountSummariesProvider`、`selectedAccountIdProvider`；`checkInStatsProvider` 源切到新 provider；`checkInDashboardProvider` 加 `@Deprecated` |
| `lib/features/check_in/presentation/providers/check_in_notifier.dart` | `executeAll` / `executeAllDue` 的 `invalidate(allCheckInResultsProvider)` 改为 `invalidate(latestResultPerAccountProvider)` |
| `lib/features/check_in/presentation/pages/check_in_page.dart` | 主列表 provider 切换 + 点击跳转 + 宽屏右列替换为 `_CheckInDetailPanel` + filter counts 改用主列表派生 |

## 测试

| 测试文件 | 新增/扩展 | 覆盖 |
|---|---|---|
| `test/features/check_in/presentation/providers/account_check_in_history_notifier_test.dart` | 新增 | `build` 首屏、`loadMore` 追加、并发幂等、`clearAll` 删除+重置+invalidate |
| `test/features/check_in/presentation/widgets/check_in_detail_view_test.dart` | 新增 | 渲染摘要卡+列表、滚动到底触发 loadMore、清空确认 Dialog + `onCleared` 回调 |
| `test/features/check_in/presentation/pages/check_in_page_test.dart` | 新增 | 窄屏点行 push 详情页；宽屏点行写 `selectedAccountIdProvider`；主列表跳过零记录账号和孤儿记录 |
| `test/features/check_in/presentation/providers/check_in_dashboard_stats_test.dart` | 扩展 | 验证新口径（latest-per-account）下 stats 数字正确 |

测试阶段由 SubAgent（`subagent_type: general-purpose`）驱动执行：写测试 + 跑 `flutter test` + `dart analyze` 直到全绿。

## 验收标准

- [ ] `dart analyze` 零警告零错误
- [ ] 所有新增/扩展测试通过，原有测试不回归
- [ ] 手工验证清单：
  1. 种入某账号 60 条结果 → 重启 app → 主列表该账号出现 1 次，详情页最多 50 行
  2. 多账号含 1 个零记录账号 → 主列表不显示该账号
  3. 主列表 chip 过滤 + 账号名搜索正常工作
  4. 窄屏点卡 → push 详情页 → 返回
  5. 宽屏点卡 → 右侧显示详情
  6. 详情页滚动过 20 条触发加载；第 50 条后显示"— 没有更多 —"
  7. 详情"清空记录"→ 确认 → 手机 pop / 宽屏切空态 → 主列表该账号消失
  8. 主页 FAB"执行全部" → 主列表刷新；若详情打开也同步刷新

## 非目标

- 不引入 GoRouter
- 不改 `lib/app/router.dart`
- 不动 Batch 1 已落地的数据层代码
- 不扩展删除账号时联动清理孤儿结果（按 Plan 保留为可选后续工作）
