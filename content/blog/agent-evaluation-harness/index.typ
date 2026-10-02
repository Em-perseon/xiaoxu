#import "../index.typ": template, tufted

#show: template.with(title: "别只看 Agent 的最后一句话：从一次轨迹到一套可信的 Evaluation Harness")

#html.elem("a", attrs: (class: "back-link", href: "/xiaoxu/blog/"))[← 返回 Blog]

= 别只看 Agent 的最后一句话

#context {
  if target() == "html" {
    html.elem("p", attrs: (class: "article-subtitle"))[从一次轨迹到一套可信的 Evaluation Harness]
  } else {
    block(width: 100%)[#text(size: 15pt, style: "italic")[从一次轨迹到一套可信的 Evaluation Harness]]
  }
}

#html.elem("p", attrs: (class: "article-lead"))[
  评测一个 Agent，不是在它说完“任务已完成”后打一个分。真正需要检查的是：世界有没有被正确改变，过程是否越权或绕路，同一任务再跑一次还能不能成功，以及这套评测本身是否值得相信。
]

*整理日期：* 2026 · 10 · 02　　*关键词：* Agent Evaluation、Harness、Trajectory、Reliability、Benchmark Audit

#outline(title: [目录], depth: 2)

== 一句“完成了”，为什么远远不够

想象一个旅行 Agent。用户让它取消酒店订单，它最后回复：“订单已经取消，退款会在三个工作日内到账。”如果只评价这句话，语义完整、语气自然，似乎没有问题。

但一个真正的系统实验还要继续追问：订单状态是否真的变成 `cancelled`？退款金额是否正确？Agent 是否误取消了另一笔订单？它有没有读取无关的私人信息？如果酒店接口第一次超时，它是安全重试，还是重复提交了两次？

这正是普通 LLM evaluation 与 Agent evaluation 的分水岭。前者常被写成一次静态映射：

$ x arrow^(f_theta) y, quad "score" = g(y, y^star) $

Agent 则在循环里观察、行动并改变环境：

$ o_t arrow a_t arrow cal(E)(s_t, a_t) arrow (s_(t+1), o_(t+1)) $

一次运行留下的不是单个答案，而是一条 trajectory：

$ tau = (o_0, a_0, o_1, a_1, dots, o_T, a_T, s_(T+1)) $

最终文本只是这条轨迹最后露出水面的一小部分。任务是否完成，往往藏在数据库、文件、网页、代码仓库或其他外部状态里；行为是否合理，则要回到工具调用和状态变化中寻找证据。

所以，Agent evaluation 更接近一场*交互式系统实验*，而不是一张静态试卷。

== Harness：把 benchmark 变成可执行的实验契约

Benchmark 通常回答“考什么”：有哪些任务、目标和评分规则。Evaluation Harness 回答“这场考试究竟怎样被运行”：谁重置环境，谁把 observation 交给 Agent，谁执行 tool call，何时停止，保存哪些日志，又由谁判分。

可以把一个评测任务写成：

$ cal(T) = (R, E, C, G; xi) $

其中 $R$ 是用户请求，$E$ 是初始环境、工具与权限，$C$ 是完成、超时、主动结束或最大步数等停止条件，$G$ 是 grader。分号后的 $xi$ 则代表那些经常被忽略、却会改变结果的实验元数据：随机种子、模型版本、system prompt、工具 schema、token 与成本预算、重试策略、上下文管理方式。

这一定义带来一个重要结论：*Harness 配置本身就是实验变量。* 只报告 base model 的名字，却省略 prompt、memory、工具接口和 retry policy，得到的并不是一个可复现的 Agent 结果。

#context {
  if target() == "html" {
    html.elem("figure", attrs: (class: "agent-eval-figure"))[
      #image("agent-evaluation-harness.svg")
      #html.elem("figcaption")[一套 Harness 可以按实验契约、交互执行、证据评分和质量治理四层理解；线上失败最终回流为新的回归用例。]
    ]
  } else {
    figure(
      image("agent-evaluation-harness.svg", width: 100%),
      caption: [Agent Evaluation Harness 的分层结构。],
    )
  }
}

