# 提示词翻译文档

## 元信息
- 原文件位置: `src/services/verification/aiApiVerification/probes/webSearchProbe.ts:96`
- 变量名称: `prompt`
- 提示词类别: 用户提示词
- 功能模块: API 验证系统 - 网页搜索探针（Google 版）
- 调用场景: 用户验证 Google Gemini API 端点时，作为第五阶段探针测试是否支持 Google Search Grounding 功能

## 中文翻译

```
使用 Google 搜索基础功能找到一条最新的 AI 头条新闻。
```

### 关联工具配置

```typescript
tools: {
  google_search: google.tools.googleSearch({}),  // 空配置，使用默认参数
}
toolChoice: { type: "tool", toolName: "google_search" }  // 强制使用搜索工具
```

## 动态参数解析 (Prompt Lineage)
- 无动态参数，该提示词为固定字符串
- 关联输入参数：
  - `params.baseUrl` - API 端点 URL
  - `params.apiKey` - API 密钥
  - `params.apiType` - 固定为 `"google"`
  - `params.modelId` - 测试模型 ID

## 相关代码上下文
- **调用方式**: 通过 `createGoogleProvider()` 创建 Google Gemini 提供商，使用其内置的 `googleSearch` 工具
- **适用范围**: 仅适用于 `apiType === "google"` 的端点
- **结果验证**: 检查 `toolResults` 中是否包含 `google_search` 调用，或 `sources` 列表是否非空
- **上游调用链**: `apiVerificationService.ts` → `runWebSearchProbe()` → `generateText()`
- **探针执行顺序**: models → text-generation → tool-calling → structured-output → **web-search**
- **与 OpenAI 版的区别**: 使用 Google 原生的 Search Grounding API，而非通用的 web_search 工具
