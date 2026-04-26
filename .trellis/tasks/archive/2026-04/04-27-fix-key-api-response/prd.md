# fix: 修复密钥管理 API 响应解析与文档不匹配的 bug

## Goal

对照 `docs/API 文档/Key.request.md`，修复密钥管理功能中所有 API **响应解析**的 bug。上一个任务（04-27-fix-key-api-bugs）已修复请求构建，但响应解析侧仍存在多个严重问题，导致创建/更新"假失败"、列表加载失败等。

## What I already know

### 代码审查发现的关键 Bug（按严重程度排序）

**P0 — 功能失效 / 假失败（Critical）**

1. **`ApiResponse.fromJson` 无法处理 `data` 为 `List` 的情况**
   - 文件：`lib/core/network/dto/api_response.dart:37-41`
   - 问题：`rawData is Map<String, dynamic>` 检查只处理 Map，不处理 List
   - 影响：Common API token 列表在返回直接数组格式（Format A）时**完全失败**
   - API 文档 Format A：`{"success": true, "data": [{...}, {...}], "message": ""}`
   - API 文档 Format B：`{"success": true, "data": {"items": [...], "total": N}, "message": ""}`
   - Format A 的 `data` 是 List → 解析为 null → `performRequest` 返回 Failure

2. **`performRequest` 将 `data: null` 视为失败**
   - 文件：`lib/core/network/adapters/common_api_adapter.dart:273`
   - 问题：`apiResponse.success && responseData != null` → 当 data 为 null 时返回 Failure
   - 影响：**Common API `createToken` 和 `updateToken` 永远返回 Failure**
   - API 文档明确：创建/更新成功响应为 `{"success": true, "message": "", "data": null}`
   - 用户看到的：创建/编辑密钥时永远提示"操作失败"，但实际已成功

3. **Sub2API `deleteToken` 不检查响应信封**
   - 文件：`lib/core/network/adapters/sub2api_adapter.dart:249-253`
   - 问题：直接 `await dio.delete(...)` 后返回 Success，不检查 `{code, message, data}` 信封
   - 影响：若服务器返回 HTTP 200 + `code: 1`（业务错误），会被误判为成功

4. **Common API `deleteToken` 不检查响应信封**
   - 文件：`lib/core/network/adapters/common_api_adapter.dart:166-184`
   - 问题：同上，不检查 `{success, message, data}` 信封
   - 影响：若服务器返回 HTTP 200 + `success: false`，会被误判为成功

**P1 — 数据质量（High）**

5. **Sub2API `quota` 为 string 时解析丢失**
   - 文件：`lib/core/network/dto/token_dto.dart:117-124`
   - 问题：`_parseQuota` 只处理 `num` 类型，不处理 string
   - API 文档：`quota?: number | string | null`
   - 影响：若 Sub2API 返回 `quota: "10.5"`，quota 会被解析为 null

6. **Sub2API `quota_used` 为 string 时解析丢失**
   - 同 Bug 5，`quota_used` 也可能是 string

**P2 — 信息丢失（Low）**

7. **Sub2API `status` 字符串映射过于简化**
   - "quota_exhausted" / "expired" → 都映射为 0（与 "inactive" 相同）
   - 用户无法区分"额度耗尽"和"已禁用"

## Assumptions (temporary)

- 修复应该集中在响应解析层（DTO + Adapter），不涉及 UI 层
- `performRequest` 的修改需要兼容所有使用它的端点
- `deleteToken` 的修复需要同时修改 Common 和 Sub2API 适配器

## Open Questions

(none — 全部问题已从代码审查中确认)

## Requirements

1. `ApiResponse.fromJson` 必须能处理 `data` 为 `List` 类型（Common API 直接数组格式）
2. `performRequest` 必须允许 `data: null` 的成功响应（create/update/delete）
3. Sub2API `deleteToken` 必须检查响应信封中的 `code` 字段
4. Common API `deleteToken` 必须检查响应信封中的 `success` 字段
5. `TokenDto._parseQuota` 必须处理 `quota` / `quota_used` 为 string 的情况

## Acceptance Criteria

- [ ] Common API token 列表在直接数组格式下能正确加载
- [ ] Common API 创建密钥成功后返回 Success（不再假失败）
- [ ] Common API 更新密钥成功后返回 Success（不再假失败）
- [ ] Sub2API 删除密钥时检查 `code` 字段，失败时返回 Failure
- [ ] Common API 删除密钥时检查 `success` 字段，失败时返回 Failure
- [ ] Sub2API 返回 `quota: "10.5"` 时能正确解析为内部单位（5250000）
- [ ] 所有现有测试通过，新增/更新相关测试
- [ ] `flutter analyze` 无 warning

