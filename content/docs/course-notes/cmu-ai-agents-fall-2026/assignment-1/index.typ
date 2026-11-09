#import "../../../../../config.typ": template, tufted

#show: template.with(title: "Assignment 1：从零构建 Agent Harness")

#html.elem("a", attrs: (class: "back-link", href: "/xiaoxu/docs/course-notes/cmu-ai-agents-fall-2026/"))[← 返回 AI Agents · 2026 秋季]

= Assignment 1：从零构建 Agent Harness

*当前进度：* 已建立作业仓库，尚未实现或运行实验。\
*我的代码：* #link("https://github.com/Em-perseon/assignment-1")[Em-perseon/assignment-1]。\
*任务说明：* #link("https://github.com/cmu-agents/assignment-1/blob/main/ASSIGNMENT.md")[Build an Agent Harness]。

这次作业把工具调用、上下文管理和技能使用串成一个可运行的系统：先让代码智能体修好一个国际象棋应用，再让下棋智能体在修复后的应用里行动。两个智能体共用同一套 ReAct 循环，变化的是任务、工具和观察方式。

我会在这里记录实现思路、调试过程和实验结果。当前先整理任务地图与实验计划，结果部分在实际运行后补充。

#outline(title: [目录], depth: 2)

== 一、要构建怎样的系统？

Harness 负责把模型输出接到真实环境：组织消息、请求模型、解析动作、执行工具、关联返回结果，并判断是否继续。模型提出动作，Harness 执行动作，再把观察交回模型。

#html.elem("div", attrs: (class: "essay-main-image"))[
  #image("task-map.svg", width: 100%, alt: "共享 ReAct 循环支持 CodeAgent 修复应用、上下文压缩实验和 ChessAgent 下棋；修复补丁是下棋环境的前置条件。")
]

关键是把*通用循环*与*领域工具*分开。CodeAgent 在终端中读文件、改代码、运行测试；ChessAgent 通过棋局接口落子、模拟和读取返回状态。二者不应各写一套 ReAct 循环。

== 二、三个部分分别做什么？

=== Part 1 · 代码智能体与应用修复

先实现提示词构建和 ReAct 生命周期：保存有效的动作—观察历史、处理结束状态和步数上限，再接入 `execute`、`send_message` 与技能调用。

工具执行失败不一定要终止整个任务。参数 JSON 错误、未知工具等情况应返回可恢复的观察，让模型有机会修改下一次调用。每条工具返回必须对应当前 assistant 动作中的调用 ID；不能假定服务端给出的 ID 在整个轨迹里永不重复。

技能采用渐进披露：系统提示先列出技能名称和描述，模型调用 `invoke_skill` 后才取得完整内容。代码智能体利用提交技能生成补丁，再在全新的测试环境里重放补丁，检查是否真正修好棋类应用。

*主要证据：* `artifacts/fix.patch`、`artifacts/part1-trajectory.json` 和补丁重放测试结果。

=== Part 2 · 上下文压缩与对照实验

在共享 Agent 中实现模型生成的工作记忆。压缩较旧的历史，但原始 system/task 消息要原样保留，最近一次完整 assistant 动作及其全部工具返回也要保留，避免破坏消息协议。

实验任务是 `django__django-15368`，比较完整上下文与 6,000-token 阈值压缩。压缩组需要实际触发压缩、明显缩短活动上下文，并生成通过回放测试的补丁。压缩是否有用，要同时看任务结果、token 使用和保留下来的状态。

*主要证据：* 两组运行轨迹、补丁、压缩事件，以及 `artifacts/token-usage-analysis.md`。

=== Part 3 · 下棋智能体与程序化工具调用

ChessAgent 执白棋，服务端的确定性对手执黑棋。实现 `play_move` 的参数定义、请求执行、状态更新与错误恢复，并复用前两部分的循环。

接着比较“只看棋盘”与“棋盘加合法着法列表”对行为的影响，再加入 `simulate_move`、`run_python` 和选棋技能。模拟只探索假设局面；真正落子才改变实时棋盘。程序运行后还要重新读取实时局面，避免模型重复执行已经落下的棋。

*主要证据：* 基础棋局轨迹与终局记录、四组观察实验，以及把技能、程序化搜索和真实落子串起来的轨迹。不同任务的验收要求不同：基础棋局需要达到终局，技能搜索演示不要求下完整局或获胜。

== 三、代码从哪里开始读？

