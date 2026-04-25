# feat(backup): 数据管理 — 备份与恢复

## Goal

在 Settings 页面新增「数据管理」分类，支持本地 JSON 手动导入/导出全部核心数据，可选 AES-256-GCM 密码加密，恢复时用户自选全量替换或智能合并。

## Requirements

- 备份 7 个 Hive Box 全量数据（accounts, keys, tags, check_in_tasks, check_in_results, scheduler_config, app_data），排除 account_reachability 缓存
- 可选密码加密：AES-256-GCM + PBKDF2 密钥派生；允许不加密明文 JSON 备份
- 密码持久化到 app_data Hive Box（backup_password + backup_encrypted），下次备份自动复用
- 恢复策略用户自选：全量替换（清空后写入）or 智能合并（ID 匹配，保留 updatedAt 更新的）
- 导出方式双支持：系统分享（share_plus）+ 保存到文件（file_picker）
- 进度指示器 + 阶段文字提示
- 恢复失败时类别独立处理 + 详细错误提示
- UI 入口：设置页 SectionCard「数据管理」→ Navigator.push 子页面

## Acceptance Criteria

- [ ] 创建未加密备份 → 输出可读 JSON 文件（.flbkp）
- [ ] 创建加密备份 → 输出二进制文件，密码持久化后第二次备份无需重输
- [ ] 恢复未加密文件 → 直接恢复无需密码
- [ ] 恢复加密文件 → 输入密码后恢复；错误密码给出提示
- [ ] 恢复（替换模式）→ 清空现有数据后写入备份数据，所有字段一致
- [ ] 恢复（合并模式）→ 按 ID 匹配合并，孤儿 Keys/Tasks/Results 跳过
- [ ] 系统分享和保存到文件两种导出方式均可用
- [ ] 操作期间显示进度指示器
- [ ] 清除密码后后续备份为未加密模式
- [ ] flutter analyze 无 warning
- [ ] dart format 通过

## Definition of Done

- 单元测试覆盖加密/解密往返、合并策略、序列化往返
- Lint / typecheck / CI green
- Settings 页面 UI 集成完整

## Technical Approach

- BackupData 存储原始 Map<String, dynamic>，恢复时通过现有 Mapper.fromMap 反序列化
- 直接操作 Hive Box（Box.values 读取、box.put 写入），不依赖现有 DataSource 类
- 未加密文件为 JSON（首字节 `{`），加密文件为二进制 `[salt][nonce][ciphertext]`
- 恢复后 invalidate 所有受影响 providers 确保 UI 刷新
- 新增 BackupException extends AppException

## Out of Scope

- WebDAV / 云同步
- 自动定时备份
- 多版本历史管理
- 数据范围复选框（MVP 全量备份）
- 删除同步

## Technical Notes

- 复用文件：hive_store.dart, *_mapper.dart, result.dart, app_exception.dart, section_card.dart
- 新增依赖：encrypt, crypto, share_plus, file_picker, path_provider
