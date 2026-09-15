#import "../../../../../../config.typ": template, tufted

#show: template.with(title: "On-Policy Distillation（OPD）")

#html.elem("a", attrs: (class: "back-link", href: "/xiaoxu/docs/technical-docs/llm/reinforcement-learning/"))[← 返回强化学习入门]

#heading(level: 1, outlined: false)[On-Policy Distillation（OPD）]

#outline(title: [目录], depth: 3)

在 #link("../llm-actor-critic/")[LLM 中的 Actor-Critic] 中，我们讨论了一个问题：模型经历很长的搜索或推理链，最后却只拿到一次“答案正确／错误”的奖励。这个结果能告诉模型整条路径是否成功，却很难告诉它中间哪一步值得保留、哪一步应该改变。

On-Policy Distillation（在策略蒸馏，简称 OPD）提供了另一种训练信号：*student 先走自己的轨迹，再让 teacher 在 student 实际到达的状态上提供下一 token 的分布。* student 学习的是“如果高手现在接手我这份草稿，会如何继续”，而不仅仅是背诵高手已经写好的答案。

== Student 自己走，Teacher 在这些前缀上指导

设 $pi_theta$ 是待训练的 student，$pi_"T"$ 是冻结的 teacher。对于 prompt $q$，student 生成回答 $o$：

$ o ~ pi_theta(dot | q), quad s_t = (q, o_<t) $

然后将同一段 prompt 和 student 前缀交给 teacher，得到：

$ pi_"T"(dot | s_t) = pi_"T"(dot | q, o_<t) $

两者看到的是同一个前缀，但对接下来生成什么可能有不同判断。蒸馏就是用这个差异训练 student。

例如，一个关于 $sqrt(2)$ 无理性的证明，student 已写出：

```text
Prompt：证明 sqrt(2) 是无理数。

Student 的草稿：
1. 假设 sqrt(2) = p / q。
2. 两边平方，得到 p² = 2q²。
3. 接下来……
```

teacher 在第三步看到的仍然是这份 student 草稿，而不是自己重新生成的完整证明。它可以在这个前缀下给后续 token 分配概率，例如更倾向讨论奇偶性、互质条件与矛盾。

这些自然语言“步骤”只是便于理解。对自回归 LLM，监督通常发生在每个 token 上，并不要求 teacher 单独写出一条“这一步正确”的评语。

== 为什么叫 On-policy

这里的 on-policy 指*训练前缀由当前 student 的策略产生*。它不是指 teacher 和 student 相同，也不是指 teacher 的所有答案都正确。

普通的 teacher-generated SFT 往往是：

```text
Teacher 生成：A -> B -> C
Student 学习：在 A 后生成 B，在 A、B 后生成 C
```

但 student 独立运行时可能走成：

```text
Student 生成：A -> X -> Y
```

它在训练中很少见到 X、Y 这样的前缀，因此可能不懂如何继续或纠错。早期偏差还可能随着序列增长不断累积。

OPD 则在 student 自己生成的 A、X、Y 上查询 teacher：

```text
Student 到达 A：Teacher 给出 A 下的下一 token 分布。
Student 到达 X：Teacher 给出 A、X 下的下一 token 分布。
Student 到达 Y：Teacher 给出 A、X、Y 下的下一 token 分布。
```

因此，训练更贴近 student 部署时会遇到的状态。这是在降低分布偏移，而不是保证训练与部署分布永远完全一致：student 每轮更新后分布会变化，部署任务也可能不同。GKD 将这种在自生成序列上学习 teacher 反馈的做法形式化，并允许选择不同的分布差异目标。#footnote[#link("https://arxiv.org/abs/2306.13649")[On-Policy Distillation of Language Models: Learning from Self-Generated Mistakes（GKD，ICLR 2024）]。]

== 从结果奖励到密集反馈

以只有终局奖励的 Search Agent 为例：

```text
question
  -> search
  -> read
  -> reason
  -> final answer
  -> verifier：reward = 1 / 0
```

RL 优化任务回报：

