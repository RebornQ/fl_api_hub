# 提示词翻译文档

## 元信息
- 原文件位置: `src/services/verification/aiApiVerification/probes/toolCallingProbe.ts:43`
- 变量名称: `prompt`
- 提示词类别: 用户提示词
- 功能模块: API 验证系统 - 工具调用探针
- 调用场景: 用户验证 API 端点时，作为第三阶段探针测试 LLM 是否支持函数/工具调用功能

## 中文翻译

```
调用 verify_tool 工具一次。回复一个包含返回时间的简短句子。
```

### 关联工具定义

```
工具名称: verify_tool
工具描述: "返回一个时间戳字符串。"
输入 Schema: { type: "object", properties: {} }
执行逻辑: 返回 { now: new Date().toISOString() }
工具选择策略: required（强制调用）
```

## 动态参数解析 (Prompt Lineage)
- 无动态参数，该提示词为固定字符串
- 工具定义中的动态数据：
  - `new Date().toISOString()` - 工具执行时返回的当前时间戳
- 关联输入参数：
  - `params.baseUrl` - API 端点 URL
  - `params.apiKey` - API 密钥
  - `params.apiType` - API 类型
  - `params.modelId` - 测试模型 ID

## 相关代码上下文
- **调用方式**: 通过 Vercel AI SDK 的 `generateText()` + `tools` 参数发送
- **工具构建**: 使用 AI SDK 的 `tool()` 函数 + `jsonSchema()` 定义工具
- **结果验证**: 通过 `toolCalled()` 辅助函数检查 `toolCalls` 或 `toolResults` 中是否包含 `verify_tool` 的调用
- **上游调用链**: `apiVerificationService.ts` → `runToolCallingProbe()` → `generateText()`
- **探针执行顺序**: models → text-generation → **tool-calling** → structured-output → web-search
- **错误处理**: 捕获异常后推断 HTTP 状态码，映射到对应的 i18n 错误消息键
