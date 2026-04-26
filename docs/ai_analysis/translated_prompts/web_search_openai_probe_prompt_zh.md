# 提示词翻译文档

## 元信息
- 原文件位置: `src/services/verification/aiApiVerification/probes/webSearchProbe.ts:49`
- 变量名称: `prompt`
- 提示词类别: 用户提示词
- 功能模块: API 验证系统 - 网页搜索探针（OpenAI 版）
- 调用场景: 用户验证 OpenAI 类型 API 端点时，作为第五阶段探针测试是否支持网页搜索/实时信息检索功能

## 中文翻译

```
使用网页搜索找到一条关于 AI SDK 的最新头条新闻。
```

### 关联工具配置

```typescript
tools: {
  web_search: provider.tools.webSearch({
    externalWebAccess: true,    // 允许外部网络访问
    searchContextSize: "low",   // 搜索上下文量：低
  }),
}
toolChoice: { type: "tool", toolName: "web_search" }  // 强制使用搜索工具
```

## 动态参数解析 (Prompt Lineage)
- 无动态参数，该提示词为固定字符串
- 关联输入参数：
  - `params.baseUrl` - API 端点 URL
  - `params.apiKey` - API 密钥
  - `params.apiType` - 固定为 `"openai"`
  - `params.modelId` - 测试模型 ID

## 相关代码上下文
- **调用方式**: 通过 `createOpenAIProvider()` 创建 OpenAI 提供商，使用其内置的 `webSearch` 工具
- **适用范围**: 仅适用于 `apiType === "openai"` 的端点
- **结果验证**: 检查 `toolResults` 中是否包含 `web_search` 调用，或 `sources` 列表是否非空
- **上游调用链**: `apiVerificationService.ts` → `runWebSearchProbe()` → `generateText()`
- **探针执行顺序**: models → text-generation → tool-calling → structured-output → **web-search**
- **特殊处理**: Anthropic API 类型直接返回 `unsupported` 状态，跳过此探针