#table(columns: 2,
[入口], [关注的问题],
[#link("https://github.com/Em-perseon/assignment-1/blob/main/src/assignment/agent/base.py")[`agent/base.py`]], [共享消息历史、ReAct 循环、技能发现与上下文压缩。],
[#link("https://github.com/Em-perseon/assignment-1/blob/main/src/assignment/agent/code_agent.py")[`agent/code_agent.py`]], [编码任务提示、终端工具分发、提交技能。],
[#link("https://github.com/Em-perseon/assignment-1/blob/main/src/assignment/agent/tools.py")[`agent/tools.py`]], [工具名称、描述与参数契约。],
[#link("https://github.com/Em-perseon/assignment-1/blob/main/src/assignment/agent/chess_agent.py")[`agent/chess_agent.py`]], [棋局观察、工具调度、状态与结束条件。],
[#link("https://github.com/Em-perseon/assignment-1/blob/main/src/assignment/agent/chess_tools.py")[`agent/chess_tools.py`]], [落子、模拟、沙箱 Python 与技能调用。],
)

以上文件都位于 `src/assignment/` 下。先读公共基类，再看两个领域子类，比较哪些职责可以共用、哪些必须由具体环境实现。

== 四、准备与验证顺序

项目要求 Python 3.11 或以上，并使用 uv 管理依赖。开始时从自己的 fork 克隆，保留作业固定的子模块版本：

```bash
git clone --recurse-submodules https://github.com/Em-perseon/assignment-1.git
cd assignment-1
make setup
make test
```

`make test` 是离线、不计费的公开测试；初始代码留有 TODO，因此未实现部分测试失败是预期现象。完成对应模块后逐步检查，不能把公开测试全部通过等同于满足所有验收要求。

实际 Agent 运行使用 Modal 沙箱与模型服务。准备运行时配置 Modal 和本地环境文件，然后检查环境：

```bash
uv run modal setup
cp .env.example .env
# 在本地 .env 中配置模型服务，不提交密钥。
make doctor
```

`make doctor` 检查子模块、认证和模型端点，不启动沙箱或生成 token。真实 Agent 运行、Modal 集成测试和沙箱评估会使用云资源或 API 额度。

建议按以下顺序推进：

1. 完成 Part 1 的提示词、循环、工具与技能，用离线测试检查。
2. 运行 `make run-code-agent`，再用 `make check-part1` 在新环境重放补丁。
3. 完成压缩逻辑，以独立文件名保存完整上下文和压缩组的轨迹及补丁。
4. 运行基础 ChessAgent，再完成观察 A/B 和程序化搜索实验。
5. 汇总结果、复核证据文件，并整理提交包。

== 五、实验记录

=== 上下文压缩对照

两组使用相同任务，并记录模型版本、推理参数和代码版本。完整上下文组设 `COMPACT_THRESHOLD=0`；压缩组设 `COMPACT_THRESHOLD=6000`。

#table(columns: 3,
[指标], [完整上下文], [压缩上下文],
[运行状态], [待运行], [待运行],
[补丁回放是否通过], [—], [—],
[输入 / 输出 token], [—], [—],
[压缩次数与前后活动上下文], [—], [—],
[ReAct 步数与耗时], [—], [—],
)

分析时会区分累计 token 与当轮活动上下文，并计入生成摘要本身的开销。单次随机运行的步数不能直接证明一种方法总是更好；还要检查摘要是否丢失约束、重复排错或误记测试结果。

=== 棋局观察 A/B

#table(columns: 4,
[模型组], [观察内容], [运行入口], [结果],
[DeepSeek], [棋盘], [`make run-obs-deepseek-no-legal`], [待运行],
[DeepSeek], [棋盘 + 合法着法], [`make run-obs-deepseek-legal`], [待运行],
[GPT-OSS], [棋盘], [`make run-obs-gpt-oss-no-legal`], [待运行],
[GPT-OSS], [棋盘 + 合法着法], [`make run-obs-gpt-oss-legal`], [待运行],
)

每组记录 `play_move` 总调用数、被判非法的调用数、非法率，以及是否达到 `game_over: true`。结果解释围绕观察接口如何影响行为展开，获胜不是唯一指标。

=== 技能与程序化搜索

待记录一次完整的决策过程：发现并读取选棋技能，用 `run_python` 调用 `simulate_move` 探索候选，再用 `play_move` 提交一步真实落子。这里关注工具是否真正组合起来工作，而不是仅仅都被注册过。

== 六、实现记录与复盘

*实现进度：* Part 1、Part 2、Part 3 均待开始。

后续每个阶段记录四件事：遇到了什么问题、如何定位、做了什么修改、用什么证据验证。实验完成后再补充轨迹片段、棋局截图、token 变化图和结果分析。

== 七、验收与材料

作业总计 100 分：Part 1 为 30 分，Part 2 为 28 分，Part 3 为 40 分，提交完整性为 2 分。实现、实验和证据分别评估，某次随机运行失败不意味着其他实现项也失败。

实现应遵守任务边界：不修改 `tests/`、`tasks/`、`chess_app/`，不修改既有日志与清理机制，不在子类重复公共循环，也不硬编码任务答案。模型生成的 Python 在提供的沙箱里执行。

最终提交包含修改过的 Agent 源码、要求的补丁和轨迹、两份实验分析，以及如实记录工具使用的 `AI_USAGE.md`；若修改 `prompts.py`，也需包含该文件。完整文件清单以 #link("https://github.com/cmu-agents/assignment-1/blob/main/ASSIGNMENT.md#submission")[提交要求] 为准。

#link("https://github.com/Em-perseon/assignment-1")[我的作业仓库 →]\
#link("https://github.com/cmu-agents/assignment-1")[上游初始代码 →]\
#link("../tool-use/")[相关笔记：工具使用 →]\
#link("../long-context/")[相关笔记：长上下文管理 →]