## Definition of Done

- 所有 P0 和 P1 bug 已修复
- Tests added/updated
- `flutter analyze` 无 warning
- 响应解析逻辑与 API 文档完全对齐

## Out of Scope

- P2: Sub2API status 字符串精细化映射（后续迭代）
- 新增 model_limits / allow_ips / group 等字段到 TokenDto（P2）
- Octopus 通道管理响应解析
- UI 层修改

## Technical Approach

### 修改文件清单

**核心修改：**

1. **`lib/core/network/dto/api_response.dart`**
   - `fromJson`: 增加 `List<dynamic>` 数据处理分支
   - 新增工厂方法 `fromJsonList<T>()` 或在现有方法中统一处理

2. **`lib/core/network/adapters/common_api_adapter.dart`**
   - `performRequest`: 允许 `data: null` 的成功响应
   - `deleteToken`: 改为使用 `performRequest` 或手动检查信封

3. **`lib/core/network/dto/token_dto.dart`**
   - `_parseQuota`: 增加 string → double → int 转换

4. **`lib/core/network/adapters/sub2api_adapter.dart`**
   - `deleteToken`: 检查响应信封

### 修复策略

**Bug 1 & 2 的修复** — `ApiResponse` 和 `performRequest`：

方案：在 `ApiResponse.fromJson` 中增加 `allowNullData` 参数，在 `performRequest` 中增加 `allowNullData` 参数传递。

对于 List 数据（token list），在 `ApiResponse` 中增加 `fromJsonWithList` 工厂方法，或在 `fromJson` 中增加 `fromListItem` 回调参数。

**更简洁的方案**：

将 `performRequest` 改为支持两种模式：
- 单对象模式：data 是 Map → fromJson
- 列表模式：data 是 Map(分页) 或 List → TokenListDto.fromJson
- 允许空数据模式：data 是 null → 返回成功

具体实现：
```dart
// api_response.dart
static ApiResponse<T> fromJson<T>(
  Map<String, dynamic> json,
  T Function(Map<String, dynamic>) fromJson, {
  bool allowNullData = false,
}) {
  final success = json['success'] as bool? ?? false;
  final message = json['message'] as String?;

  T? data;
  if (success) {
    final rawData = json['data'];
    if (rawData is Map<String, dynamic>) {
      data = fromJson(rawData);
    } else if (allowNullData && rawData == null) {
      // data stays null but success is true — caller handles this
    }
    // List case is handled by caller separately
  }

  return ApiResponse<T>(success: success, message: message, data: data);
}
```

```dart
// common_api_adapter.dart performRequest
@protected
Future<Result<T>> performRequest<T>({
  required String method,
  required String path,
  required ApiRequest request,
  required T Function(Map<String, dynamic>) fromJson,
  Map<String, dynamic>? queryParameters,
  Object? data,
  bool allowNullData = false,
}) async {
  // ...
  if (apiResponse.success) {
    if (apiResponse.data != null) {
      return Success<T>(apiResponse.data!);
    }
    if (allowNullData) {
      // For create/update, success with null data is valid
      // Return a default-constructed instance or handle in caller
    }
  }
  // ...
}
```

但实际上 `performRequest<T>` 返回 `Result<T>`，对于 create/update `T = TokenDto`，data=null 时需要构造空 TokenDto。可以在调用侧处理。

**更实用的方案**：

`listTokens` 特殊处理 List 格式：
- 在 `CommonApiAdapter.listTokens` 中不使用 `performRequest`，而是像 Sub2API 一样手动解析
- 这样可以同时处理 Map 和 List 两种格式

`createToken` / `updateToken`：
- 在调用 `performRequest` 后，即使 data=null，只要 success=true 就返回成功
- 修改 `performRequest` 增加 `allowNullData` 参数

## Technical Notes

- 上一个任务（04-27-fix-key-api-bugs）已修复请求构建侧的 bug
- 本任务专注于响应解析侧
- Sub2API adapter 的 createToken/updateToken 已经正确处理了 data:null（返回空 TokenDto）
- 问题集中在 CommonApiAdapter 和 ApiResponse 层
