#import "../../../../../../config.typ": template, tufted

#show: template.with(
  title: "LLM 中的 Actor-Critic",
)

#html.elem("a", attrs: (class: "back-link", href: "/xiaoxu/docs/technical-docs/llm/reinforcement-learning/"))[← 返回强化学习入门]

#heading(level: 1, outlined: false)[LLM 中的 Actor-Critic]

#outline(title: [目录], depth: 3)

在 LLM 的 RLHF、RLVR 和长链 Agent 训练中，最终奖励往往只在回答结束时出现，但策略模型和价值模型却要在每一个生成 token 或工具调用上得到训练信号。本页专门解释 terminal reward 如何通过 return 和 advantage 影响 Actor 与 Critic，以及为什么这最终会变成 credit assignment 问题。

== Terminal reward 如何影响每个 token 的 Actor/Critic 更新

这是 PPO 在 LLM 的 RLHF 或 RLVR 中最核心、也最容易混淆的机制之一：最终奖励通常只在回答结束时出现，但 Actor 和 Critic 却要在每一个生成 token 上得到训练信号。

这里需要先区分一件事：terminal reward 并不是通过环境或搜索过程直接反向传播到每一个动作，而是先被转换为 return，再由 Critic 形成价值目标、由 Actor 形成优势加权的策略梯度。

=== 1. 先建立 PPO 的世界观

PPO 包含两个相互配合的网络。

*Actor（策略模型）。* Actor 回答“现在应该输出什么 action”。在 LLM 中，一个 action 就是下一个 token。给定状态 $s_t$，策略模型给出生成动作 $a_t$ 的概率：

$ pi_theta(a_t | s_t) $

例如，模型可能逐步生成：

```text
Question:
2 + 2 = ?

Actor:
token 1: "答案"
token 2: "是"
token 3: "4"
```

*Critic（价值模型）。* Critic 回答“从现在开始，未来大概能拿到多少 reward”。它不负责选择 token，而是估计当前状态的未来回报：

$ V_phi(s_t) $

例如，当当前状态是“我已经搜索到了一个网页”时，Critic 可能预测从这个状态继续行动最终获得的 reward 为 $0.7$。因此，Critic 学习的是“哪些状态更容易成功”，Actor 学习的是“在这些状态下应该采取哪些动作”。

=== 2. 一个带 terminal reward 的完整 trajectory

以 Search Agent 为例，一条高层 trajectory 可以写成：

```text
s_0: 用户问题

a_1: search("Nobel physics 2023")
s_1: 搜索结果

a_2: read(document)
s_2: 读取到候选资料

a_3: 生成答案 "Pierre Agostini"
s_3: 结束
```

最终 verifier 判断答案正确，并给出：

```text
reward = 1
```

在这个例子中，中间的搜索和阅读步骤没有即时的外部 reward，唯一明确的任务奖励出现在 trajectory 末端。这就是 LLM agent 训练中的 delayed reward。

=== 3. PPO 并不是把 reward 直接倒着传

很多人会把这个过程理解成“最后得到 reward=1，然后直接把 1 传回 $a_1$、$a_2$ 和 $a_3$”。严格来说并不是这样。PPO 先计算从每个时间步开始的折扣回报：

$ G_t = sum_(k=t)^T gamma^(k-t) r_k $

如果只有最后一步有 reward：

```text
r_1 = 0
r_2 = 0
r_3 = 1
```

并且暂时取 $gamma = 1$，则：

```text
G_1 = 1
G_2 = 1
G_3 = 1
```

也就是说，每个时间步都获得了“这条 trajectory 最终成功了”这一训练目标。若 $gamma < 1$，则更早的动作会受到更强的折扣。例如末端 reward 位于时间步 $T$ 时：

$ G_t = gamma^(T-t) r_T $

所以，terminal reward 是通过 return 间接影响早期动作的，而不是沿着环境转移图对动作本身做可微反向传播。

=== 4. Critic 学什么

Critic 的目标是让价值预测接近从当前状态开始实际得到的 return：

$ V_phi(s_t) approx G_t $

最简单的 Monte Carlo 价值损失为：

$ L_"critic"(phi) = 1 / 2 (V_phi(s_t) - G_t)^2 $

例如，某条成功 trajectory 中不同状态的 Critic 预测为：