这张图刻意不把所有模块连成一张蛛网。最上层先冻结实验契约；中间层只负责让 Agent 与环境发生真实交互；评分层消费运行证据，而不是反过来干预轨迹；最下层再问结果是否稳定、安全，评测是否有效。四层分开后，数据流和责任边界都清楚得多。

== 一次 episode 到底怎样运行

Harness 的核心不是某个复杂算法，而是一段纪律严明的生命周期。每个 case 开始前，环境必须恢复到已知状态；运行中，Harness 在 Agent 与工具之间路由消息，同时执行预算与停止规则；结束后，它保存最终状态和完整轨迹，再把证据交给 grader。

一个最小 runner 大致如下：

```python
for case in eval_suite:
    env.reset(case.initial_state)
    trace = []

    for step in range(case.max_steps):
        observation = env.observe()
        action = agent.act(observation)
        result = env.step(action)
        trace.append((observation, action, result))

        if case.should_stop(env, trace):
            break

    evidence = {
        "final_state": env.snapshot(),
        "trajectory": trace,
    }
    grade = graders.evaluate(case, evidence)
    recorder.save(case, evidence, grade)
```

真实系统还要处理并发、sandbox、缓存、API 波动、工具异常和版本固定，但这些工程细节都服务于同一个目标：让每次运行可重放、可比较、可解释。

因此，每次 evaluation run 最好沉淀为一条自描述记录：

```json
{
  "case_id": "cancel-hotel-042",
  "agent_version": "travel-agent@8c1d9a2",
  "model": "...",
  "seed": 42,
  "environment_version": "booking-env@2026-10-02",
  "initial_state_hash": "...",
  "trajectory": [...],
  "final_state": {...},
  "grader_outputs": {...},
  "steps": 17,
  "latency_sec": 23.1,
  "cost_usd": 0.18
}
```

没有这些上下文，两个“成功率 70%”可能来自完全不同的工具权限、预算和环境版本，也就谈不上公平比较。

== Final state 给结论，trajectory 给原因

评测中最容易混淆的两件事，是*判定结果*与*解释结果*。

Final state 更适合回答“目标有没有真正实现”。酒店订单是否取消、测试是否通过、文件是否生成、数据库是否满足约束，都应该尽量由程序化检查完成。Trajectory 则回答“为什么会得到这个结果”：Agent 选了什么工具、参数是否正确、有没有重复调用、是否忽略关键 observation、在哪个异常后开始偏离。

同样的成功结果，可能来自完全不同的行为质量。一条轨迹直接完成任务，另一条轨迹先删除错误文件、再从备份中偶然恢复，两者不应被视为同样可靠。反过来，Agent 也可能已经正确完成任务，却因为 grader 漏掉一种合法解而被判失败。

因此，较稳健的 grader stack 通常不是“全部交给一个 LLM judge”，而是逐层使用最合适的证据：

#table(
  columns: (1.05fr, 1.7fr, 1.65fr),
  align: (left, left, left),
  inset: 7pt,
  stroke: 0.6pt + rgb("d8dee8"),
  table.header([*评分层*], [*适合判断什么*], [*主要风险*]),
  [状态／代码检查], [数据库状态、文件内容、测试结果、数值约束], [可能漏掉等价的合法解],
  [轨迹规则检查], [越权、重复调用、确认流程、首个关键错误], [规则覆盖不足或与工具语义脱节],
  [LLM judge], [解释质量、开放式策略、难以形式化的沟通效果], [位置、长度、模型偏好与 prompt 敏感性],
  [人工复核], [校准 rubric、处理争议样本、审计高风险结果], [成本高、速度慢、判断者之间不一致],
)

组合式评分可以写成：

$ G = w_1 G_"state" + w_2 G_"policy" + w_3 G_"quality" + w_4 G_"efficiency" $

但权重不是越多越科学。更重要的是先明确哪些条件是硬约束：例如“未经确认不得付款”不应被更流畅的解释抵消。对于这类任务，更合适的定义是：

