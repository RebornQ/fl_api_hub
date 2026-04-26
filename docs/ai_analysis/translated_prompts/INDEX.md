# 提示词翻译文档索引

> 本索引由 project-analyzer skill 自动生成
> 生成时间: 2026-03-22T12:00:00+08:00

---

## 统计总览

| 统计项 | 数量 | 说明 |
|--------|------|------|
| **总提示词数量** | 5 | 实际翻译文档总数 |
| 系统提示词 | 0 | SYSTEM/ROLE 类提示词 |
| 用户提示词 | 5 | USER/HUMAN 类提示词 |
| 任务提示词 | 0 | TASK/INSTRUCTION 类提示词 |
| 工具提示词 | 0 | TOOL/FUNCTION 类提示词 |

---

## 按类别分类

### 用户提示词 (5个)

| 序号 | 名称 | 原文件位置 | 功能描述 | 翻译文档 |
|------|------|-----------|----------|----------|
| 1 | text_generation_probe_prompt | `probes/textGenerationProbe.ts:28` | API 验证系统 - 基础文本生成探针 | [查看](./text_generation_probe_prompt_zh.md) |
| 2 | tool_calling_probe_prompt | `probes/toolCallingProbe.ts:43` | API 验证系统 - 工具调用探针 | [查看](./tool_calling_probe_prompt_zh.md) |
| 3 | structured_output_probe_prompt | `probes/structuredOutputProbe.ts:36` | API 验证系统 - 结构化输出探针 | [查看](./structured_output_probe_prompt_zh.md) |
| 4 | web_search_openai_probe_prompt | `probes/webSearchProbe.ts:49` | API 验证系统 - 网页搜索探针（OpenAI 版） | [查看](./web_search_openai_probe_prompt_zh.md) |
| 5 | web_search_google_probe_prompt | `probes/webSearchProbe.ts:96` | API 验证系统 - 网页搜索探针（Google 版） | [查看](./web_search_google_probe_prompt_zh.md) |

---

## 完整列表（按发现顺序）

| 全局序号 | 名称 | 类别 | 原文件位置 | 翻译文档 |
|----------|------|------|-----------|----------|
| 1 | text_generation_probe_prompt | 用户 | `probes/textGenerationProbe.ts:28` | [查看](./text_generation_probe_prompt_zh.md) |
| 2 | tool_calling_probe_prompt | 用户 | `probes/toolCallingProbe.ts:43` | [查看](./tool_calling_probe_prompt_zh.md) |
| 3 | structured_output_probe_prompt | 用户 | `probes/structuredOutputProbe.ts:36` | [查看](./structured_output_probe_prompt_zh.md) |
| 4 | web_search_openai_probe_prompt | 用户 | `probes/webSearchProbe.ts:49` | [查看](./web_search_openai_probe_prompt_zh.md) |
| 5 | web_search_google_probe_prompt | 用户 | `probes/webSearchProbe.ts:96` | [查看](./web_search_google_probe_prompt_zh.md) |

---

## 数据一致性声明

- 本索引记录提示词总数: 5
- translated_prompts/ 目录实际文件数: 5 (不含本索引文件)
- AI_MODEL_USAGE_ANALYSIS.md 引用提示词数: 5
- 三者一致性检查: ✅ 通过

---

> 注：所有提示词均位于 `src/services/verification/aiApiVerification/probes/` 目录下，属于 API 验证系统的测试探针。
> 这些提示词用于验证用户添加的 AI API 端点是否支持特定能力（文本生成、工具调用、结构化输出、网页搜索），
> 不是项目核心业务逻辑中的 AI 提示词。

最后更新时间: 2026-03-22T12:00:00+08:00
