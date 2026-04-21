# Batch 1: Check-In Data Layer Refactor (Per-Account Cap + Pagination)

> 本 PRD 聚焦数据层（domain + data 两层）的改造，UI 改动在 Batch 2（`check-in-ui-master-detail`）进行。

---

## 背景

当前 `check_in_results` Hive box 没有任何上限，随时间无限增长。产品决定：每个账号最多保留最近 50 条签到结果，查询单账号历史时需要分页（UI 使用无限滚动）。同时需要一次性静默迁移老用户的超量数据。

## 业务需求

1. **每账号封顶 50 条**。不同账号互不影响（`accountId` 独立维护各自的 50 条上限）。
2. **写入时同步修剪**：`saveResult` 每次写入后立即检查目标账号记录数，超过 50 立即删除最旧的。保证任何时刻每账号 ≤ 50。
3. **启动时静默迁移**：app 启动早期一次性扫描 `check_in_results`，对已超量账号修剪到 50 以内。失败静默吞掉，不阻塞 `runApp`，不给用户反馈。
4. **提供分页查询能力**：按 `accountId` 分页查询历史记录，支持 `limit` / `offset`，newest-first 排序。UI（Batch 2）默认 20 条/页。
5. **提供单账号一键清空**：删除某账号所有记录，返回删除数。
6. **提供每账号最新一条查询**：主列表（Batch 2）按账号聚合展示最新一条结果，需要这个新方法支撑。

## 技术约束

- **保留 Hive**。不引入 SQLite。扫描 + 过滤 + 排序 + 分页全部基于现有 `_resultBox.values` 迭代完成。数据规模受 50 × accountCount 约束，成本可控。
- **沿用 Result 类型模式**：所有新增 repository 方法用 `Future<Result<T>>` 包裹，错误一律转成 `StorageException`。
- **不破坏现有 API**：`getAllResults`、`getResultsByTaskId`、`getResultsByAccountId`、`getLatestResult(taskId)`、`saveResult` 保留原签名。新方法纯新增。

## 交付范围

### 代码修改

| 文件 | 性质 | 说明 |
|---|---|---|
| `lib/features/check_in/data/datasources/check_in_local_datasource.dart` | 修改 | 新增常量 `kCheckInResultsCapPerAccount = 50` + 6 个新方法；在 `saveResult` 里串接 `pruneAccountResults`。 |
| `lib/features/check_in/domain/repositories/check_in_repository.dart` | 修改 | 新增 5 个抽象方法签名。 |
| `lib/features/check_in/data/repositories/check_in_repository_impl.dart` | 修改 | 实现 5 个新方法，delegate 到 datasource。 |
| `lib/main.dart` | 修改 | 在 `await initHive();` 后加入 `await _migrateCheckInResultCap();`（静默 try/catch）。 |

### 新方法签名

Datasource：
```dart
List<CheckInResult> getLatestResultPerAccount();
List<CheckInResult> getResultsByAccountIdPaged(
  String accountId, {required int limit, required int offset});
int countResultsByAccountId(String accountId);
Future<int> deleteAllResultsByAccountId(String accountId);
Future<int> pruneAccountResults(String accountId, {int keep = kCheckInResultsCapPerAccount});
Future<int> migrateResultsToCap({int keep = kCheckInResultsCapPerAccount});
```

Repository:
```dart
Future<Result<List<CheckInResult>>> getLatestResultPerAccount();
Future<Result<List<CheckInResult>>> getResultsByAccountIdPaged(
  String accountId, {required int limit, required int offset});
Future<Result<int>> countResultsByAccountId(String accountId);
Future<Result<int>> deleteAllResultsByAccountId(String accountId);
Future<Result<void>> migrateResultsToCap({int keep = 50});
```

### 测试

| 测试文件 | 新增/扩展 | 覆盖 |
|---|---|---|
| `test/features/check_in/data/datasources/check_in_local_datasource_test.dart` | 新增 | 使用真实 Hive 临时目录（遵循项目已有 pattern）。覆盖 trim-on-write、分页、count、清空、prune、migrate 多账号混合场景。 |
| `test/features/check_in/data/repositories/check_in_repository_impl_test.dart` | 扩展 | mocktail 每个新方法的成功 + `StorageException` 失败路径。 |

测试阶段由 SubAgent（`subagent_type: general-purpose`）驱动执行：写测试 + 运行 `flutter test` + `dart analyze` 到全绿。

## 验收标准

- [ ] `dart analyze` 零警告零错误
- [ ] 所有新增/扩展测试通过
- [ ] 手工验证：对同一账号连续写入 51 条结果，`countResultsByAccountId` 稳定返回 50；写入不影响其他账号计数
- [ ] 手工验证：种入 80 条某账号结果 → 重启 app → `countResultsByAccountId` 返回 50
- [ ] `saveResult`、`getAllResults`、`getResultsByTaskId`、`getResultsByAccountId`、`getLatestResult(taskId)` 对外行为不变，现有调用方无需改动即可编译通过

## 非目标 / 超出范围

- UI 层改造（master-detail、分页无限滚动、清空按钮、摘要卡片）全部留给 Batch 2。
- 不动 `CheckInNotifier` 里 `allCheckInResultsProvider` 的 invalidate 调用（Batch 2 重写 provider 依赖图时一并处理）。
- 不引入 SQLite 或其他持久化方案。
- 不改 `lib/app/router.dart`。
