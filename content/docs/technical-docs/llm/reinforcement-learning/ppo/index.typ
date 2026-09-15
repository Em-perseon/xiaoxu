#import "../../../../../../config.typ": template, tufted

#show: template.with(
  title: "近端策略优化（PPO）",
)

#html.elem("a", attrs: (class: "back-link", href: "/xiaoxu/docs/technical-docs/llm/reinforcement-learning/"))[← 返回强化学习入门]

#heading(level: 1, outlined: false)[近端策略优化（PPO）]

#outline(title: [目录], depth: 3)

== 算法定位

近端策略优化（Proximal Policy Optimization, PPO）是一类基于 Actor-Critic 的策略优化算法。它使用旧策略采样轨迹，用优势估计判断动作相对于当前状态平均水平的好坏，再通过裁剪策略更新幅度来避免新策略偏离旧策略过远。

PPO 的核心思想可以概括为：

1. 用旧策略 $pi_(theta_"old")$ 与环境交互，收集状态、动作、奖励和旧策略下的动作概率；
2. 用价值网络计算 TD 残差，并通过 GAE 得到优势估计 $hat(A)_t$；
3. 用重要性采样比率把旧策略产生的数据用于评估新策略；
4. 对策略目标进行裁剪，只允许有限幅度的有利更新；
5. 同时训练价值网络，使其逼近目标回报。

== 前置知识

=== On-policy 与 off-policy

设 $mu$ 是实际产生数据的行为策略，$pi$ 是正在评估或优化的目标策略：

- *On-policy*：$mu = pi$。采样数据由当前正在优化的策略产生，数据分布和目标策略一致；
- *Off-policy*：$mu != pi$。使用另一个行为策略产生的数据来学习目标策略，例如 Q-learning 使用行为策略探索、使用贪心目标更新。

因此，判断 on-policy 或 off-policy 的关键不是比较相邻时间步的动作，而是比较“数据由谁产生”和“数据用于评估谁”。PPO 在每轮更新开始时使用旧策略采样；在这一轮内部，数据相对于旧策略是 on-policy 的，但更新后的策略不能无限复用这批数据，裁剪目标正是为了控制这种分布偏移。

=== 环境交互与 DQN 图示转写

原笔记中的交互图可转写为：

$ s_t -> a_t -> (r_t, s_(t+1)) -> a_(t+1) -> (r_(t+1), s_(t+2)) -> dots $

环境根据转移分布产生下一个状态：

$ s_(t+1) ~ p(dot | s_t, a_t), quad s_(t+2) ~ p(dot | s_(t+1), a_(t+1)) $

图中还给出了基于 Q 网络的贪心动作选择：

$ a_t = op("argmax")_a Q(s_t, a; w) $

$ a_(t+1) = op("argmax")_a Q(s_(t+1), a; w) $

$ a_(t+2) = op("argmax")_a Q(s_(t+2), a; w) $

这是 DQN 背景图，不是 PPO 的策略更新公式。其 TD 学习关系为：

$ U_t = R_t + gamma U_(t+1) $

$ Q(s_t, a_t; w) approx r_t + gamma Q(s_(t+1), a_(t+1); w) $

=== 优势函数

动作价值函数和状态价值函数分别表示：

$ Q_pi(s, a) = E[U_t | S_t = s, A_t = a] $

$ V_pi(s) = E_(A ~ pi(dot | s))[Q_pi(s, A)] $

优势函数定义为：

$ A_pi(s, a) = Q_pi(s, a) - V_pi(s) $

$A_pi(s,a)$ 描述在状态 $s$ 下选择动作 $a$ 相对于遵循当前策略的平均表现好多少：

- $A_pi(s,a) > 0$：该动作优于当前状态下的平均动作；
- $A_pi(s,a) < 0$：该动作劣于平均水平；
- $A_pi(s,a) approx 0$：该动作没有明显的相对优势。

使用优势函数而不是直接使用 $Q(s,a)$ 有三个好处：

1. *降低方差*：减去状态基线 $V(s)$ 后，更新信号关注相对优势，数值范围通常更稳定；
2. *改善探索*：策略可以提高高优势动作的概率，降低低优势动作的概率；
3. *适合 Actor-Critic*：Critic 学习 $V(s)$，Actor 使用优势估计更新策略。

== 重要性采样

当样本来自分布 $q(x)$，但目标是计算分布 $p(x)$ 下的期望时，可以插入概率比率：