$ J_"RL"(theta) = E_(o ~ pi_theta(dot | q))[R(q, o)] $

在这种设置里，一次成功不代表每个搜索动作都必要；一次失败也不代表前面的每一步都错了。return、Critic 和 GAE 可以构造训练信号，但具体动作的 credit assignment 仍然困难。#footnote[这是因为Critic 不是“知道每一步真正贡献是多少”，它只是学习一个预测器，预测未来回报。]

OPD 的反馈来自 teacher 在相同前缀下的分布。可以把它想象成老师查看学生自己的草稿，在许多位置给出继续写下去的建议。Thinking Machines 的实现将 student 和 teacher 对已采样 token 的 log probability 差异转成逐 token 的训练权重。#footnote[#link("https://thinkingmachines.ai/blog/on-policy-distillation/")[Thinking Machines：On-Policy Distillation]，下文的 sampled-token reverse KL 流程参考该实现。]

*密集反馈不等于正确性标签。* teacher 可能在错误前提下继续写出符合上下文的内容；teacher 也可能判断失误。因此，OPD 缓解了对终局奖励的依赖，并没有从根本上消除任务验证和因果归因问题。

== Reverse KL：让 Student 靠近 Teacher

=== 分布层面的目标

OPD 是一类训练方式，不只有一种 loss。下面用 reverse KL 说明：

$
  D_"KL"(pi_theta || pi_"T"; s_t)
  = sum_(a in cal(V)) pi_theta(a | s_t)
    log frac(pi_theta(a | s_t), pi_"T"(a | s_t))
$

其中 $cal(V)$ 是词表。这个 KL 比较的是*同一状态下* student 与 teacher 的完整下一 token 分布。序列上的局部蒸馏目标可以写成：

$
  cal(L)_"OPD"(theta)
  = E_((q ~ cal(D)), (o ~ pi_theta(dot | q)))[
    frac(1, |o|) sum_(t=1)^|o|
    D_"KL"(pi_theta || pi_"T"; s_t)
  ]
$

外层轨迹来自 student，内层比较来自同一前缀下的两个分布。这两个选择是不同维度：on-policy 描述采样来源，reverse KL 描述 loss 的方向。

普通 teacher-generated SFT 使用 teacher 样本的交叉熵，在相应前缀上与 forward KL 方向相关；也可以在 student 前缀上使用其他 divergence。MiniLLM 研究了 reverse KL 的 on-policy 优化，以减少 student 对 teacher 低概率区域的过度覆盖。#footnote[#link("https://arxiv.org/abs/2306.08543")[MiniLLM（ICLR 2024）]。]

=== 只给已采样 Token 打分

不一定需要保存 teacher 的整个词表 logits。对 student 已经采样的 token $o_t$，可以计算：

$ k_t = log pi_theta(o_t | s_t) - log pi_"T"(o_t | s_t) $

在固定状态 $s_t$ 下，若 $o_t$ 从 student 分布采样，那么：

$ E_(o_t ~ pi_theta(dot | s_t))[k_t] = D_"KL"(pi_theta || pi_"T"; s_t) $

*完整 KL 非负，但单个 token 的估计 $k_t$ 可以为负。* 所以不能把一处正负 log probability 差直接解释成“这一步错误／正确”。

Thinking Machines 用局部的负 log probability 差作为 advantage-like 权重：

$ hat(A)_t^"OPD" = log pi_"T"(o_t | s_t) - log pi_"old"(o_t | s_t) $

其中 $pi_"old"$ 是本批轨迹采样时的 student。这是局部蒸馏权重，区别于通过 return 和 Critic 构造的长期回报优势。该实现只优化即时 token 信号（折扣为零），因而不要求独立的 Critic 或 GAE。

=== 一个概率例子

以下数值仅作示意：

```text
某个固定前缀下，Student 采样了 token a。

Student：P(a) = 0.10
Teacher：P(a) = 0.40
权重：log(0.40) - log(0.10) = log(4) ≈ +1.386
局部梯度倾向提高 Student 对 a 的概率。

另一个 token b：
Student：P(b) = 0.30
Teacher：P(b) = 0.05
权重：log(0.05) - log(0.30) = log(1/6) ≈ -1.792
局部梯度倾向降低 Student 对 b 的概率。
```

