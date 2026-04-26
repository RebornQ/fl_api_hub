# 完善密钥管理页面

## Goal

将现有密钥管理从"纯本地 CRUD"升级为"远程 API 联动 + 本地缓存 + 外部工具导出 + Sub2API 适配"的完整功能。

## Decision (ADR-lite)

**Context**: 现有 KeysRepositoryImpl 纯本地存储，密钥创建/编辑/删除不同步到服务器，无法拉取服务器密钥列表。
**Decision**:
1. 采用"远程优先 + 本地缓存"架构 — 与账号刷新模式一致
2. 导出优先支持 Claude Code + Cherry Studio
3. 补充 Sub2API 密钥管理适配（不同端点和信封格式）
**Consequences**: 需重构 Repository 层、扩展 SiteAdapter 接口、新增导出格式化器。

## Requirements

### P0 — 远程 API 联动
1. KeysRepository 重构为远程优先：创建/编辑/删除 → 调远程 API → 成功后更新本地缓存
2. 打开密钥页面时从服务器拉取最新密钥列表并缓存
3. 密钥值远程解析：key 为掩码时 → 调用 `fetchTokenKey()` 获取完整值
4. 复制完整密钥到剪贴板（修复 KeyCard._copyKey 的假实现）
5. SiteAdapter 新增 `updateToken()` 方法（`PUT /api/token/`）
6. KeysRemoteDataSource 新增 `updateToken()` 方法

### P1 — 导出功能
7. 导出为 Claude Code 格式（JSON 配置文件：apiUrl + apiKey + model 列表）
8. 导出为 Cherry Studio 格式（OpenAI 兼容 provider 配置）
9. 导出 UI：密钥卡片添加"导出"按钮，底部导出栏

### P1 — 站点特化
10. Sub2API 密钥管理适配（`/api/v1/keys/*` 端点 + `{ code, message, data }` envelope）
11. Sub2ApiAdapter 实现 listTokens / createToken / deleteToken / updateToken

## Acceptance Criteria

- [ ] 选择账号后自动从服务器拉取该账号的密钥列表
- [ ] 创建密钥 → 服务器 API 成功创建 → 本地缓存更新
- [ ] 编辑密钥名称/额度 → 服务器 API 成功更新 → 本地缓存更新
- [ ] 删除密钥 → 服务器 API 成功删除 → 本地缓存更新
- [ ] 密钥值为掩码时点击"解析" → 调 fetchTokenKey 显示完整密钥
- [ ] 显示密钥后点击复制 → 完整密钥复制到剪贴板
- [ ] 离线时显示缓存的密钥数据，操作失败时显示错误提示
- [ ] 能将密钥导出为 Claude Code 配置格式
- [ ] 能将密钥导出为 Cherry Studio 配置格式
- [ ] Sub2API 站点的密钥 CRUD 正常工作

## Definition of Done

- Tests added/updated（Repository 单元测试、Notifier 单元测试、Widget 测试）
- `flutter analyze` 无 warning
- 离线/网络错误场景有优雅降级

## Out of Scope

- Octopus 密钥管理（其体系以渠道为主，不使用标准 token 接口）
- Kilo Code 导出（后续迭代）
- 密钥自动预配置（P2）
- 批量操作（P2）

## Technical Approach

### 架构变更

**1. Repository 层重构**

```
KeysRepositoryImpl (改造前):
  └─ KeysLocalDataSource only

KeysRepositoryImpl (改造后):
  ├─ KeysRemoteDataSource (远程 API)
  └─ KeysLocalDataSource (本地缓存)
  策略: 写操作 → 远程 API → 成功后写本地缓存
        读操作 → 远程 API → 成功后更新本地缓存
               → 失败时回退到本地缓存
```

Repository 需要接收 `Account` 信息来构建 `ApiRequest`（baseUrl, authToken, authType, userId）。

**2. SiteAdapter 扩展**

新增方法：
```dart
Future<Result<TokenDto>> updateToken(
  ApiRequest request, {
  required String tokenId,
  required String name,
  int? quota,
  DateTime? expiresAt,
});
```

**3. Sub2API 适配器**