$
  E_(x ~ p(x))[f(x)]
  = sum_x f(x) p(x)
  = sum_x f(x) p(x) frac(q(x), q(x))
  = sum_x f(x) frac(p(x), q(x)) q(x)
  = E_(x ~ q(x))[f(x) frac(p(x), q(x))]
$

从 $q(x)$ 采样 $N$ 个样本后，可用蒙特卡罗估计：

$ E_(x ~ p(x))[f(x)] approx frac(1, N) sum_(n=1)^N f(x_n) frac(p(x_n), q(x_n)), quad x_n ~ q(x) $

在策略梯度中，行为策略是旧策略 $pi_(theta_"old")$，目标策略是当前策略 $pi_theta$。对已采集的动作，重要性采样比率为：

$ r_t(theta) = frac(pi_theta(a_t | s_t), pi_(theta_"old")(a_t | s_t)) $

当 $r_t(theta) > 1$ 时，新策略提高了动作 $a_t$ 的概率；当 $r_t(theta) < 1$ 时，新策略降低了该动作的概率。重要性采样并不是把 on-policy 算法“变成”某种策略，而是允许使用行为策略生成的样本估计目标策略下的期望。

== GAE：广义优势估计

=== TD 残差

单步 TD 残差为：

$ delta_t = r_t + gamma V(s_(t+1)) - V(s_t) $

它表示即时奖励加上下一状态价值的折扣估计，与当前状态价值估计之间的差异。单步 TD 的方差较低，但只利用一步信息，可能存在较大偏差。

=== 多步估计与偏差—方差权衡

通过累加未来多个时间步的 TD 残差，可以获得更充分的长期信息。例如：

- 两步估计：$delta_t + gamma lambda delta_(t+1)$；
- 三步估计：$delta_t + gamma lambda delta_(t+1) + (gamma lambda)^2 delta_(t+2)$。

距离当前时刻越远，TD 残差的权重越小。$lambda$ 是平滑因子，控制偏差与方差之间的权衡：

- $lambda = 0$：只使用单步 TD，方差较低但偏差可能较大；
- $lambda = 1$：接近蒙特卡罗回报，偏差较低但方差可能较大；
- $0 < lambda < 1$：在两者之间折中。

=== GAE 公式

无限时间范围下的 GAE 为：

$ hat(A)_t^("GAE"(gamma, lambda)) = sum_(l=0)^infinity (gamma lambda)^l delta_(t+l) $

其中：

$ delta_(t+l) = r_(t+l) + gamma V(s_(t+l+1)) - V(s_(t+l)) $

在长度为 $T$ 的有限轨迹中，通常截断为：

$ hat(A)_t = sum_(l=0)^(T-t-1) (gamma lambda)^l delta_(t+l) $

将 TD 残差展开，也可以得到有限轨迹的回报形式：

$
  hat(A)_t = -V(s_t) + r_t + gamma r_(t+1) + dots + gamma^(T-t-1) r_(T-1) + gamma^(T-t) V(s_T)
$

这里最高幂次取决于从 $t$ 到轨迹末端的步数。原笔记中出现的 $T-t+1$ 形式与该有限求和范围不一致，应按轨迹边界重新确认。

== PPO 的策略目标

=== 未裁剪的代理目标

使用重要性采样比率后，策略代理目标（surrogate objective）为：

$ L^"CPI"(theta) = E_t[ r_t(theta) hat(A)_t ] $

其中：

$ r_t(theta) = frac(pi_theta(a_t | s_t), pi_(theta_"old")(a_t | s_t)) $

如果直接最大化 $L^"CPI"$，当优势为正时，模型可能无限提高该动作的概率；当优势为负时，也可能过度降低该动作的概率。过大的策略变化会使重要性采样估计失真，并造成训练不稳定。

=== 裁剪目标

PPO 将比率限制在区间 $[1 - epsilon, 1 + epsilon]$ 附近：

$
  L^"CLIP"(theta)
  = E_t[
    min(
      r_t(theta) hat(A)_t,
      op("clip")(r_t(theta), 1 - epsilon, 1 + epsilon) hat(A)_t
    )
  ]
$

裁剪对正负优势的作用不同：

- 当 $hat(A)_t > 0$ 时，提高该动作概率是有利的，但比率超过 $1 + epsilon$ 后不再继续奖励；
- 当 $hat(A)_t < 0$ 时，降低该动作概率是有利的，但比率低于 $1 - epsilon$ 后不再继续奖励。