$ "Safe Utility" = "Goal Completion" and "Policy Compliance" $

也就是说，任务完成并不蕴含安全完成。

== 从一个分数，转向一组证据

单一 success rate 只能回答“这批任务中有多少次被判成功”。一套真正可用的报告至少要同时回答三个问题：

#table(
  columns: (1fr, 1.5fr, 2fr),
  align: (left, left, left),
  inset: 7pt,
  stroke: 0.6pt + rgb("d8dee8"),
  table.header([*问题*], [*证据维度*], [*典型指标*]),
  [做成了吗？], [Outcome], [目标完成率、partial credit、最终状态正确性],
  [做得好吗？], [Efficiency / Process / Safety], [步骤、延迟、成本、无效动作、恢复率、违规率],
  [还能再做成吗？], [Reliability / Calibration], [重复运行方差、扰动鲁棒性、置信度与成功率、合理拒答],
)

第三个问题尤其容易被 leaderboard 掩盖。若把单次成功概率近似为 $p$，理想独立假设下：

$ "Pass@k" = 1 - (1-p)^k, quad "AllSuccess@k" = p^k $

`Pass@k` 问的是“给它 $k$ 次机会，至少成功一次吗”；`AllSuccess@k` 问的是“连续 $k$ 次都能成功吗”。一个系统可以拥有很好看的 `Pass@k`，却不适合接管一次性的付款、删除或发布操作。

真实 Agent 运行也未必独立同分布，所以公式只能帮助理解，不能替代复跑。实践中应直接改变采样、prompt 表述、页面布局、API 延迟、文件顺序和工具故障，观察能力在小扰动下是否仍然成立。此时，Agent eval 已经很像软件工程中的 fuzz testing、fault injection 与 regression testing。

== 评测系统自己也要接受评测

当结果不符合预期时，我们习惯先责怪 Agent。但 observed failure 其实有两种来源：

$ "observed failure" = "agent failure" quad "or" quad "evaluation failure" $

前者可以沿轨迹归并为几类：Agent 没看懂环境，规划或工具选择出错；工具选对却参数错误，随后又丢失状态；异常出现后不会恢复，或在错误时刻停止；它也可能完成目标，却绕过授权、安全和沟通约束。

后者发生在考场本身：任务实际上不可完成，初始状态和文字描述冲突，reset 不完整，ground truth 错误，grader 漏掉合法替代解，甚至 Agent 可以从环境中读到隐藏答案。把十几种错误平铺成清单并不利于定位；更实用的方式，是顺着证据链问三个 validity 问题：

1. *Task validity：* 题目是否清楚、真实、可完成，且覆盖了希望研究的能力？
2. *Execution validity：* 环境、工具、权限、预算和 reset 是否公平且可复现？
3. *Scoring validity：* grader 是否真的测量了它声称测量的东西？

这也是为什么 benchmark 需要自己的测试套件：case 要做 feasibility check，grader 要有 unit tests，环境 reset 要做一致性测试，还要保留 golden trajectories 检查评分器是否在版本更新后悄悄漂移。

== Offline 不是终点：让失败回到 Case Factory

离线 benchmark 一发布就开始老化。真实页面会改版，API 会变慢，用户目标和数据分布也会移动。更健康的评测系统因此是一个闭环：

```text
Offline Eval
  -> Deploy
  -> Trace Sampling
  -> Online Grading
  -> Failure Mining
  -> Regression Cases
  -> Offline Eval
```

线上信号可以来自用户反馈、人工接管、工具错误、自动 state checker、抽样轨迹复核、成本与延迟漂移。关键不是把所有生产日志直接塞进 benchmark，而是先聚类失败、去除隐私信息、验证任务可执行性，再把有代表性的案例变成稳定的 regression cases。