teacher 对某个 token 给出很高概率并不足以决定更新方向，还要比较 student 原本的概率。两者概率一样时，这种权重为零。

== 一个搜索 Agent 的例子

任务是“谁发现了青霉素？”student 生成：

```text
search("penicillin inventor")
  -> 读取搜索结果
  -> 找到 Fleming
  -> 回答 Alexander Fleming
```

在工具调用文本的各个前缀上，teacher 可以给出生成 `penicillin`、`inventor` 等 token 的概率。如果 student 生成了过于宽泛的 `search("medicine history")`，teacher 与 student 的分布差异可以给出不同的局部训练权重。

这里不能把 teacher 的 token 概率直接当成查询质量分数。查询是否有效，还取决于搜索引擎返回什么、结果是否可靠，以及后续如何使用结果。Agent OPD 需要把工具观察纳入状态，并区分模型生成的动作 token 与外部工具返回的 token；通常只在可训练的动作位置计算 loss。

这个例子说明的是如何把 OPD 扩展到工具调用，属于应用推演，并非 Thinking Machines 博客中报告的搜索 Agent 实验。

== 训练流程与伪代码

一轮 sampled-token OPD 可以按下面的顺序执行：

1. 用当前 student 生成 rollout，并保存动作 token 的旧 log probability；
2. teacher 对相同 rollout 做前向计算，给已采样 token 打分；
3. 构造逐 token 的蒸馏权重，并屏蔽 padding、prompt 和工具观察；
4. 用当前 student 重算 log probability，形成策略梯度 loss；
5. 更新 student 后重新采样。

下面是抽象伪代码，`rollout`、`action_logprobs` 和 `action_mask` 表示训练系统需要提供的接口，而不是某个库的可直接运行 API：

```python
with torch.no_grad():
    rollout = student.sample(prompts)
    old_logprobs = rollout.action_logprobs
    mask = rollout.action_mask
    teacher_logprobs = teacher.action_logprobs(rollout)
    advantages = (teacher_logprobs - old_logprobs).detach()

new_logprobs = student.action_logprobs(rollout)
ratio = torch.exp(new_logprobs - old_logprobs)
loss = -(ratio * advantages * mask).sum() / mask.sum()

optimizer.zero_grad()
loss.backward()
optimizer.step()
```

teacher 和采样权重不参与反向传播。上面的 importance-sampling surrogate 在采样策略附近提供局部更新；如果多轮复用 rollout，需要考虑策略漂移，可使用 clipping 或其他稳定化方式。OPD 本身并不要求一定采用 PPO clipping。

还要区分两种实现：有完整分布时，可以在已采样前缀上对 KL loss 直接求导；只有 sampled-token log probability 时，需要正确构造 score-function 梯度。简单地把 `new_logprobs - teacher_logprobs` 求均值后反向传播，并不能自动得到上面这个采样目标所需的梯度。对局部状态 KL 的完整梯度求期望时，常数基线项可以消去，剩余项与 log probability 差加权的策略梯度对应；若还要优化未来访问状态，目标与梯度会更复杂。

实现时，teacher 与 student 的 token 位置必须按 causal shift 对齐；逐 token KL 还需要一致的 tokenizer 和词表，或额外的跨词表对齐。verl 提供了 sampled-token 和分布级蒸馏等实现选项。#footnote[#link("https://verl.readthedocs.io/en/latest/algo/opd.html")[verl：On-Policy Distillation 文档]。]

== 和 RL、普通蒸馏放在一起看

