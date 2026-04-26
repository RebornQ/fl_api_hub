---
description: 让 Agent 用 AskUserQuestion 工具对你进行详细采访，完善需求规格，然后创建 Trellis 任务
argument-hint: [ 简要描述 ]
---

我想构建 $ARGUMENT。用 AskUserQuestion 工具对我进行详细采访。

问我关于技术实现、UI/UX、边界情况、顾虑和权衡的问题。 不要问显而易见的问题，深入挖掘我可能没有考虑到的困难部分。

持续采访直到我们覆盖了所有方面，然后询问我是否需要把完整的需求规格写入 SPEC.md。

要求：

1. 验证和测试阶段必须用 SubAgent 执行，以减少主 Agent 的上下文负担
2. 帮我规划一下怎么拆分任务。用 .trellis/scripts/task.py 创建 Trellis Tasks 任务，尽可能多地拆分任务。在
   Plan 模式下禁止直接执行脚本，先写入计划，退出 Plan 模式后再用 SubAgent 执行。