# feat: 账号刷新时同步签到状态判定优化

## Goal

账号列表项刷新账号状态时，要求刷新签到状态；签到状态的判定要求判断本地和 API 任一成功，不能只判断本地数据。

## Background

### 当前实现问题

1. **账号状态刷新不包含签到状态**
   - `AccountsNotifier._checkSingle()` 只调用 `fetchAccountInfo` 和 `fetchSiteStatus`
   - 并没有调用 `fetchCheckInStatus` API

2. **签到状态判定完全依赖本地数据**
   - `AccountCard._resolveCheckInIcon()` 只看 `latestResultByAccountProvider`
   - 如果 API 端已签到但本地没有记录（如手动在网页签到），会显示红色 cancel

3. **用户期望**
   - 刷新账号状态时，应该同步获取最新的签到状态
   - 签到成功判定：本地有今日成功记录 **或** API 返回今日已签到

## Requirements

### R1: 扩展 ReachabilityRecord 添加签到状态字段

- 在 `ReachabilityRecord` 中新增 `checkInStatusToday: bool?` 字段
- 存储从 API 获取的今日签到状态

### R2: 刷新账号状态时同步获取签到状态

- `AccountsNotifier._checkSingle()` 增加调用 `fetchCheckInStatus` API
- 获取当前月份的签到状态（`checkedInToday` 字段）
- 将签到状态存储到 `ReachabilityRecord.checkInStatusToday`

### R3: 签到状态判定逻辑优化

- 修改 `_resolveCheckInIcon()` 逻辑：
  - **本地有今日成功/已签到记录 → 绿色 check_circle**
  - **API 返回 `checkedInToday=true` → 绿色 check_circle**
  - **两者都无今日记录 → 红色 cancel**
- 图标样式保持一致，不区分来源

### R4: 批量刷新时同步签到状态

- `checkAll()` 刷新所有账号时，同时获取每个账号的签到状态
- 启动时 `checkAll()` 也刷新签到状态

## Technical Design

### 数据结构变更

```dart
// lib/core/network/reachability_status.dart
class ReachabilityRecord {
  final DateTime timestamp;
  final ReachabilityStatus status;
  final FailureCategory? failureCategory;
  final bool? checkInStatusToday;  // 新增：今日签到状态

  const ReachabilityRecord({
    required this.timestamp,
    required this.status,
    this.failureCategory,
    this.checkInStatusToday,  // 新增
  });

  // 工厂方法更新
  factory ReachabilityRecord.ok(DateTime t, {bool? checkInStatusToday}) =>
      ReachabilityRecord(timestamp: t, status: ReachabilityStatus.ok, checkInStatusToday: checkInStatusToday);

  factory ReachabilityRecord.fail(DateTime t, FailureCategory c) =>
      ReachabilityRecord(timestamp: t, status: ReachabilityStatus.fail, failureCategory: c);
}
```

### API 调用流程

```
_checkSingle(account)
  ├── fetchAccountInfo() → 用户信息、余额
  ├── fetchSiteStatus() → 站点状态
  └── fetchCheckInStatus(month=当前月份) → 今日签到状态
       ↓
  ReachabilityRecord.put(accountId, record.withCheckInStatus(checkedInToday))
```

### 签到状态判定逻辑

```dart
// account_card.dart
({IconData icon, Color color})? _resolveCheckInIcon({
  required bool autoCheckInEnabled,
  required CheckInResult? latestResult,
  required bool? apiCheckInStatusToday,  // 新增参数
}) {
  if (!autoCheckInEnabled) return null;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // 本地有今日成功签到记录
  if (latestResult != null) {
    final resultDate = DateTime(
      latestResult.executedAt.year,
      latestResult.executedAt.month,
      latestResult.executedAt.day,
    );
    if (resultDate == today &&
        (latestResult.status == CheckInStatus.success ||
         latestResult.status == CheckInStatus.alreadyChecked)) {
      return (icon: Icons.check_circle, color: const Color(0xFF10B981));
    }
  }

  // API 返回今日已签到
  if (apiCheckInStatusToday == true) {
    return (icon: Icons.check_circle, color: const Color(0xFF10B981));
  }

  // 无今日签到记录
  return (icon: Icons.cancel, color: const Color(0xFFEF4444));
}
```

## Files to Modify

| 文件 | 改动说明 |
|------|----------|
| `lib/core/network/reachability_status.dart` | 扩展 `ReachabilityRecord` 添加 `checkInStatusToday` 字段 |
| `lib/features/accounts/presentation/providers/accounts_notifier.dart` | `_checkSingle()` 增加调用 `fetchCheckInStatus` |
| `lib/features/accounts/presentation/widgets/account_card.dart` | `_resolveCheckInIcon()` 增加对 API 签到状态的判定，需要 watch reachability provider |
| `lib/features/accounts/presentation/providers/account_reachability_providers.dart` | 更新 `put` 方法支持新字段 |

## Acceptance Criteria

- [ ] 点击「刷新状态」按钮后，账号卡片的签到图标正确反映最新状态
- [ ] 启动 App 时自动刷新所有账号签到状态
- [ ] 在网页端手动签到后，App 内刷新账号状态能看到签到成功（绿色 check_circle）
- [ ] 本地有今日签到记录时显示绿色 check_circle
- [ ] API 返回 `checkedInToday=true` 时显示绿色 check_circle
- [ ] 两者都无今日记录时显示红色 cancel
- [ ] `flutter analyze` 无错误
- [ ] `flutter test` 全部通过

## Out of Scope

- 不修改签到执行逻辑（`CheckInNotifier.executeCheckIn`）
- 不修改签到历史记录存储
- 不涉及签到页面的改动
- 不区分本地签到和 API 签到的图标样式

## Dependencies

- 现有 `fetchCheckInStatus` API 已实现
- 现有 `ReachabilityRecord` 缓存机制
- `CheckInStatusDto.checkedInToday` 字段

## Risks

- 启动时批量刷新签到状态可能增加启动耗时（每个账号一次 API 调用）
- 可通过批量并行请求优化