```text
state  s_0:  V_phi(s_0) = 0.2,  G_0 = 1
state  s_1:  V_phi(s_1) = 0.5,  G_1 = 1
state  s_2:  V_phi(s_2) = 0.8,  G_2 = 1
```

Critic 会通过价值损失逐步把这些预测推向真实 return：

```text
V_phi(s_0): 0.2 -> 0.4
V_phi(s_1): 0.5 -> 0.7
V_phi(s_2): 0.8 -> 0.9
```

它最终希望学会：哪些状态通常意味着任务更可能成功，哪些状态已经偏离了正确轨迹。实际 LLM PPO 通常使用 GAE 或 bootstrapped return，而不是完全依赖 Monte Carlo return；但“Critic 拟合价值目标”的角色不变。

=== 5. Actor 如何知道 action 好不好

Actor 需要的不是绝对回报，而是动作相对于当前状态预期表现的相对好坏。因此使用优势函数：

$ A_t = G_t - V_phi(s_t) $

它回答的是：实际结果比 Critic 原本预期的结果好多少？

例如：

```text
Step 1
状态：我是否应该搜索？
Critic：V_phi(s_1) = 0.3
最终结果：答案正确，G_1 = 1
优势：A_1 = 1 - 0.3 = +0.7
```

这说明 `search()` 这个动作带来的结果比当前 Critic 的预期好，Actor 应该提高类似动作的概率。

```text
Step 2
状态：已经找到资料
Critic：V_phi(s_2) = 0.95
最终结果：答案正确，G_2 = 1
优势：A_2 = 1 - 0.95 = +0.05
```

这个动作虽然出现在成功 trajectory 中，但它没有特别超出预期，因此更新幅度应该较小。

再例如，如果答案错误、$G_t = 0$，而 Critic 预测 $V_phi(s_t) = 0.5$，那么：

$ A_t = 0 - 0.5 = -0.5 $

此时 Actor 会降低生成相应 action 的概率。

在实际 PPO 中，$hat(A)_t$ 往往由 GAE 计算，而不是直接使用 $G_t - V_phi(s_t)$。GAE 会将多个时间步的 TD 残差组合起来，但其作用仍然是为每个动作提供一个相对优势信号。

=== 6. Actor 如何更新

最简单的策略梯度损失可以写成：

$ L_"actor"(theta) = - A_t log pi_theta(a_t | s_t) $

因此：

- 如果 $A_t > 0$，最小化 loss 会提高 $pi_theta(a_t | s_t)$；
- 如果 $A_t < 0$，最小化 loss 会降低 $pi_theta(a_t | s_t)$。

例如某一步的 action 是 `search Nobel physics`，旧策略给出的概率为 $0.01$，而该动作的 advantage 为 $+0.7$，Actor 会收到提高该动作概率的梯度。相反，如果最终答案错误、优势为负，Actor 会收到降低相应 action 概率的梯度。

PPO 在此基础上加入重要性采样比率：

$ r_t(theta) = frac(pi_theta(a_t | s_t), pi_(theta_"old")(a_t | s_t)) $

并使用裁剪目标限制策略变化：

$
  L^"CLIP"(theta)
  = E_t[
    min(
      r_t(theta) hat(A)_t,
      op("clip")(r_t(theta), 1 - epsilon, 1 + epsilon) hat(A)_t
    )
  ]
$

如果旧策略给出某个 action 的概率为 $0.1$，新策略试图把它提高到 $0.9$，那么策略比率变化过大。PPO 的 clipping 会把有利更新限制在 $[1 - epsilon, 1 + epsilon]$ 附近，避免策略因为一次成功 trajectory 就发生过于激进的变化。

=== 7. 放到 LLM 的 token 级别

LLM 的 response 是由一连串 token action 组成的。例如：

```text
回答：The answer is 42

t_1: "The"
t_2: " answer"
t_3: " is"
t_4: "42"
```

最终 verifier 给出 reward=1。对每个 token，PPO 会保存其状态、动作、旧策略 log probability、价值预测和 advantage，然后在 token 维度上累积 Actor loss：

$
  L_"actor"
  = - frac(1, |o|) sum_(t=1)^|o|
    hat(A)_t log pi_theta(o_t | q, o_<t)
$

因此，计算过程看起来像：