随着 Agent 数量和交互时间继续增长，评测边界还会外扩。单次任务成功无法描述推荐系统对用户长期行为的影响，也无法描述多个交易 Agent 形成的反馈回路，或多 Agent 协作中的联盟与欺骗。Social / Macro evaluation 不是每个项目的第一步，却提醒我们：局部最优的轨迹，不一定组成全局健康的系统。

== 把经典 benchmark 看成设计模式

与其背诵一串 benchmark 名称，不如把它们理解为 Harness 的不同设计选择：

#table(
  columns: (1fr, 1.45fr, 2.2fr),
  align: (left, left, left),
  inset: 7pt,
  stroke: 0.6pt + rgb("d8dee8"),
  table.header([*代表工作*], [*评测对象*], [*最值得借鉴的 Harness 思想*]),
  [#link("https://arxiv.org/abs/2308.03688")[AgentBench]], [多种交互环境], [Agent 能力应在行动与决策中测量，而不只在静态问答上测量],
  [#link("https://arxiv.org/abs/2307.13854")[WebArena]], [状态化网站], [检查网站最终状态的 functional correctness，而不是 Agent 的自我声明],
  [#link("https://arxiv.org/abs/2310.06770")[SWE-bench]], [真实软件 issue], [把自然语言目标落到代码 artifact，再用可执行测试验证],
  [#link("https://arxiv.org/abs/2404.07972")[OSWorld]], [真实桌面与应用], [为每个任务配置初始状态和 task-specific execution evaluator],
  [#link("https://arxiv.org/abs/2401.13178")[AgentBoard]], [多轮 Agent], [在最终分数之外分析 trajectory progress，使评测可以诊断],
  [#link("https://arxiv.org/abs/2406.13352")[AgentDojo]], [工具 Agent 安全], [把不可信外部内容放进环境，同时测 utility 与 prompt-injection security],
  [#link("https://arxiv.org/abs/2310.11667")[SOTOPIA]], [社会交互], [用角色、关系、目标和隐藏信息扩展到多 Agent 社会行为],
)

这些工作并不在同一条排行榜上回答同一个问题。它们更像一组可复用的实验范式：可重置环境、功能性状态检查、可执行 grader、过程诊断、对抗性环境和社会交互模拟。

== 如果从零开始，先交付五件东西

搭建 Harness 时，与其一开始追求庞大的目录，不如先让下面五个 artifact 闭环：一份明确的 case schema；一个可重置、可观察、可版本化的 environment；一个执行预算与停止条件的 runner；一条同时保存 final state 与 trajectory 的结构化记录；以及一组带测试的 graders。

当这五件东西能够稳定运行后，再增加并发、缓存、failure taxonomy、自动报告和线上采样。Case Factory 也不必一开始就用生成模型大规模造题；先把 happy path、边界状态、工具故障、权限确认和真实线上失败变成少量高质量 case，通常更有价值。

最终，一套成熟的 Harness 应该给出三类答案：

- *能力边界：* Agent 在哪些任务和环境条件下可以完成目标；
- *失败机制：* 它在哪个观察、决策或工具步骤开始偏离；
- *证据可信度：* 结果是否可复现、安全，grader 和 benchmark 是否有效。

== 结语：Harness 是 Agent 的实验室

Agent Evaluation Harness 不是排行榜外围的一层工程胶水。它决定 Agent 看见什么、能做什么、何时停下，也决定我们最后相信什么。

如果只保留一个原则，那就是：*优先检查世界，而不是相信 Agent 对世界的描述。* Final state 告诉我们事情有没有办成，trajectory 告诉我们它怎样办成；重复试验、安全约束和 benchmark audit，则告诉我们这次成功究竟是能力、偶然，还是评测漏洞。

当这些证据被保存、验证并重新流回 Case Factory，评测才不再是一场一次性的考试，而会成为 Agent 系统持续演化的实验基础设施。

== 延伸阅读

除上表工作外，还可继续阅读 #link("https://arxiv.org/abs/2311.12983")[GAIA] 对通用助手任务的设计，以及 #link("https://arxiv.org/abs/2412.05467")[BrowserGym] 对 Web Agent 环境与评测基础设施的整理。