因此，裁剪项会阻止一次更新把策略推得太远。$epsilon$ 是裁剪范围超参数，具体取值需要结合任务、批次大小和学习率调节。

=== KL 惩罚形式

原笔记还记录了 PPO 的 KL 惩罚变体：

$
  L^"KLPEN"(theta)
  = E_t[
    frac(pi_theta(a_t | s_t), pi_(theta_"old")(a_t | s_t)) hat(A)_t
    - beta op("KL")[pi_(theta_"old")(dot | s_t), pi_theta(dot | s_t)]
  ]
$

第一项鼓励策略选择高优势动作，第二项惩罚新旧策略分布之间的 KL 散度。裁剪形式和 KL 惩罚形式都是限制策略更新幅度的方法；实际 PPO 实现通常更常见的是裁剪目标。

注意：上面的 $L^"CPI"$、$L^"CLIP"$ 和 $L^"KLPEN"$ 是需要最大化的目标。如果使用深度学习框架的梯度下降接口，通常将它们取负后作为 actor loss。

== Critic：价值网络损失

价值网络用 $V_theta(s_t)$ 估计状态价值，并拟合一个目标值 $V_t^"targ"$：

$ L^"value"(theta) = (V_theta(s_t) - V_t^"targ")^2 $

常见的目标值可以由 GAE 和旧价值估计构造：

$ V_t^"targ" = hat(A)_t + V_(theta_"old")(s_t) $

也可以直接使用折扣回报或其他 bootstrapped return。Critic 通过最小化价值损失更新；Actor 则通过最大化裁剪代理目标更新。两者可以共享部分特征提取层，也可以使用完全独立的网络。

== PPO 算法流程

=== 单轮训练流程

1. 保存当前策略参数作为旧策略参数 $theta_"old"$；
2. 使用 $pi_(theta_"old")$ 在环境中运行 $T$ 个时间步，收集 $(s_t, a_t, r_t)$ 以及旧策略的 log probability；
3. 使用 Critic 估计 $V(s_t)$，计算 TD 残差；
4. 从后往前递推 GAE，得到 $hat(A)_1, ..., hat(A)_T$；
5. 根据 $V_t^"targ" = hat(A)_t + V_(theta_"old")(s_t)$ 构造价值目标；
6. 将轨迹打乱并切分成若干 minibatch；
7. 在固定的这批数据上进行若干个 epoch 的 actor/critic 更新：
   - 计算新策略概率与旧策略概率的比率 $r_t(theta)$；
   - 最大化 $L^"CLIP"(theta)$，或最小化其相反数；
   - 最小化 $L^"value"(theta)$；
8. 完成若干 epoch 后，将新策略复制为下一轮的旧策略，重新采样。

=== 原笔记算法图的文字化

原图中的伪代码可写成：

```text
Algorithm 1: PPO, Actor-Critic Style

for iteration = 1, 2, ... do
    for epoch = 1, 2, ..., N do
        Run policy pi_(theta old) in environment for T timesteps
        Compute advantage estimates hat(A)_1, ..., hat(A)_T
    end for

    Optimize surrogate L with respect to theta,
    using K epochs and minibatch size M <= N T
    theta old <- theta
end for
```

原图将内层循环标为 “actor”，这里按 PPO 训练含义改写为 “epoch”：内层循环重复利用已采集 rollout 做多轮 minibatch 更新，而不是重新定义一个 Actor 网络。

== LLM 中的 PPO 对齐

在大语言模型中，强化学习的基本元素可以映射为：

#table(
  columns: (1.1fr, 2.4fr),
  align: (left, left),
  inset: 8pt,
  stroke: 0.6pt + rgb("d8dee8"),
  table.header(
    [*强化学习概念*],
    [*LLM 中的对应物*],
  ),
  [环境], [系统或任务定义。],
  [智能体], [待训练的大语言模型。],
  [状态 $s_t$], [用户 prompt 与已经生成的 token 前缀 $o_<t$。],
  [动作 $a_t$], [基于当前前缀生成下一个 token $o_t$。],
  [策略 $pi_theta$], [模型对下一个 token 的条件概率分布 $pi_theta(o_t | q, o_<t)$。],
  [奖励], [奖励模型分数，以及对参考模型偏离程度的 per-token KL 惩罚。],
  [回报], [从当前 token 开始累积的折扣奖励。],
  [价值函数], [对当前 token 前缀或状态未来回报的估计。],
)

对于 prompt $q$ 和已经生成的前缀 $o_<t$，LLM 的一步交互可以写成：

