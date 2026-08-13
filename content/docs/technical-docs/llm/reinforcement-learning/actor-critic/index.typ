#import "../../../../../../config.typ": template, tufted

#show: template.with(
  title: "Actor-Critic 方法",
)

#html.elem("a", attrs: (class: "back-link", href: "/xiaoxu/docs/technical-docs/llm/reinforcement-learning/"))[← 返回强化学习入门]

#heading(level: 1, outlined: false)[Actor-Critic 方法]

#outline(title: [目录], depth: 3)

== 网络结构与目标函数

策略 $pi$ 下的状态价值为：

$ V_pi(s) = sum_a pi(a | s) Q_pi(s, a) $

Actor-Critic 分别用两个神经网络近似策略和动作价值函数：

$ V(s, theta, w) approx sum_a pi(a | s, theta) q(s, a, w) $

- *策略网络（Actor）*：使用 $pi(a|s,theta)$ 近似策略 $pi(a|s)$，$theta$ 是可训练参数；
- *价值网络（Critic）*：使用 $q(s,a,w)$ 近似动作价值 $Q_pi(s,a)$，$w$ 是可训练参数。

这个目标函数可以理解为：使用当前策略后，智能体的平均表现有多好。策略越好，目标函数越大。

== Critic：更新价值网络

Critic 使用时序差分目标：

$ y_t = r_t + gamma q(s_(t+1), a_(t+1), w_t) $

损失函数为：

$ L(w) = 1 / 2 [q(s_t, a_t, w) - y_t]^2 $

使用梯度下降更新价值网络，使当前预测逐渐接近时序差分目标：

$ w_(t+1) = w_t - alpha nabla_w L(w_t) $

== Actor：更新策略网络

状态价值关于策略参数 $theta$ 的梯度为：

$ frac(partial V(s, theta), partial theta) = sum_a frac(partial pi(a | s, theta), partial theta) Q_pi(s, a) $

利用对数导数恒等式，可写为：

$ frac(partial V(s, theta), partial theta) = sum_a pi(a | s, theta) frac(partial log pi(a | s, theta), partial theta) Q_pi(s, a) $

也可以将求和写成关于随机动作 $A$ 的期望：

$ frac(partial V(s, theta), partial theta) = E_(A ~ pi(dot | s, theta))[frac(partial log pi(A | s, theta), partial theta) Q_pi(s, A)] $

第一种形式适合枚举离散动作；当动作空间连续、无法直接计算积分时，可以从策略分布中抽样，并用蒙特卡罗方法近似这个期望。

令：

$ g(a, theta) = frac(partial log pi(a | s_t, theta), partial theta) q(s_t, a, w) $

从 $pi(dot|s_t,theta_t)$ 中抽取动作 $a$ 后，$g(a,theta)$ 是策略梯度的无偏估计。策略网络使用随机梯度上升更新：

$ theta_(t+1) = theta_t + beta g(a, theta_t) $

== 完整流程

1. 观察状态 $s_t$，从策略 $pi(dot|s_t,theta_t)$ 中抽取动作 $a_t$；
2. 执行动作 $a_t$，环境返回新状态 $s_(t+1)$ 和奖励 $r_t$；
3. 从 $pi(dot|s_(t+1),theta_t)$ 中抽取下一动作 $tilde(a)_(t+1)$，但此时不执行它；
4. 计算 $q_t=q(s_t,a_t,w_t)$ 和 $q_(t+1)=q(s_(t+1),tilde(a)_(t+1),w_t)$；
5. 计算时序差分误差：

$ delta_t = q_t - (r_t + gamma q_(t+1)) $

6. 计算价值网络梯度：

$ d_(w,t) = nabla_w q(s_t, a_t, w_t) $

7. 更新价值网络：

$ w_(t+1) = w_t - alpha delta_t d_(w,t) $

8. 计算策略网络梯度：

$ d_(theta,t) = nabla_theta log pi(a_t | s_t, theta_t) $

9. 更新策略网络：

$ theta_(t+1) = theta_t + beta q_t d_(theta,t) $

== 优势函数

策略更新中的动作价值函数可以替换为优势函数：

$ A_pi(s, a) = Q_pi(s, a) - V_pi(s) $

优势函数衡量某个动作相对于当前状态下平均动作的额外收益或损失，因此能够更清楚地反映该动作是否优于策略的平均表现。
