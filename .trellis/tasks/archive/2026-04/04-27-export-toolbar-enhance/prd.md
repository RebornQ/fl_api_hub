# 密钥列表导出工具栏增强

## Goal

增强密钥管理页面底部导出工具栏的功能：支持横向滚动、选中密钥时才显示、导出弹窗支持渠道类型选择、导出工具按系统平台适配显示。

## What I already know

### 当前代码状态

- `keys_page.dart`: ConsumerStatefulWidget，有 `_selectedAccountId` 管理账号选中状态，**无密钥选中状态**
- `KeyExportBar`: 当前是 `bottomNavigationBar`，固定显示（有账号+有密钥时），包含 Claude Code 和 Cherry Studio 两个导出按钮
- 现有导出器: `claude_code_exporter.dart`、`cherry_studio_exporter.dart`，均为直接复制 JSON 到剪贴板
- `ApiKey` 实体: 有 `id`, `accountId`, `name`, `keyValue`, `quota`, `usedQuota`, `expiresAt` 等字段
- `Account` 实体: 有 `id`, `name`, `baseUrl` 等字段
- 当前 KeyExportBar 已支持 `SingleChildScrollView(scrollDirection: Axis.horizontal)`，横向滚动已实现

### CC-Switch Deeplink 协议

- 协议格式: `ccswitch://v1/import?resource=provider&app={app}&name={name}&endpoint={url}&apiKey={key}`
- `app` 参数: `claude` / `codex` / `gemini` / `opencode` / `openclaw`
- 渠道类型映射: OpenAI→(无直接app值, 需确认), Anthropic→`claude`, Gemini→`gemini`
- 支持 macOS、Windows、Linux

### Kelivo 分享字符串格式

- 数据: `{"type":"openai","name":"sitename","apiKey":"sk-xxx","baseUrl":"https://apisite.demo.com/v1"}`
- 导出格式: `ai-provider:v1:{base64(JSON)}`
- 支持 macOS、Windows、Linux、Android、iOS
- 暂无 Deeplink，复制到剪贴板

## Assumptions (temporary)

- "导出弹窗"中"名称默认获取账号名"指的是当前选中账号的 `name` 字段
- 密钥选中状态为单选（用户明确要求），存储在 keys_page 的 state 中
- 切换账号时需要清除密钥选中状态（用户明确要求）
- "系统平台没有支持的工具时显示空状态"是指工具栏区域显示空状态提示

## Open Questions

(全部已解决)

## Decision (ADR-lite)

**Context**: 需要确定渠道类型映射和旧导出器处理方式

**Decision**:
1. **渠道类型映射** — 各导出工具分别处理：
   - CC-Switch: OpenAI→`codex`, Anthropic→`claude`, Gemini→`gemini`
   - Kelivo: OpenAI→`openai`, Anthropic→`claude`, Gemini→`google`
2. **旧导出器** — 替换。删除 `claude_code_exporter.dart` 和 `cherry_studio_exporter.dart`，由 CC-Switch 和 Kelivo 完全替代

**Consequences**: 减少维护负担，工具栏只有 CC-Switch 和 Kelivo 两个工具

## Requirements

### R1: 导出工具栏横向滚动

- 工具栏中的导出工具（chip）支持横向滚动（当前已实现）
- 新增导出工具后工具数量增加，横向滚动更必要

### R2: 密钥选中状态与工具栏显隐

- 未选中密钥时，底部导出工具栏**隐藏**
- 单选选中任一密钥后，工具栏**显示**
- **不支持多选**
- 切换账号时，**取消选中密钥**（清除选中状态）
- 密钥卡片需要支持点击选中（视觉反馈：选中高亮）

### R3: 导出弹窗

- 点击工具栏中的导出工具（如 CC-Switch / Kelivo）时，弹出导出配置弹窗
- 弹窗内容：
  - **渠道类型**选择：OpenAI / Anthropic / Gemini（单选）
  - **名称**输入框：默认获取当前选中账号的 `name`
  - 确定/取消按钮
- 确定后执行对应的导出逻辑

### R4: 导出工具平台适配

- 每个导出工具存储一个支持的平台列表
- 根据当前运行平台过滤显示：
  - CC-Switch: 支持 macOS, Windows, Linux
  - Kelivo: 支持 macOS, Windows, Linux, Android, iOS
- 当前平台没有支持的工具时，工具栏区域显示**空状态**提示

### R5: CC-Switch 导出逻辑

- 使用 Deeplink: `ccswitch://v1/import?resource=provider&app={app}&name={name}&endpoint={url}&apiKey={key}`
- 导出弹窗确定后，通过 `launchUrl` 打开 Deeplink
- 渠道类型映射: OpenAI→`codex`, Anthropic→`claude`, Gemini→`gemini`

### R6: Kelivo 导出逻辑

- 格式: `ai-provider:v1:{base64(JSON)}`
- JSON 内容: `{"type":"{type}","name":"...","apiKey":"...","baseUrl":"..."}`
- 渠道类型映射: OpenAI→`openai`, Anthropic→`claude`, Gemini→`google`
- 导出弹窗确定后，复制到剪贴板

## Acceptance Criteria