创建 `Sub2ApiAdapter`（或扩展现有适配器），实现：
- `listTokens`: `GET /api/v1/keys?page={page}&page_size={size}`
- `createToken`: `POST /api/v1/keys`
- `updateToken`: `PUT /api/v1/keys/{id}`
- `deleteToken`: `DELETE /api/v1/keys/{id}`
- envelope: `{ code, message, data }` 而非 `{ success, message, data }`

**4. 导出格式化器**

新建 `lib/features/keys/data/export/`:
- `claude_code_exporter.dart` — Claude Code 配置格式
- `cherry_studio_exporter.dart` — Cherry Studio provider 格式

### 关键改动文件清单

**修改（按批次）：**
1. `lib/core/network/site_adapter.dart` — 新增 updateToken()
2. `lib/core/network/adapters/common_api_adapter.dart` — 实现 updateToken()
3. `lib/features/keys/data/datasources/keys_remote_datasource.dart` — 新增 updateToken()
4. `lib/features/keys/data/datasources/keys_local_datasource.dart` — 无变化（保持不变）
5. `lib/features/keys/data/repositories/keys_repository_impl.dart` — 重构为远程优先
6. `lib/features/keys/presentation/providers/keys_providers.dart` — 传入 Account context
7. `lib/features/keys/presentation/providers/keys_notifier.dart` — 适配新 Repository
8. `lib/features/keys/presentation/widgets/key_card.dart` — 修复复制 + 添加导出按钮
9. `lib/features/keys/presentation/widgets/key_value_row.dart` — 添加远程解析能力
10. `lib/features/keys/presentation/pages/keys_page.dart` — 加载时同步远程

**新增：**
11. `lib/features/keys/data/export/claude_code_exporter.dart`
12. `lib/features/keys/data/export/cherry_studio_exporter.dart`
13. `lib/core/network/adapters/sub2api_adapter.dart`（或扩展到现有文件）

## Implementation Plan (batches)

### Batch 1: 远程 API 基础（核心重构）
1. SiteAdapter 新增 `updateToken()` 接口 + CommonApiAdapter 实现
2. KeysRemoteDataSource 新增 `updateToken()`
3. KeysRepositoryImpl 重构为远程优先 + 本地缓存
4. KeysProviders 注入 Account context
5. KeysNotifier 适配新 Repository

### Batch 2: UI 完善
6. KeyValueRow 添加远程解析密钥功能
7. KeyCard 修复复制功能
8. KeysPage 加载时自动从服务器同步
9. 离线/错误状态处理

### Batch 3: 导出功能
10. Claude Code 导出格式化器
11. Cherry Studio 导出格式化器
12. 导出 UI 集成

### Batch 4: Sub2API 适配
13. Sub2ApiAdapter 密钥 CRUD
14. 接入 site_adapter_provider

## Technical Notes

### 关键文件
- `lib/features/keys/data/repositories/keys_repository_impl.dart` — 纯本地实现，需重构
- `lib/features/keys/data/datasources/keys_remote_datasource.dart` — 远程数据源
- `lib/core/network/site_adapter.dart` — 需添加 updateToken
- `lib/core/network/adapters/common_api_adapter.dart` — Common API 实现
- `lib/core/network/api_request.dart` — ApiRequest 结构
- `lib/features/accounts/domain/entities/account.dart` — Account 实体

### API 端点映射

| 操作 | Common endpoint | Sub2API endpoint | SiteAdapter 方法 |
|------|----------------|-------------------|-----------------|
| 列表 | `GET /api/token/?p=&size=` | `GET /api/v1/keys?page=&page_size=` | `listTokens()` |
| 创建 | `POST /api/token/` | `POST /api/v1/keys` | `createToken()` |
| 更新 | `PUT /api/token/` | `PUT /api/v1/keys/{id}` | `updateToken()` (新增) |
| 删除 | `DELETE /api/token/{id}` | `DELETE /api/v1/keys/{id}` | `deleteToken()` |
| 解析 | `POST /api/token/{id}/key` | N/A | `fetchTokenKey()` |

### PRD 参考
- PRD §3.4 密钥管理用户故事
- PRD §5.2.3 密钥管理页面布局
- PRD §5.1 功能清单
