#import "../../../../../../config.typ": template, tufted

#show: template.with(
  title: "群组相对策略优化（GRPO）",
)

#html.elem("a", attrs: (class: "back-link", href: "/xiaoxu/docs/technical-docs/llm/reinforcement-learning/"))[← 返回强化学习入门]

#heading(level: 1, outlined: false)[群组相对策略优化（GRPO）]

#outline(title: [目录], depth: 3)

群组相对策略优化（Group Relative Policy Optimization, GRPO）是面向大语言模型强化学习的一种策略优化方法。它保留 PPO 的裁剪代理目标，但去掉了动作价值函数或独立的 Critic，通过对同一个 prompt 采样的一组回答进行相对比较，直接构造优势估计。

== PPO 到 GRPO

=== LLM 中的基本对象

对于一个 prompt $q$，模型生成回答 $o = (o_1, o_2, ..., o_|o|)$。在 token 级强化学习中：

- 状态是 prompt 和已经生成的 token 前缀；
- 动作是生成下一个 token；
- 策略 $pi_theta$ 是模型对下一个 token 的条件概率分布；
- 奖励由奖励模型或可验证规则给出；
- 价值函数估计当前前缀继续生成的期望回报。

PPO 通常需要策略模型、参考模型、奖励模型和价值模型。价值模型为每个状态提供 $V(s_t)$，再结合 TD 残差计算 GAE 优势。

GRPO 的关键变化是：对同一个 prompt 一次采样 $G$ 个回答 $o_1, o_2, ..., o_G$，用这组回答的奖励均值和标准差作为基线，从组内相对表现直接得到优势。因此，GRPO 不再训练单独的价值模型，也不需要通过 GAE 来估计优势。

=== 框架图

#figure(caption: "PPO 与 GRPO 框架对比图（原图保留）")[
  #image("ppo-grpo-framework.webp", width: 100%)
]

图中上半部分是 PPO：策略模型生成回答后，参考模型提供 KL 约束，奖励模型产生奖励，价值模型产生 $v$，再由 GAE 得到优势 $A$。下半部分是 GRPO：策略模型针对同一个 prompt 生成一组回答，参考模型和奖励模型分别计算约束与奖励，最后通过组内计算得到 $A_1, A_2, ..., A_G$。

== GRPO 的组内相对优势

对同一个 prompt $q$，旧策略生成一组回答：

$ {o_i}_{i=1}^G ~ pi_(theta_"old")(dot | q) $

奖励模型或规则函数分别给出奖励 $r_1, r_2, ..., r_G$。GRPO 将每个回答的奖励减去组内平均奖励，再除以组内标准差：

$ A_i = frac(r_i - op("mean")({r_1, r_2, ..., r_G}), op("std")({r_1, r_2, ..., r_G})) $

也可以写成：

$ A_i = frac(r_i - overline(r), sigma_r) $

其中：

- $overline(r)$ 是同一组回答的平均奖励；
- $sigma_r$ 是同一组回答的奖励标准差；
- $A_i > 0$ 表示第 $i$ 个回答优于组内平均水平；
- $A_i < 0$ 表示第 $i$ 个回答低于组内平均水平。

这种优势估计只需要比较同一个 prompt 下的多个回答，不需要让 Critic 学习一个额外的状态价值函数。它尤其适合具有明确验证器的任务，例如数学题、代码执行和有规则答案的问题。

当组内奖励标准差接近零时，实际实现需要加入一个很小的数避免除零，或对该组进行特殊处理。

== PPO 与 GRPO 的目标函数

=== PPO 目标

PPO 对一个回答中的 token 逐步计算重要性采样比率。其目标可以写为：

$
  J^"PPO"(theta)
  = E_((q ~ P(Q)), (o ~ pi_(theta_"old")(dot | q))) [
    frac(1, |o|) sum_(t=1)^|o|
    min(
      frac(pi_theta(o_t | q, o_<t), pi_(theta_"old")(o_t | q, o_<t)) A_t,
      op("clip")(
        frac(pi_theta(o_t | q, o_<t), pi_(theta_"old")(o_t | q, o_<t)),
        1 - epsilon,
        1 + epsilon
      ) A_t
    )
  ]
$

其中 $o_<t$ 表示生成第 $t$ 个 token 之前的 token 前缀，$A_t$ 通常由价值模型和 GAE 得到。

=== GRPO 目标

GRPO 使用同一 prompt 下的 $G$ 个回答及其组内优势，目标函数可以写为：

