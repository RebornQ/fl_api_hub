# 签到失败项长按跳转内置浏览器手动签到

## Goal

在签到列表中，失败的签到结果项支持长按操作，弹出确认弹窗后跳转到内置浏览器打开对应站点，让用户可以手动完成签到。同时建立通用的内置浏览器服务层，供签到、兑换页等场景复用。

## Requirements

### 核心功能
* 签到失败的列表项长按触发操作
* 长按后弹出确认弹窗，显示站点 URL 信息
* 确认后跳转内置浏览器页面
* 内置浏览器支持基本浏览功能（加载、返回、前进）

### 通用浏览器服务
* 创建通用的浏览器服务层，封装平台判断逻辑
* 默认使用 `flutter_inappwebview`（内置浏览器）
- 不支持的平台回退到 `url_launcher`（系统浏览器），回退前提示用户
* 设置中提供开关"使用内置浏览器打开链接"，默认开启
* 关闭开关时直接使用系统浏览器

### 触发位置
* 签到主列表（CheckInPage）中的失败项
* 签到详情页（CheckInDetailView）中的失败项

### 边界处理
* URL 为空或无效时显示错误提示
* 仅 `failed` 状态的签到结果支持长按
* 其他状态（success/alreadyChecked/skipped）不受影响

## Acceptance Criteria

* [ ] 仅 failed 状态的签到结果项支持长按
* [ ] 长按弹出确认弹窗，包含站点 URL 信息
* [ ] 确认后跳转内置浏览器页面加载站点
* [ ] 内置浏览器页面有 AppBar 返回按钮
* [ ] 不支持 inappwebview 的平台回退 url_launcher 并提示
* [ ] 设置中有"使用内置浏览器打开链接"开关，默认开启
* [ ] 关闭开关后所有 URL 使用系统浏览器打开
* [ ] 其他状态的签到项无长按响应

## Definition of Done

* Lint / typecheck / CI green
* 签到成功/已签到/跳过的项不受影响
* 通用浏览器服务可被其他 feature 复用

## Out of Scope

* 自动填写签到表单
* 浏览器书签/历史功能
* Cookie/登录态持久化管理
* 兑换页（redemptionUrl）的浏览器集成（本次只搭好服务层，不集成兑换页）

## Technical Approach

### 依赖
* `flutter_inappwebview`: 内置 WebView 引擎
* `url_launcher`: 系统浏览器回退方案

### 新增文件

| 文件 | 说明 |
|------|------|
| `lib/core/browser/browser_service.dart` | 通用浏览器服务：平台判断、设置读取、打开 URL |
| `lib/core/browser/browser_page.dart` | 内置浏览器页面（InAppWebView + AppBar） |
| `lib/core/browser/platform_checker.dart` | 平台支持检查工具 |
| `lib/features/settings/presentation/widgets/browser_settings.dart` | 设置页中的浏览器开关 UI |
| `lib/features/check_in/presentation/widgets/check_in_result_long_press_dialog.dart` | 签到失败长按确认弹窗 |

### 修改文件

| 文件 | 修改要点 |
|------|----------|
| `pubspec.yaml` | 添加 flutter_inappwebview + url_launcher 依赖 |
| `CheckInResultCard` | 添加 `onLongPress` 回调参数 |
| `CheckInPage` | 对 failed 状态项传入 `onLongPress` 处理 |
| `CheckInDetailView` | 对 failed 状态项传入 `onLongPress` 处理 |
| Settings 相关 | 添加浏览器设置项 |

## Decision (ADR-lite)

**Context**: 需要内置浏览器支持签到失败后的手动操作，同时考虑多平台兼容性
**Decision**: 采用 flutter_inappwebview + url_launcher 双方案，通过通用浏览器服务层统一管理，设置中提供开关
**Consequences**: 需要额外引入两个依赖；Linux/Web 平台只能用系统浏览器；未来其他 URL 场景可直接复用服务层