$ s_t = (q, o_<t), quad a_t = o_t, quad pi_theta(a_t | s_t) = pi_theta(o_t | q, o_<t) $

动作价值函数 $Q(s_t, o_t)$ 衡量在当前前缀下选择 token $o_t$ 的长期收益；状态价值函数 $V(s_t)$ 衡量当前前缀在当前策略下的平均长期收益；优势函数仍然是：

$ A(s_t, o_t) = Q(s_t, o_t) - V(s_t) $

=== LLM 中的奖励与 KL 惩罚

LLM 对齐通常同时使用奖励模型和参考模型。奖励模型给出回答质量分数；参考模型通常是训练开始时的 SFT 模型，用于约束策略不要偏离原始语言分布太远。一个常见的 per-token 奖励形式为：

$
  r_t = r_phi(q, o_<=t)
  - beta log frac(
    pi_theta(o_t | q, o_<t),
    pi_"ref"(o_t | q, o_<t)
  )
$

其中 $r_phi$ 表示奖励模型的输出，$pi_"ref"$ 表示冻结的参考模型，$beta$ 是 KL 惩罚系数。工程实现中，奖励模型的整体分数通常只在响应结束位置加入，而 KL 惩罚则作用于每个生成 token：

$ op("KL")_t = log pi_theta(o_t | q, o_<t) - log pi_"ref"(o_t | q, o_<t) $

$ r_t^"non-score" = - beta op("KL")_t $

如果奖励模型只产生一个序列级分数 $op("score")$，可以在响应最后一个有效 token 的位置加上该分数：

```python
kl = logprobs - ref_logprobs
non_score_reward = -args.kl_coef * kl
rewards = non_score_reward.clone()
actual_start = torch.arange(rewards.size(0), device=rewards.device)
actual_end = torch.where(
    sequence_lengths_p1 < rewards.size(1),
    sequence_lengths_p1,
    sequence_lengths,
)
rewards[[actual_start, actual_end]] += scores
```

这里的参考模型 KL 与 PPO 代理目标中的新旧策略比率是两个不同概念：

- $pi_(theta_"old")$：当前 PPO 轮次采样时的旧策略，用于构造 $r_t(theta)$ 的分母；
- $pi_"ref"$：训练开始时或指定检查点的参考模型，用于控制 LLM 偏离初始行为的程度。

=== 四个主要模型

LLM PPO 实现通常需要以下四类模型或模型角色：

#table(
  columns: (1.25fr, 2.25fr),
  align: (left, left),
  inset: 8pt,
  stroke: 0.6pt + rgb("d8dee8"),
  table.header(
    [*模型角色*],
    [*作用*],
  ),
  [`policy_model` / active model], [正在训练的策略模型，提供 token log probability。],
  [`ref_model`], [冻结的参考模型，提供参考 token log probability 和 KL 惩罚。],
  [`value_model`], [Critic，按 token 位置估计状态价值。],
  [`reward_model`], [根据 prompt 与回答输出奖励分数，通常用于回答末端。],
)

一次 rollout 的主要数据流可以概括为：

```python
for batch_prompt in prompt_dataset:
    batch_response = active_model.generate(batch_prompt)
    batch_data = concat(batch_prompt, batch_response)

    batch_scores = reward_model(batch_data)
    batch_all_probs, batch_probs, batch_all_values = active_model.forward_pass(batch_data)
    ref_all_probs, ref_probs, _ = ref_model.forward_pass(batch_data)

    kls = compute_KL(batch_all_probs, ref_all_probs)
    rewards = compute_rewards(batch_scores, kls)
    advantages = compute_advantages(batch_all_values, rewards)
    returns = advantages + batch_all_values
```

对于带 padding 的 batch，计算奖励和价值时需要根据 `attention_mask`、`context_length` 以及最后一个非 padding token 的位置屏蔽无效位置。奖励模型通常取最后一个有效 response token 的 score；价值模型则保留 response 区间内每个 token 的 value。

=== GAE 的 LLM 实现

LLM 场景下 GAE 仍然沿 response token 维度从后往前递推。伪代码如下：

```python
lastgaelam = 0
advantages_reversed = []
gen_length = responses.shape[1]

for t in reversed(range(gen_length)):
    nextvalues = values[:, t + 1] if t < gen_length - 1 else 0.0
    delta = rewards[:, t] + args.gamma * nextvalues - values[:, t]
    lastgaelam = delta + args.gamma * args.lam * lastgaelam
    advantages_reversed.append(lastgaelam)

advantages = torch.stack(advantages_reversed[::-1], dim=1)
returns = advantages + values
advantages = masked_whiten(advantages, ~padding_mask)
advantages = torch.masked_fill(advantages, padding_mask, 0)
```