- [ ] 导出工具栏中的工具支持横向滚动
- [ ] 未选中密钥时工具栏隐藏，选中一个密钥后显示
- [ ] 不支持多选密钥，只有单选行为
- [ ] 切换账号时，密钥选中状态被清除
- [ ] 点击导出工具时弹出配置弹窗
- [ ] 弹窗中渠道类型有 OpenAI/Anthropic/Gemini 三选一
- [ ] 弹窗中名称默认为当前账号名
- [ ] CC-Switch 导出通过 Deeplink 打开应用
- [ ] Kelivo 导出通过剪贴板复制分享字符串
- [ ] 工具栏根据当前平台过滤显示工具
- [ ] 当前平台无支持的工具时显示空状态

## Definition of Done

- `flutter analyze` 无 warning
- `flutter test` 全部通过
- 新增 widget 测试覆盖关键交互

## Out of Scope

- 多选密钥导出
- Cherry Studio / Claude Code 导出器（已决定替换删除）
- 导出历史记录
- 导入功能
- 其他导出工具的动态注册机制（当前硬编码两个工具）

## Technical Approach

### 架构设计

```
ExportTool (抽象模型)
├── name: String
├── icon: IconData
├── supportedPlatforms: List<TargetPlatform>
├── supportsCurrentPlatform: bool (getter)
├── export(ExportConfig): Future<void>
│
├── CCSwitchExportTool
│   └── uses launchUrl with ccswitch:// deeplink
│
└── KelivoExportTool
    └── copies ai-provider:v1:{base64} to clipboard

ExportConfig
├── channelType: ChannelType (openai/anthropic/gemini)
├── name: String
├── apiKey: String
├── baseUrl: String

ExportDialog
├── channelType selector (OpenAI/Anthropic/Gemini)
├── name TextField (default: account.name)
├── confirm → calls tool.export(config)
```

### 核心变更

**1. `keys_page.dart`** — 新增密钥选中状态 + 工具栏显隐
- 新增 `String? _selectedKeyId` state
- 切换账号时清除 `_selectedKeyId`
- 工具栏仅在 `_selectedKeyId != null` 时显示
- KeyCard 新增 `isSelected` / `onSelect` 回调

**2. `key_card.dart`** — 支持选中视觉反馈
- 新增 `isSelected` 和 `onSelect` 参数
- 选中时显示高亮边框/背景

**3. `key_export_bar.dart`** — 重构为平台适配 + 工具列表
- 接收 `ExportTool` 列表（而非硬编码按钮）
- 按当前平台过滤显示
- 空状态处理
- 点击工具 → 弹出 ExportDialog

**4. `export_dialog.dart`** — 新建导出配置弹窗
- 渠道类型选择器
- 名称输入框
- 确定/取消

**5. `export_tool.dart`** — 新建导出工具模型
- `ExportTool` 基类/接口
- `CCSwitchExportTool` 实现
- `KelivoExportTool` 实现

**6. 现有导出器** — 删除 `claude_code_exporter.dart` 和 `cherry_studio_exporter.dart`

### 改动文件清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `keys_page.dart` | 修改 | 新增选中状态、工具栏显隐、切换清除 |
| `key_card.dart` | 修改 | 新增选中视觉 |
| `key_export_bar.dart` | 重构 | 平台适配、工具列表、弹窗触发 |
| `export_dialog.dart` | 新建 | 导出配置弹窗 |
| `export_tool.dart` | 新建 | 导出工具抽象模型 |
| `cc_switch_exporter.dart` | 新建 | CC-Switch 导出实现 |
| `kelivo_exporter.dart` | 新建 | Kelivo 导出实现 |
| `claude_code_exporter.dart` | 删除 | 旧导出器，被 CC-Switch 替代 |
| `cherry_studio_exporter.dart` | 删除 | 旧导出器，被 Kelivo 替代 |
| `test/` | 修改 | 覆盖新交互 |

## Implementation Plan (batches)

### Batch 1: 密钥选中状态 + 工具栏显隐
> 依赖: 无

1. `keys_page.dart`: 新增 `_selectedKeyId` state
2. `key_card.dart`: 新增 `isSelected` / `onSelect`
3. `keys_page.dart`: 切换账号时清除选中
4. `keys_page.dart`: 工具栏在无选中时隐藏
5. 验证: 选中/取消选中/切换账号

### Batch 2: 导出工具模型 + 平台适配
> 依赖: 无（可与 Batch 1 并行开发）

1. `export_tool.dart`: `ExportTool` 抽象 + 平台过滤
2. `cc_switch_exporter.dart`: CC-Switch deeplink 导出
3. `kelivo_exporter.dart`: Kelivo base64 分享字符串导出
4. 单元测试

### Batch 3: 导出弹窗 + 工具栏重构
> 依赖: Batch 1 + Batch 2

1. `export_dialog.dart`: 渠道选择 + 名称输入
2. `key_export_bar.dart`: 重构为工具列表 + 平台过滤 + 空状态
3. 删除旧导出器: `claude_code_exporter.dart`、`cherry_studio_exporter.dart`
4. 串联: 选中密钥 → 点击工具 → 弹窗 → 导出
5. Widget 测试