```text
token 1 loss
+ token 2 loss
+ token 3 loss
+ token 4 loss
```

在真正的 LLM PPO 实现中，通常还会加入 per-token KL 惩罚、padding mask、GAE 和 minibatch 平均。若只有 terminal task reward，那么早期 token 得到的信号主要来自最终 return；若同时加入 KL shaping，则每个 token 还会得到与参考模型偏离程度相关的 reward。

=== 8. Critic 为什么有用

如果没有 Critic，所有成功 trajectory 都可能只得到同一个 reward：

```text
成功 trajectory：reward = 1
其中所有 action：更新信号都近似为 +1
```

这种信号太粗糙。Critic 引入了一个状态相关的 baseline，把问题从“成功了吗”变成“结果比当前状态原本预期的结果好多少”。

假设有两个 action：

```text
Action A：搜索
Critic 预测成功概率：0.9
最终成功：G = 1
Advantage：+0.1

Action B：直接猜
Critic 预测成功概率：0.1
最终成功：G = 1
Advantage：+0.9
```

两条 trajectory 都成功，但 PPO 会更强烈地奖励 Action B，因为它带来了超出预期更多的结果。这里的数值只是示意；实际 Critic 预测的是价值而不一定是严格意义上的成功概率。

=== 9. 这仍然是 credit assignment 问题

即使有了 Critic，PPO 也不一定知道一条成功 trajectory 中究竟是哪一个 action 导致了成功。它更直接得到的是：

```text
这一整条路径最终成功的可能性更高
```

如果 trajectory 是：

```text
search A
  -> search B
  -> read document
  -> generate answer
```

而最终答案正确，多个 action 可能都会获得正的 advantage。Critic 可以通过不同状态的价值预测提供更细粒度的 baseline，GAE 可以通过 TD 残差利用局部时序信息，但它们并不能自动识别每一个 action 的真实因果贡献。

因此，当 Search Agent 的 trajectory 包含 100 个 search、read、reason 和 answer step 时，Critic 必须学会判断：

> 当前这一步搜索行为，究竟让最终成功的概率增加了多少？

这正是长链 Agent 训练中最困难的 credit assignment 问题之一。

=== 10. 回传链条总结

PPO 的训练信号可以概括为：

```text
terminal reward
       |
       v
计算 return G_t
       |
       v
Critic 预测 V_phi(s_t)
       |
       v
advantage = G_t - V_phi(s_t)
       |
       +-----------------------------+
       v                             v
Actor：                         Critic：
优势为正，提高 action 概率       让 V_phi 更接近真实 return
优势为负，降低 action 概率
```

所以，PPO 并不是把 reward 直接“传回”每一个 token，而是通过 value function 建立每一步的评价，再用 advantage 指导 Actor 更新、用 return 训练 Critic。对于 LLM，action 是 token；对于 Search Agent，action 还可以是 search、read 和 answer 等高层工具调用。无论 action 粒度如何，核心机制都是相同的。

== 关键符号速查

#table(
  columns: (1.1fr, 2.4fr),
  align: (left, left),
  inset: 8pt,
  stroke: 0.6pt + rgb("d8dee8"),
  table.header(
    [*符号*],
    [*含义*],
  ),
  [$pi_theta$], [当前待优化的策略。],
  [$pi_(theta_"old")$], [采样 trajectory 时使用的旧策略。],
  [$G_t$], [从时间步 $t$ 开始的折扣回报。],
  [$V_phi(s_t)$], [Critic 对当前状态未来回报的估计。],
  [$A_t$], [实际回报相对于 Critic 预期的相对优势。],
  [$hat(A)_t$], [PPO 中通常由 GAE 得到的优势估计。],
  [$r_t(theta)$], [新策略相对旧策略的动作概率比率。],
  [$gamma$], [折扣因子。],
  [$lambda$], [GAE 平滑因子。],
  [$epsilon$], [PPO 裁剪范围超参数。],
)

== 小结

PPO 在 LLM 中的训练可以理解为一条清晰的评价链：terminal reward 先形成每一步的 return，Critic 学习预测这些 return，Actor 再根据实际结果相对于 Critic 预期的 advantage 调整 token 或工具调用的概率。这个过程并不能完美回答“究竟是哪一步 action 导致成功”，因此长链 Agent 的核心难点仍然是 credit assignment。
