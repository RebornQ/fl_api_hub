# 提示词翻译文档

## 元信息
- 原文件位置: `src/services/verification/aiApiVerification/probes/structuredOutputProbe.ts:36`
- 变量名称: `prompt`
- 提示词类别: 用户提示词
- 功能模块: API 验证系统 - 结构化输出探针
- 调用场景: 用户验证 API 端点时，作为第四阶段探针测试 LLM 是否支持结构化 JSON 输出

## 中文翻译

```
返回一个形如 { ok: true } 的 JSON 对象。
```

### 关联输出 Schema

```typescript
z.object({
  ok: z.literal(true)  // 必须返回 { ok: true }
})
```

## 动态参数解析 (Prompt Lineage)
- 无动态参数，该提示词为固定字符串
- 输出验证使用 Zod Schema：`z.object({ ok: z.literal(true) })`
- 关联输入参数：
  - `params.baseUrl` - API 端点 URL
  - `params.apiKey` - API 密钥
  - `params.apiType` - API 类型
  - `params.modelId` - 测试模型 ID

## 相关代码上下文
- **调用方式**: 通过 Vercel AI SDK 的 `generateText()` + `Output.object()` 参数实现结构化输出
- **Schema 验证**: 使用 Zod 库定义输出格式，AI SDK 自动将 Schema 传递给 LLM
- **结果验证**: 检查 `output?.ok === true` 是否成立
- **上游调用链**: `apiVerificationService.ts` → `runStructuredOutputProbe()` → `generateText()`
- **探针执行顺序**: models → text-generation → tool-calling → **structured-output** → web-search
- **依赖库**: `ai`（Vercel AI SDK）、`zod`（Schema 验证）