这里的 `delta` 对应单步 TD 残差：

$ delta_t = r_t + gamma V(s_(t+1)) - V(s_t) $

`returns = advantages + values` 是由优势估计和价值估计构造出的 Critic 训练目标。对 padding 位置做 mask 是 LLM PPO 实现与普通固定长度环境实现的重要区别。

=== Actor 与 Critic 的实现损失

在代码中，通常使用梯度下降，因此策略目标会先取负号。给定旧策略 log probability `mb_logprobs`、当前策略 log probability `new_logprobs` 和优势 `mb_advantage`：

```python
logprobs_diff = new_logprobs - mb_logprobs
ratio = torch.exp(logprobs_diff)

pg_losses = -mb_advantage * ratio
pg_losses2 = -mb_advantage * torch.clamp(
    ratio,
    1.0 - args.cliprange,
    1.0 + args.cliprange,
)
pg_loss_max = torch.max(pg_losses, pg_losses2)
pg_loss = masked_mean(pg_loss_max, ~padding_mask[micro_batch_inds])
```

其中 `ratio = exp(new_logprobs - mb_logprobs)` 等价于：

$ r_t(theta) = frac(pi_theta(a_t | s_t), pi_(theta_"old")(a_t | s_t)) $

Critic 的价值损失可以使用 value clipping，避免价值网络一次更新过大：

```python
vpred = vpred_temp[:, context_length - 1 : -1].squeeze(-1)
vpred = torch.masked_fill(vpred, padding_mask_p1[micro_batch_inds], 0)
vpredclipped = torch.clamp(
    vpred,
    mb_values - args.cliprange_value,
    mb_values + args.cliprange_value,
)
vf_losses1 = torch.square(vpred - mb_return)
vf_losses2 = torch.square(vpredclipped - mb_return)
vf_loss_max = torch.max(vf_losses1, vf_losses2)
vf_loss = 0.5 * masked_mean(
    vf_loss_max,
    ~padding_mask_p1[micro_batch_inds],
)
```

最终损失通常是：

```python
loss = pg_loss + args.vf_coef * vf_loss
loss.backward()
optimizer.step()
optimizer.zero_grad()
```

这对应数学形式：

$ L_"total" = L_"actor" + c_"vf" L_"value" $

其中 actor loss 已经包含负号，因而整体使用梯度下降时等价于最大化 PPO 的裁剪代理目标。

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
  [$pi_(theta_"old")$], [采样轨迹时使用的旧策略。],
  [$pi_"ref"$], [冻结的参考 LLM，用于计算 per-token KL 惩罚。],
  [$r_phi$], [奖励模型对 prompt—response 的评分函数。],
  [$r_t(theta)$], [新策略相对旧策略的动作概率比率。],
  [$G_t$], [从时间步 $t$ 开始的折扣回报。],
  [$V_phi(s_t)$], [Critic 对当前状态未来回报的估计。],
  [$A_t$], [实际回报相对于 Critic 预期的相对优势。],
  [$hat(A)_t$], [对动作相对优势的估计，PPO 中通常由 GAE 计算。],
  [$delta_t$], [一步 TD 残差。],
  [$gamma$], [折扣因子，控制未来奖励的权重。],
  [$lambda$], [GAE 平滑因子，控制偏差—方差权衡。],
  [$epsilon$], [PPO 裁剪范围超参数。],
  [$beta$], [KL 惩罚形式中的惩罚系数。],
  [$c_"vf"$], [价值损失在总损失中的权重。],
)

== 小结

PPO 将 Actor-Critic、GAE 和重要性采样组合起来：Critic 提供价值估计和优势信号，重要性采样允许用旧策略数据评估新策略，裁剪目标则限制新旧策略之间的变化。在 LLM 对齐中，还需要额外维护冻结的参考模型和奖励模型，并将 per-token KL 惩罚与奖励模型分数合成为 token 级奖励。实现重点不在某一个单独公式，而在于保持以下数据关系一致：轨迹由旧策略采样，概率比率使用同一批动作的旧概率作分母，参考模型只用于 KL 约束，优势和价值目标在更新前固定，padding 位置不参与损失，策略完成若干 epoch 更新后再重新采样。