$
  J^"GRPO"(theta)
  = E_((q ~ P(Q)), ({o_i}_(i=1)^G ~ pi_(theta_"old")(dot | q))) [
    frac(1, G) sum_(i=1)^G (
      min(
        frac(pi_theta(o_i | q), pi_(theta_"old")(o_i | q)) A_i,
        op("clip")(
          frac(pi_theta(o_i | q), pi_(theta_"old")(o_i | q)),
          1 - epsilon,
          1 + epsilon
        ) A_i
      )
      - beta cal(D)_"KL"(pi_theta || pi_"ref")
    )
  ]
$

这里 $A_i$ 是组内相对优势，$epsilon$ 是 PPO 风格的裁剪范围，$beta$ 是 KL 惩罚系数，$pi_"ref"$ 是冻结的参考模型。GRPO 仍然使用旧策略生成的数据，因此重要性采样比率的分母是 $pi_(theta_"old")$；参考模型只负责限制策略偏离初始模型的程度。

=== KL 正则项

笔记中的 KL 近似项为：

$
  cal(D)_"KL"(pi_theta || pi_"ref")
  = frac(pi_"ref"(o_i | q), pi_theta(o_i | q))
  - log frac(pi_"ref"(o_i | q), pi_theta(o_i | q))
  - 1
$

这个形式在数值上可以使用当前策略和参考策略的 log probability 计算。它会惩罚训练中的策略偏离参考模型过远，使模型在追求奖励的同时保持合理的语言分布。

== GRPO 训练流程

1. 从 prompt 数据集采样一个 batch；
2. 对每个 prompt 使用旧策略生成 $G$ 个回答；
3. 使用奖励模型或规则验证器为每个回答计算 $r_i$；
4. 在每个 prompt 对应的回答组内计算均值、标准差和优势 $A_i$；
5. 使用参考模型计算 KL 约束；
6. 使用 GRPO 裁剪目标更新策略模型；
7. 重复采样新的回答组并继续训练。

与 PPO 相比，GRPO 的主要变化如下：

#table(
  columns: (1.15fr, 1.55fr, 1.55fr),
  align: (left, left, left),
  inset: 8pt,
  stroke: 0.6pt + rgb("d8dee8"),
  table.header(
    [*组件*],
    [*PPO*],
    [*GRPO*],
  ),
  [回答采样], [通常逐条处理 rollout。], [同一 prompt 采样一组回答。],
  [优势估计], [价值模型 + GAE。], [组内奖励均值和标准差。],
  [价值模型], [需要独立 Critic。], [去掉独立价值模型。],
  [策略目标], [裁剪代理目标。], [组内平均的裁剪代理目标。],
  [KL 约束], [可以作为策略目标中的惩罚项。], [通常显式加入参考模型 KL 惩罚。],
)

== 为什么 GRPO 可以去掉 Critic

PPO 中，Critic 的重要作用是为状态提供基线 $V(s)$，从而把动作价值转换为优势：

$ A(s, a) = Q(s, a) - V(s) $

GRPO 使用同一个 prompt 生成的回答组作为比较集合。对于固定的 prompt，组内平均奖励充当了一个经验基线：

$ A_i approx frac(r_i - overline(r), sigma_r) $

因此，GRPO 不需要额外拟合 $V(s)$。代价是每个 prompt 需要生成多个回答，训练计算量从“维护价值模型”转移为“扩大同 prompt 的采样组”。组大小 $G$ 越大，组内比较通常越充分，但生成成本和显存占用也越高。

== 关键符号速查

#let symbol-table = table(
  columns: (1.1fr, 2.4fr),
  align: (left, left),
  inset: 8pt,
  stroke: 0.6pt + rgb("d8dee8"),
  table.header(
    [*符号*],
    [*含义*],
  ),
  [$q$], [一个 prompt。],
  [$o_i$], [同一个 prompt 下第 $i$ 个采样回答。],
  [$G$], [每个 prompt 采样的回答数量。],
  [$r_i$], [第 $i$ 个回答的奖励。],
  [$A_i$], [由组内奖励归一化得到的相对优势。],
  [$pi_theta$], [当前待优化的策略模型。],
  [$pi_(theta_"old")$], [生成回答组时使用的旧策略。],
  [$pi_"ref"$], [冻结的参考模型。],
  [$epsilon$], [策略比率裁剪范围。],
  [$beta$], [KL 惩罚系数。],
)

#context {
  if target() == "html" {
    html.elem("div", attrs: (class: "grpo-symbol-table"))[#symbol-table]
  } else {
    align(center)[#symbol-table]
  }
}

== 小结

GRPO 可以看作面向 LLM 的 PPO 变体：它保留重要性采样和裁剪策略更新，通过同一 prompt 下多个回答的相对奖励直接构造优势，省去了价值模型与 GAE。其核心代价是每个 prompt 需要生成一组回答；在奖励可验证、回答之间容易比较的任务中，这种组内相对优化尤其自然。
