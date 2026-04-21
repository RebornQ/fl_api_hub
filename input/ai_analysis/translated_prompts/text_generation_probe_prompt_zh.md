# 提示词翻译文档

## 元信息
- 原文件位置: `src/services/verification/aiApiVerification/probes/textGenerationProbe.ts:28`
- 变量名称: `prompt`
- 提示词类别: 用户提示词
- 功能模块: API 验证系统 - 基础文本生成探针
- 调用场景: 用户在 API 验证对话框中触发验证流程时，作为第一阶段探针测试 LLM 端点的基础文本生成能力

## 中文翻译

```
请精确回复：OK
```

## 动态参数解析 (Prompt Lineage)
- 无动态参数，该提示词为固定字符串
- 关联输入参数（非提示词变量）：
  - `params.baseUrl` - API 端点 URL
  - `params.apiKey` - API 密钥
  - `params.apiType` - API 类型（openai-compatible / openai / anthropic / google）
  - `params.modelId` - 测试模型 ID

## 相关代码上下文
- **调用方式**: 通过 Vercel AI SDK 的 `generateText()` 函数发送
- **模型创建**: `createModel()` 根据 `apiType` 动态选择提供商（OpenAI Compatible / OpenAI / Anthropic / Google）
- **结果验证**: 检查返回文本是否包含 "ok"（大小写不敏感）
- **上游调用链**: `apiVerificationService.ts` → `runTextGenerationProbe()` → `generateText()`
- **探针执行顺序**: models → **text-generation** → tool-calling → structured-output → web-search
- **结果输出**: 返回 `ApiVerificationProbeResult` 包含 pass/fail 状态、延迟和摘要信息