#table(
  columns: (1fr, 1.5fr, 1.5fr, 1.5fr),
  align: (left, left, left, left),
  inset: 8pt,
  stroke: 0.6pt + rgb("d8dee8"),
  table.header([*维度*], [*Teacher-generated SFT*], [*终局奖励 RLVR*], [*OPD*]),
  [轨迹来源], [Teacher／外部数据], [Student], [Student],
  [主要信号], [目标 token／Teacher 分布], [环境或 Verifier 的结果奖励], [相同前缀下的 Teacher 分布],
  [信号粒度], [逐 token，密集], [通常序列末端，稀疏], [逐 token，密集],
  [核心用途], [示范与能力初始化], [按任务回报探索策略], [在自生成状态上转移 Teacher 行为],
  [主要困难], [前缀分布偏移], [探索成本、延迟奖励和归因], [Teacher 可靠性、能力差距和打分成本],
)

这张表比较的是特定设置，而非所有 RL：RL 可以使用密集奖励，也可以由 teacher 充当奖励模型。OPD 同样包含 student 的采样探索，只是训练方向主要受 teacher 分布约束。

PRM 也会对过程提供密集反馈，但它通常输出过程步骤的标量评分；OPD 提供下一 token 的分布或 log probability。RLVR、PRM 和 OPD 是可组合的信号来源，不是必须依次经历的三阶段路线。

== 能力差距、Teacher 错误与采样覆盖

teacher 需要在目标任务上有可学习的优势，但“模型越大，蒸馏越有效”不是普遍规律。teacher 也可以是同一模型在微调前保存的版本，用于恢复某种已有行为。Thinking Machines 讨论了用先前模型恢复领域训练后受损的指令遵循能力。

影响训练效果的因素包括：

- *Teacher 的错误：* 模仿其分布也可能继承错误、偏见或不合适的表达方式；
- *Student 的容量：* 无法完全表达 teacher 的策略时，需要选择适合的 divergence、任务或课程；
- *采样覆盖：* Student 几乎从不生成某种关键行为时，纯 on-policy 局部学习可能很难接触到它；
- *计算成本：* Student rollout、Teacher 前向打分、Student 训练都消耗资源，收益取决于任务和系统实现。

可以先通过 SFT 建立基础能力，再用 OPD 训练 student 自己会访问的前缀。也可以研究选择性蒸馏、任务奖励与蒸馏权重组合等方法，但不能把它们当成所有 OPD 都必需的组件。

On-Policy Delta Distillation 则使用 teacher 与其推理微调前基础模型之间的差异作为信号，尝试转移微调带来的能力变化；它不是简单比较 teacher 与 student 谁更强。#footnote[#link("https://arxiv.org/abs/2607.15161")[On-Policy Delta Distillation]，2026 年预印本。]

== 与 Agent RL 结合

一个值得探索的流程是：

```text
SFT 建立基本能力
    -> Student 生成自己的轨迹
    -> OPD 提供 Teacher 的密集反馈
    -> 环境奖励驱动 RL 探索
    -> 在独立任务上验证效果
```

也可以用一个混合目标表示：

$ J(theta) = E[R(q, o)] - eta E[sum_t D_"KL"(pi_theta || pi_"T"; s_t)] $

其中 $eta$ 控制 teacher 约束的强度。这是组合思路的示意公式，具体实现需要处理目标尺度、采样和优化稳定性。GKD 已研究蒸馏与 RL fine-tuning 的组合；但“先 OPD 再 RL”只是可选方案，不能保证每个任务都更好。

蒸馏目标鼓励接近 teacher，但 teacher 的基准分数并非 student 的数学硬上限。训练数据、初始化和任务奖励都可能改变最终能力；是否超过 teacher，需要用实际评估确认。

== 小结

OPD 的关键是把“谁生成训练轨迹”和“谁提供反馈”分开：student 产生自己实际会遇到的前缀，teacher 在这些前缀上提供密集的下一 token 信号。它让长链训练不必完全依赖最后一次对错奖励，也降低了只学习 teacher 完美轨迹带来的分布偏移。理解它时，始终区分 token 概率与正确性、局部蒸馏权重与长期优势、teacher 模仿与任务回报优化。

更多系统化讨论可参考 #link("https://arxiv.org/abs/2604.00626")[A Survey of On-Policy Distillation for Large Language Models]（2026 年持续更新的综述预印本）。
