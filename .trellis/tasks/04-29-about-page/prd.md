# 关于页面

## Goal

新增一个"关于"页面，展示应用信息、开源许可和项目源码链接，帮助用户了解应用身份和合规信息。

## What I already know

* **应用名称**: Fl API HUB
* **当前版本**: 1.0.0+1 (来自 pubspec.yaml)
* **GitHub 仓库**: https://github.com/RebornQ/fl_api_hub
* **导航模式**: 使用 Navigator.push(MaterialPageRoute) 而非 GoRouter
* **设置页面入口**: 已存在 SettingsPage，使用 SectionCard 分组
* **应用图标位置**:
  - Android: `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.webp`
  - iOS: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
  - 源图标: `icons/icon-hub-1024-play-512.png`
* **UI 风格**: Material Design 3, 使用 SectionCard 分组、AppSpacing/AppRadius 设计令牌
* **已依赖 url_launcher**: 可用于打开 GitHub 链接

## Assumptions (temporary)

* 关于页面从设置页面进入（而非独立底部 Tab）
* 版本信息通过 `package_info_plus` 包获取（需要新增依赖）
* 开源许可使用 Flutter 内置的 `LicensePage` 或 `showLicensePage()` 方法

## Open Questions

(无待确认问题)

## Requirements (evolving)

* [x] 应用图标，水平居中显示
* [x] 应用名称: Fl API HUB
* [x] 版本名称 (如 1.0.0)
* [x] 第三方库开源许可列表
* [x] 项目 GitHub 源码链接: https://github.com/RebornQ/fl_api_hub
* [x] 从设置页面入口导航到关于页面

## Acceptance Criteria (evolving)

* [ ] 关于页面显示应用图标（居中、合适尺寸）
* [ ] 关于页面显示应用名称 "Fl API HUB"
* [ ] 关于页面显示当前版本号
* [ ] 关于页面提供开源许可列表查看入口
* [ ] 关于页面提供 GitHub 链接，点击可跳转

## Definition of Done

* 代码通过 `flutter analyze`
* 代码通过 `dart format .`
* 在 Android/iOS 平台测试通过
* UI 风格与现有设置页面一致

## Out of Scope (explicit)

* 自动检查更新功能
* 应用评分/反馈入口
* 隐私政策/用户协议链接

## Technical Notes

### 导航方式
使用 `Navigator.push(MaterialPageRoute(...))` 方式导航，与项目现有路由模式一致。

### 版本信息获取
推荐使用 `package_info_plus` 包获取应用版本：
- 版本名称: `PackageInfo.version` (如 "1.0.0")
- 构建号: `PackageInfo.buildNumber` (如 "1")

### 开源许可展示
使用 Flutter 内置 `showLicensePage(context)` 系统默认许可页面。

## Decision (ADR-lite)

**Context**: 需要展示第三方库开源许可列表
**Decision**: 使用系统默认 `showLicensePage()` 而非自定义页面
**Consequences**: 实现简单，与平台原生风格一致；不足是与应用自定义 MD3 风格不完全统一

### 相关文件
- 入口: `lib/features/settings/presentation/pages/settings_page.dart`
- UI 组件: `lib/core/widgets/section_card.dart`
- 设计令牌: `lib/app/theme/design_tokens.dart`
- 图标源: `icons/icon-hub-1024-play-512.png`