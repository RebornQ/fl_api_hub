# GitHub Actions CI 构建

## Goal

为 fl_api_hub Flutter 项目建立 GitHub Actions CI/CD 工作流，实现自动化构建和发布。

## What I already know

**项目信息：**
- Flutter SDK 版本：`^3.10.4`
- 项目名称：`fl_api_hub`
- Application ID: `com.mallotec.reb.flapihub`
- 已有 Android 签名配置（`key.properties`）
- 支持 Android 和 iOS 平台

**用户选择：** MVP 阶段支持 **全平台构建**（Android、iOS、macOS、Windows）

**参考项目 fluxdo 的 workflow 特点：**
- 触发条件：推送 `v*` 格式的 tag
- 构建矩阵：Android (arm64-v8a, armeabi-v7a, x86_64)、iOS、macOS、Windows
- 环境变量：`IS_STABLE` 判断是否稳定版
- 包含 Telegram 通知、GitHub Release、AltStore source.json 更新等功能

**当前项目状态：**
- `.github/workflows/` 目录不存在
- Android 使用 Kotlin DSL (`build.gradle.kts`)
- 已配置 release 签名

## Decisions Made

1. **目标平台**：全平台（Android、iOS、macOS、Windows）
2. **触发条件**：仅 tag 推送（v*）
3. **发布流程**：自动发布到 GitHub Releases
4. **iOS 签名**：构建未签名版本（测试用）

## Open Questions

1. **目标平台范围**：✅ **已确定** - 全平台（Android、iOS、macOS、Windows）
2. **触发条件**：✅ **已确定** - 仅 tag 推送（v*）
3. **发布流程**：✅ **已确定** - 自动发布到 GitHub Releases
4. **iOS 签名**：✅ **已确定** - 构建未签名版本

## Requirements (evolving)

- 创建 `.github/workflows/build.yaml` 文件
- 配置 Flutter 构建环境（使用官方 flutter-action）
- **全平台构建**：
  - Android APK（arm64-v8a, armeabi-v7a, x86_64）- 签名版本
  - iOS IPA（未签名，用于测试）
  - macOS app（未签名或 ad-hoc 签名）
  - Windows exe
- 配置 Android 签名（使用 GitHub Secrets）
- 构建矩阵支持多 ABI
- 自动创建 GitHub Release 并上传构建产物

## Acceptance Criteria (evolving)

- [ ] 推送 `v*` tag 后自动触发 CI
- [ ] 成功构建 Android APK（三个 ABI）
- [ ] 成功构建 iOS 未签名版本
- [ ] 成功构建 macOS app
- [ ] 成功构建 Windows exe
- [ ] 自动创建 GitHub Release
- [ ] 所有构建产物上传到 Release

## Definition of Done (team quality bar)

- Workflow 文件语法正确，能被 GitHub 识别
- 构建流程在 GitHub Actions 中成功运行
- 签名配置正确，APK 可安装

## Out of Scope (explicit)

- Linux Flatpak 构建（fluxdo 特有的 Flatpak 流程）
- 自动发布到应用商店（Google Play / App Store）
- Telegram 通知（除非用户明确需要）
- AltStore source.json 更新（fluxdo 特有功能）
- Changelog 自动生成（除非用户明确需要）

## Technical Notes

**参考文件：**
- `pubspec.yaml` - Flutter SDK 版本 `^3.10.4`
- `android/app/build.gradle.kts` - Android 配置，Java 17，签名配置
- `android/key.properties` - 本地签名配置（不应提交到 git）

**GitHub Actions 环境要求：**
- Flutter SDK
- Java 17
- Android SDK / NDK
- 签名密钥（通过 Secrets 配置）

**参考 workflow：**
- https://github.com/Lingyan000/fluxdo/blob/main/.github/workflows/build.yaml

## Technical Approach

**关键技术选型：**
- 使用 `subosito/flutter-action@v2` 配置 Flutter 环境
- 使用构建矩阵（matrix）并行构建多平台，节省时间
- Android 签名通过 GitHub Secrets 配置（Base64 编码 keystore）
- 使用 `softprops/action-gh-release@v2` 创建 Release
- iOS 构建使用 `--no-codesign` 生成未签名版本

**构建矩阵：**
| OS | Target | Architecture | Output |
|----|--------|--------------|--------|
| ubuntu-latest | android | arm64-v8a | APK |
| ubuntu-latest | android | armeabi-v7a | APK |
| ubuntu-latest | android | x86_64 | APK |
| macos-latest | ios | - | IPA (unsigned) |
| macos-latest | macos | arm64 | DMG |
| macos-13 | macos | x86_64 | DMG |
| windows-latest | windows | x64 | ZIP |

**需要配置的 GitHub Secrets：**
- `ANDROID_KEYSTORE_BASE64` - Base64 编码的 keystore 文件
- `ANDROID_KEY_ALIAS` - 密钥别名
- `ANDROID_KEY_PASSWORD` - 密钥密码
- `ANDROID_STORE_PASSWORD` - 存储密码
