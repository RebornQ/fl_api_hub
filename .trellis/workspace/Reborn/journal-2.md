# Journal - Reborn (Part 2)

> Continuation from `journal-1.md` (archived at ~2000 lines)
> Started: 2026-04-23

---



## Session 25: Fix check-in already-checked-in handling

**Date**: 2026-04-23
**Task**: Fix check-in already-checked-in handling
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

## 问题描述

New-API 签到接口存在两个问题：
1. "已签到"场景显示为失败 - New-API 返回 `success: false` 导致被错误处理为 Failure
2. "已签到"计入跳过计数 - 应该计入成功计数

## 解决方案

### 1. Adapter 层重写 checkIn 方法
- `CommonApiAdapter.checkIn` 和 `VeloeraApiAdapter.checkIn` 不再使用 `performRequest`
- 直接解析 `CheckInResultDto`，只要 HTTP 200 就返回 Success
- 委托 `CheckInApiMapper` 判断实际状态

### 2. DTO 结构重构
- 新增 `CheckInDataDto` 用于嵌套数据（checkin_date, quota_awarded）
- 重构 `CheckInResultDto` 匹配 New-API 响应结构（success + message + data）

### 3. 状态扩展
- 新增 `CheckInStatus.alreadyChecked` 枚举值
- 更新 `CheckInApiMapper.inferStatus()` 状态推断逻辑
- UI 显示紫色"已签到"徽章

### 4. 统计修复
- `AccountCheckInStats` 将 `alreadyChecked` 计入成功计数

## 状态映射

| 条件 | 状态 | UI 显示 | 统计计数 |
|------|------|---------|----------|
| success=true | success | 绿色"成功" | Success |
| success=false + "已签到" | alreadyChecked | 紫色"已签到" | Success |
| success=false + 其他 | failed | 红色"失败" | Failed |
| 账号禁用/无userId | skipped | 紫色"已跳过" | Skipped |

## 修改文件

**新增文件（3）：**
- `lib/core/network/dto/check_in_data_dto.dart` - 嵌套 DTO
- `test/core/network/adapters/common_api_adapter_test.dart` - Adapter 测试
- `input/specs/New-API 的签到响应处理.md` - 问题规格文档

**修改文件（14）：**
- `lib/core/network/adapters/common_api_adapter.dart` - 重写 checkIn
- `lib/core/network/adapters/veloera_api_adapter.dart` - 重写 checkIn
- `lib/core/network/dto/check_in_result_dto.dart` - 重构结构
- `lib/features/check_in/data/models/check_in_api_mapper.dart` - 更新状态推断
- `lib/features/check_in/domain/entities/check_in_result.dart` - 新增字段和枚举
- `lib/features/check_in/presentation/providers/account_check_in_history_notifier.dart` - 修复统计
- `lib/features/check_in/presentation/widgets/check_in_result_card.dart` - 支持新状态
- `lib/features/check_in/presentation/widgets/check_in_status_badge.dart` - 支持新状态
- `test/core/network/dto/check_in_result_dto_test.dart` - 更新测试
- `test/features/check_in/data/models/check_in_api_mapper_test.dart` - 更新测试
- `test/core/network/adapters/veloera_api_adapter_test.dart` - 更新测试
- `test/features/check_in/presentation/providers/check_in_notifier_userid_test.dart` - 修复测试
- `.trellis/spec/backend/directory-structure.md` - 文档化特殊处理

## 测试结果

- ✅ 26/26 测试通过
- ✅ 静态分析无错误
- ✅ 代码格式化完成

## 文档更新

在 `.trellis/spec/backend/directory-structure.md` 新增专门章节：
- 问题描述（为什么需要特殊处理）
- 解决方案（如何实现）
- 状态映射表（完整的映射规则）
- 实现细节（代码示例）
- 测试说明（测试场景）


### Git Commits

| Hash | Message |
|------|---------|
| `71068c0` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete
