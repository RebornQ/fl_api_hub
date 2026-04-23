# UI: 签到状态徽章颜色 + 账号编辑表单优化

## Goal

1. 统一签到状态徽章配色：`alreadyChecked` 改为与 `success` 相同的绿色，`skipped` 改为黄色
2. 账号编辑表单启用开关移至站点信息 SectionCard 上方
3. 备注多行输入框 hint 文字顶部左对齐

## Deliverables

**Modify**: `lib/features/check_in/presentation/widgets/check_in_status_badge.dart`
- `alreadyChecked` 颜色：`Color(0xFFEDE9FE)`/`Color(0xFF6D28D9)` → `Color(0xFFD1FAE5)`/`Color(0xFF047857)`（与 success 相同绿色）
- `skipped` 颜色：`Color(0xFFEDE9FE)`/`Color(0xFF6D28D9)` → `Color(0xFFFEF3C7)`/`Color(0xFF92400E)`（黄色）

**Modify**: `lib/features/accounts/presentation/widgets/account_edit_form.dart`
- 将 `_buildSiteInfoFields()` 中的 `SwitchListTile`（L280-292）提取到 `build()` 方法，放在 `SectionCard(站点信息)` 之前
- `notesField` 添加 `textAlignVertical: TextAlignVertical.top`

## Verification

- `flutter analyze` clean
- 手动：签到结果卡片中 "成功" 和 "已签到" 显示绿色，"已跳过" 显示黄色
- 手动：账号编辑页启用开关在站点信息卡片上方
- 手动：备注输入框 hint 文字顶部左对齐

## Out of scope

- 用户 ID / 充值比例输入类型（已是正确类型，无需修改）
- CheckInOverallStatusBadge 颜色
