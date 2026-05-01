# 修复 CheckInStatusDto.fromJson 嵌套解析

## Goal

修复 `CheckInStatusDto.fromJson` 无法正确解析 New API 状态检查响应的 bug，使 `checkedInToday` 字段从嵌套的 `stats` 对象中正确提取。

## Problem

`CommonApiAdapter.fetchCheckInStatus()` 通过 `performRequest` → `ApiResponse.fromJson` 提取 `data` 字段后传给 `CheckInStatusDto.fromJson`。

当前 `fromJson` 在顶层查找 `checked_in_today`、`checked_days`、`total_reward`，但实际 API 响应结构是：

```json
{
  "enabled": true,
  "stats": {
    "checked_in_today": true,
    "records": [{"checkin_date": "2026-05-02", "quota_awarded": 1083226}],
    "total_quota": 500000
  }
}
```

结果：`checkedInToday` 永远为 `null`，账号列表签到状态图标对所有 Common 系站点失效。

## Files to Modify

| 文件 | 改动 |
|------|------|
| `lib/core/network/dto/check_in_status_dto.dart` | 修复 `fromJson` 从 `stats` 嵌套对象解析 |
| `test/core/network/dto/check_in_status_dto_test.dart` | 新增/更新测试覆盖 |

## Acceptance Criteria

- [ ] `CheckInStatusDto.fromJson` 正确从 `stats.checked_in_today` 读取
- [ ] `checkedDays` 从 `stats.records[].checkin_date` 提取日期中的 day 数
- [ ] `totalReward` 从 `stats.total_quota` 读取
- [ ] `flutter analyze` clean
- [ ] 现有测试通过
