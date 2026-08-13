#import "../../../../../../config.typ": template, tufted

#show: template.with(
  title: "策略梯度",
)

#html.elem("a", attrs: (class: "back-link", href: "/xiaoxu/docs/technical-docs/llm/reinforcement-learning/"))[← 返回强化学习入门]

#heading(level: 1, outlined: false)[策略梯度]

#outline(title: [目录], depth: 3)

== 状态价值函数

折扣回报为：

$ U_t = R_t + gamma R_(t+1) + gamma^2 R_(t+2) + gamma^3 R_(t+3) + dots $

动作价值函数定义为：

$ Q_pi(s_t, a_t) = E[U_t | S_t = s_t, A_t = a_t] $

对动作按照策略分布求期望，可以得到状态价值函数：

$ V_pi(s) = E_(A ~ pi(dot | s))[Q_pi(s, A)] = sum_a pi(a | s) Q_pi(s, a) $

== 策略梯度

使用参数 $theta$ 表示策略网络后，状态价值可以近似写成：

$ V(s, theta) = sum_a pi(a | s, theta) Q_pi(s, a) $

策略梯度是状态价值关于策略参数 $theta$ 的导数：

$ frac(partial V(s, theta), partial theta) = sum_a frac(partial pi(a | s, theta), partial theta) Q_pi(s, a) $

利用对数导数恒等式：

$ frac(partial log pi(a | s, theta), partial theta) = 1 / pi(a | s, theta) frac(partial pi(a | s, theta), partial theta) $

可以把策略梯度改写为：

$ frac(partial V(s, theta), partial theta) = sum_a pi(a | s, theta) frac(partial log pi(a | s, theta), partial theta) Q_pi(s, a) $

训练的目标是增大状态价值，因此参数更新采用梯度上升。

== Q 值的两种计算方式

=== 使用完整回报：REINFORCE

先完成一个回合并生成轨迹：

$ (s_1, a_1, r_1, s_2, a_2, r_2, dots, s_T, a_T, r_T) $

对每个时刻 $t$，计算采样得到的折扣回报：

$ u_t = sum_(k=t)^T gamma^(k-t) r_k $

因为 $Q_pi(s_t,a_t)=E[U_t]$，所以可以用一次采样得到的 $u_t$ 近似 $Q_pi(s_t,a_t)$，即令：

$ q_t = u_t $

这种方法必须等整个回合结束后才能计算回报。

=== 使用神经网络近似

另一种方式是使用神经网络近似动作价值函数 $Q_pi$。这样，同一回合中的不同动作都可以及时获得价值评价，也由此得到 Actor-Critic 方法。
