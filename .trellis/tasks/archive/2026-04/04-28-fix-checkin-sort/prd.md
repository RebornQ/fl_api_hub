# fix: 手动签到后签到列表顺序保持不变

## Goal

修复账号列表右划手动签到后，签到页面中刚签到的账号会置顶的 bug。签到列表应始终按账号列表 `sortOrder` 排序，不受签到操作影响。

## What I already know

- `checkInAccountSummariesProvider` (check_in_providers.dart L134-158) 已有 sortOrder 排序逻辑
- `getLatestResultPerAccount()` (check_in_local_datasource.dart L149-163) 返回数据按 executedAt DESC
- 手动签到通过 `_performCheckIn` (accounts_page.dart L700) 触发
- 签到后 invalidate `latestResultPerAccountProvider`，触发级联刷新

## Root Cause Hypothesis

`latestResultPerAccountProvider` 返回数据按 `executedAt DESC`，新签到的账号 executedAt 最新排在第一。虽然 `checkInAccountSummariesProvider` 有 re-sort 逻辑，但可能存在：
1. `AsyncValue` loading→data 状态切换时 UI 短暂展示未排序数据
2. 或者排序逻辑存在边界情况（如 sortOrder 相同时回退到原始顺序）

## Fix Strategy

在 `checkInAccountSummariesProvider` 的 sort 中加入 secondary sort key (accountId) 确保稳定排序，并确认 `whenData` 路径下排序始终生效。若排序逻辑本身无误，则需在 datasource 层直接按 sortOrder 排序（需 join accounts）。

## Acceptance Criteria

- [ ] 手动签到任意账号后，签到列表中该账号位置不变
- [ ] executeAll 批量签到后，列表顺序仍与账号列表一致

## Files

- `lib/features/check_in/presentation/providers/check_in_providers.dart` — 确认排序逻辑
- `lib/features/check_in/data/datasources/check_in_local_datasource.dart` — 可能需调整排序
