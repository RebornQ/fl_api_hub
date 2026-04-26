# Account Edit Form Improvements

## Goal

改善账号编辑表单体验：添加重复站点 URL 检测、临时隐藏 AnyRouter 站点类型、新增账号默认选择 New-API。

## Requirements

### 1. 重复站点 URL 检测

1. 用户在 URL 输入框停止输入 100ms 后，检查 URL 是否与已有账号重复
2. 用户离开 URL 输入框（焦点丢失）时，同样触发检查
3. URL 比较前做标准化（trim、去尾 `/`、忽略大小写）
4. 检测到重复时显示非阻塞警告：橙色边框 + 警告图标 + 标签变色 + 冲突账号名
5. 用户可忽略警告继续保存
6. 编辑模式下排除当前账号自身

### 2. 站点类型下拉调整

7. 下拉列表临时隐藏 `SiteType.anyrouter`
8. 已有 `anyrouter` 账号在编辑时仍保留该选项（避免 Flutter assertion 崩溃）
9. 新增账号时默认站点类型改为 `SiteType.newApi`（原为 `SiteType.unknown`）

## Acceptance Criteria

- [x] 输入重复 URL 后 100ms 显示橙色警告（边框、图标、标签、helperText）
- [x] 离开 URL 字段触发检查
- [x] 警告显示冲突账号名称
- [x] 编辑模式不警告自身 URL
- [x] 有警告时仍可保存
- [x] URL 标准化比较（去尾 `/`、大小写）
- [x] 站点类型下拉不显示 AnyRouter（编辑已有 AnyRouter 账号时除外）
- [x] 新增账号默认选中 New-API

## Technical Approach

**仅修改一个文件：** `lib/features/accounts/presentation/widgets/account_edit_form.dart`

### 重复检测实现

- 新增状态：`_urlFocusNode`, `_urlDebounce`, `_isDuplicateUrl`, `_duplicateUrlNames`
- `_normalizeUrl()` static 方法：trim → 去尾 `/` → lowercase
- `_checkDuplicateUrl()` 读取 `accountsProvider`，标准化比较 URL
- `_onUrlFocusChanged()` 焦点丢失时触发检查
- `onChanged` 回调使用 100ms `Timer` 防抖
- `_buildUrlDecoration()` 重复时返回橙色边框 + 警告图标 + label/helperText 变色

### 站点类型调整

- 默认值：`_siteType = a?.siteType ?? SiteType.newApi`
- 下拉过滤：`.where((t) => t != SiteType.anyrouter || _siteType == t)`

## Decision (ADR-lite)

**Context:** 重复 URL 警告样式选择
**Decision:** 橙色边框 + 警告图标（suffixIcon）+ 标签变色 + helperText（非阻塞，不使用 errorText）
**Consequences:** 用户仍可保存；视觉上区别于验证错误；遵循 MD3 主题

## Definition of Done

- [x] flutter analyze 零错误
- [x] 新增/编辑模式均正常工作
- [x] 无新增依赖

## Out of Scope

- 仓库层阻止重复 URL（未来可能添加）
- 存储层 URL 标准化
- 合并/去重已有重复账号
- 永久移除 AnyRouter 站点类型

## Technical Notes

- 修改文件：`lib/features/accounts/presentation/widgets/account_edit_form.dart`
- 防抖时间：100ms（参考搜索的 300ms，验证操作更短即可）
- 警告色：`colorScheme.error.withValues(alpha: 0.7)` 保持 MD3 主题一致性
