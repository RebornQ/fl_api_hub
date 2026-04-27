# fix: 签到排序/呼吸效果/密钥置空三合一修复

## Goal

修复三个独立 bug：
1. 签到列表手动签到后顺序变动（账号不应置顶）
2. 账号列表更新信息时呼吸效果太微弱看不清
3. 删除密钥后选中状态未置空导致导出工具显示异常

## What I already know

### Bug 1: 签到排序
- `checkInAccountSummariesProvider` (L134-158) 按 `sortOrder` 排序逻辑已存在
- `getLatestResultPerAccount()` (local_datasource L149-163) 返回结果按 `executedAt DESC` 排序
- 手动签到后 `_performCheckIn` invalidate `latestResultPerAccountProvider`，触发重新计算
- 排序逻辑理论上应正确，需实际调试确认根因

### Bug 2: 呼吸效果
- `_StatusDot` (account_card.dart L177-262) 使用 `AnimationController(duration: 1200ms)`
- 当前参数: scale 0.85-1.15 (幅度 0.30), opacity 0.5-1.0 (幅度 0.5)
- 10px 的点 + 微弱幅度 → 视觉效果确实不明显
- 需增强幅度或增加辅助视觉反馈（颜色变化、光晕大小）

### Bug 3: 密钥删除后选中状态
- `keys_page.dart` L474-498: `_confirmDelete` 删除密钥后未清除 `_selectedKeyId`
- `KeyExportBar` 通过 `keys.valueOrNull?.firstWhere((k) => k.id == _selectedKeyId, orElse: ...)` 查找
- 删除后 `firstWhere` 走 `orElse` 创建空壳 `ApiKey`，导出工具拿到无效数据显示异常

## Requirements

### R1: 签到排序修复
- 手动签到后签到列表顺序必须与账号列表 `sortOrder` 一致
- 不得因签到操作改变任何账号的排列位置

### R2: 呼吸效果增强
- `_StatusDot` 检测中的动画幅度需明显增加，确保用户能清晰感知
- 不得影响性能（保持 `SingleTickerProviderStateMixin` 单控制器）

### R3: 密钥选中置空
- 删除密钥成功后 `_selectedKeyId` 必须置为 `null`
- 导出工具栏随之隐藏，不得显示无效数据

## Acceptance Criteria

- [ ] Bug1: 手动签到某账号后，签到列表中该账号保持原位不跳动
- [ ] Bug2: 账号检测中时状态点呼吸效果明显可辨（scale/opacity/color 至少一项显著增强）
- [ ] Bug3: 删除选中密钥后导出工具栏消失，无残留异常状态
- [ ] `flutter analyze` 零警告
- [ ] 相关测试通过

## Definition of Done

- 三个 bug 均修复并验证
- Lint / typecheck clean
- 无回归

## Technical Notes

### Bug 1 调查方向
- `checkInAccountSummariesProvider` 的 `whenData` 是否正确传递排序结果
- `AsyncValue` loading→data 切换时 UI 是否有闪烁或短暂乱序
- 是否需要改在 datasource 层就按 sortOrder 排序

### Bug 2 参数建议
- scale: 0.7 ↔ 1.3 (幅度从 0.30 提升到 0.60)
- opacity: 0.3 ↔ 1.0 (幅度从 0.5 提升到 0.7)
- duration: 1000ms (微加速)
- 可选: 增大光晕 blurRadius 或添加颜色脉动

### Bug 3 修复点
- `_confirmDelete` 成功后添加 `setState(() { _selectedKeyId = null; })`
