# 优化动态莫奈取色分层设计感

## Goal

解决开启 Monet 动态取色后，组件颜色高度相似导致 UI 失去视觉层次感的问题。通过在动态色彩方案基础上注入分层对比度调整，确保在任何壁纸场景下都能保持清晰的视觉层次。

## What I already know

* 当前使用 `dynamic_color` 插件 (v1.7.0)，通过 `DynamicColorBuilder` 获取平台 Monet 色板
* `AppTheme.buildFromScheme(ColorScheme)` 统一处理静态/动态主题
* 动态取色仅做了 `.harmonized()` 处理，无任何自定义色调调整
* UI 组件大量使用 `surfaceContainer*` 系列令牌（Low/Lowest/High/Highest）做视觉分层
* Card 使用 `surfaceContainerLow`，导航栏使用 `surface`，搜索栏使用 `surfaceContainerHigh`
* 选中状态使用 `primaryContainer`，FAB 使用 `primary`
* 分隔线使用 `outlineVariant.withAlpha(40)`，可能导致边缘模糊
* 当前零 elevation 卡片策略加剧了扁平感

## Assumptions (temporary)

* 问题主要源于 Monet 生成的 tonal palette 在同一色相下 surface tokens 亮度差不足
* 某些壁纸（如偏单色、低饱和度壁纸）会加剧这个问题
* 不需要完全重写主题系统，而是在现有基础上做色调增强

## Open Questions

1. 分层增强策略：应使用哪种技术手段确保 surface tokens 有足够区分度？
2. 增强范围：仅影响 Monet 动态模式，还是同时优化静态主题？
3. 是否需要针对亮/暗模式分别调整？

## Requirements (evolving)

* 动态取色开启时，surface 系列令牌之间必须有可感知的亮度/色度差异
* 关闭动态取色时，现有静态主题不受影响（或同样获得轻微改善）
* 解决方案不能破坏 Material 3 的色彩语义
- 增强效果在亮色和暗色模式下都应有效

## Acceptance Criteria (evolving)

- [ ] Monet 开启状态下，Card 与背景有可区分的视觉边界
- [ ] Monet 开启状态下，选中/未选中状态有明确对比
- [ ] 分隔线/边框在 Monet 模式下可辨识
- [ ] 静态主题视觉表现不劣化
- [ ] `flutter analyze` 零错误

## Definition of Done

* Lint / typecheck / CI green
* 亮色/暗色模式分别测试多种壁纸场景
* 代码遵循现有架构模式

## Out of Scope (explicit)

* 不更改用户切换动态取色的 UI 流程
* 不引入新的主题引擎或替换 dynamic_color 插件
* 不修改 Design.md 中的品牌色定义

## Technical Notes

* 关键文件：
  * `lib/app/theme/app_theme.dart` — AppTheme 类，`buildFromScheme()` 方法
  * `lib/app/app.dart` — DynamicColorBuilder 集成
  * `lib/app/theme/design_tokens.dart` — 设计令牌常量
* 当前 surface token 用法分布：
  * `surface` — 导航栏
  * `surfaceContainerLow` — 卡片
  * `surfaceContainerLowest` — 启用的账号卡片、请求日志
  * `surfaceContainerHigh` — 搜索栏、筛选芯片
  * `surfaceContainerHighest` — 选中筛选芯片、导出工具栏
  * `primaryContainer` — 选中状态
* 动态取色管道：`DynamicColorBuilder → lightDynamic.harmonized() → AppTheme.buildFromScheme()`
