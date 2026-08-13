#import "../../../../../../config.typ": template, tufted

#show: template.with(
  title: "DQN 算法",
)

#html.elem("a", attrs: (class: "back-link", href: "/xiaoxu/docs/technical-docs/llm/reinforcement-learning/"))[← 返回强化学习入门]

#heading(level: 1, outlined: false)[DQN 算法]

#outline(title: [目录], depth: 3)

== 采样流程

DQN 在每个时刻观察状态 $s_t$，选择 Q 值最大的动作：

$ a_t = op("argmax")_a Q(s_t, a, w) $

执行动作后，环境给出奖励 $r_t$，并按照状态转移分布产生下一个状态：

$ s_(t+1) ~ p(dot | s_t, a_t) $

随后在新状态中继续选择动作：

$ a_(t+1) = op("argmax")_a Q(s_(t+1), a, w) $

因此，采样过程可以写成：

$ s_t -> a_t -> (r_t, s_(t+1)) -> a_(t+1) -> (r_(t+1), s_(t+2)) -> dots $

== 时序差分学习

折扣回报满足递推关系：

$ U_t = R_t + gamma U_(t+1) $

展开后可以验证：

$ U_t = R_t + gamma R_(t+1) + gamma^2 R_(t+2) + gamma^3 R_(t+3) + dots $

DQN 的输出 $Q(s_t,a_t,w)$ 用来估计 $U_t$，而 $Q(s_(t+1),a_(t+1),w)$ 用来估计 $U_(t+1)$。于是有：

$ Q(s_t, a_t, w) approx r_t + gamma Q(s_(t+1), a_(t+1), w) $

等式左侧是当前预测，右侧是时序差分目标。

== 价值网络的训练

在第 $t$ 次更新中，先计算：

$ q(s_t, a_t, w_t) $

$ q(s_(t+1), a_(t+1), w_t) $

时序差分目标为：

$ y_t = r_t + gamma q(s_(t+1), a_(t+1), w_t) $

损失函数为：

$ L(w) = 1 / 2 [q(s_t, a_t, w) - y_t]^2 $

最后使用梯度下降更新网络参数：

$ w_(t+1) = w_t - alpha nabla_w L(w_t) $

动作价值函数的作用，是评估在给定状态 $s$ 下采取动作 $a$，并继续遵循策略后能够获得的期望回报。训练的目标，就是让 Q 网络的预测逐渐接近时序差分目标。
