#import "_notes.typ": course-note

== 一、这节课究竟在解决什么问题？

*核心问题：当 Agent 需要执行几百、几千步操作时，如何让它既能利用漫长的历史信息，又不至于耗费过高的推理成本？*

这包含两个不同的问题：

- *Capacity（容量）*：模型的上下文窗口足够长，并不意味着它真正能够识别、检索和利用早期的重要信息。
- *Efficiency（效率）*：即使模型能够处理足够长的上下文，重复读取历史也会带来推理延迟、计算成本和内存压力。

Neubig 的解决思路可以归纳为：

#html.elem("div", attrs: (class: "essay-main-image"))[
  #image("images/chat-system-stack.svg", width: 100%, alt: "历史增长后，Model 与 Harness 两层并列提供优化，共同支持低成本、稳定的长程 Agent。")
]

这里最重要的区分是：*让模型支持 100 万 token，与让 Agent 在长程任务中持续做出正确决策，是两个不同的研究目标。*

== 二、为什么 Agent 的上下文成本增长得这么快？

对应 PPT 第 2–5 页

普通聊天可能只需要几轮交互，但 Agent 的每一步通常都会产生：

用户指令 → 模型推理 → Tool Call → Tool Result → 模型继续推理。

为了让下一步知道之前发生了什么，系统往往把之前的历史重新提供给模型。

假设初始提示为 1K tokens，每轮新增 5K，调用过程如下：

#table(columns: 3,
[模型调用], [本轮输入], [累计处理输入],
[第 1 轮], [6K], [6K],
[第 2 轮], [11K], [17K],
[第 3 轮], [16K], [33K],
[第 4 轮], [21K], [54K],
[第 5 轮], [26K], [80K],
)

历史长度是线性增长，但如果每轮都重新计算所有输入，*累计输入 token 数呈平方级增长*。#course-note("n1")

=== OpenHands 的真实数据

Neubig 分析了 1,500 个 OpenHands session，平均每个 session 涉及约 77,922 tokens。

#html.elem("div", attrs: (class: "essay-main-image"))[
  #image("images/chat-context-composition.svg", width: 100%, alt: "OpenHands 上下文组成：工具返回 37%，系统与工具定义 23%，工具调用 20%，用户输入 9%，推理 9%，最终回复 2%。")
]

图：OpenHands 上下文组成（课件第 4 页）。

其中工具调用和工具结果合计占到 *57%*。

这意味着，Agent 的上下文开销很大一部分不是用户对话，而是它与环境交互产生的信息。优化 Tool Result 的长度和保留策略，可能比单纯缩短 Prompt 更有效。

== 三、LLM 推理是怎样处理长上下文的？

对应 PPT 第 6–11 页

课程首先介绍了两个关键阶段：

#html.elem("div", attrs: (class: "essay-main-image"))[
  #image("images/chat-inference-cards.svg", width: 100%, alt: "Prefill 与 Decode 并列对比：输入处理与输出生成，计算密集与顺序带宽限制。")
]

图：Prefill 与 Decode 的处理阶段和主要瓶颈。

由此引出两项重要指标：

- *TTFT（Time to First Token）*：从请求到达，到生成第一个 token 的时间。
- *TPOT（Time per Output Token）*：生成相邻输出 token 的平均时间间隔。

需要注意，优化 TTFT 不等于优化 TPOT。#course-note("n2")例如缩短长 Prompt 通常有助于 Prefill，但生成速度还取决于 Decode 的执行效率。

== 四、四种长上下文模型技术

对应 PPT 第 12–25 页

标准 Transformer 的全局 Attention 通常需要进行 $O(n^2)$ 级别的 token 间比较。上下文长度增大后，计算和 KV 存储成为瓶颈。#course-note("n3")

课程介绍了四类常见技术。

#table(columns: 3,
[技术], [核心思路], [主要问题],
[Sliding Window Attention], [只关注最近的 $w$ 个 token], [远距离信息无法被单层直接访问],
[Linear / Recurrent Attention], [将历史信息累积到固定大小的状态中], [历史信息可能相互干扰],
[Sparse Attention], [只计算被选中的重要 token], [选择器可能漏掉关键信息],
[KV Compression], [减少 KV 的存储大小], [压缩可能损失部分表达能力],
)

=== 4.1 Sliding Window Attention

例如当前 token 只关注前面 4,096 个 token，而不关注全部历史。

这样可以把复杂度从 $O(n^2)$ 降低为 $O(n w)$。

好处是计算成本显著降低，但早期历史无法被当前 token 在单层中直接读取。多层堆叠可以扩大信息传播范围，但不等同于直接访问所有历史。#course-note("n4")

=== 4.2 Linear Attention：把历史变成一种状态

这部分的关键是理解历史如何写入状态。

标准 Attention 保留历史的 Key、Value，在生成新 token 时进行匹配。

Linear Attention 则可以将过去的信息整合成一个状态矩阵：

$ S_t = S_(t-1) + k_t v_t^T $

然后利用这个状态产生输出，而不必每次都显式遍历全部历史。

它与 RNN 的思路存在相似之处：#course-note("n5")*历史被逐步写入一个固定大小的内部状态。*

课程还介绍了它的几个发展版本：

(Linear) 简单累积历史信息，但容易出现信息干扰。

(DeltaNet) 先读取已有记忆的预测结果，再利用预测误差修正状态。

(Gated DeltaNet) 增加遗忘门，让部分旧信息逐渐衰减。

(Kimi Delta Attention) 将遗忘从统一标量扩展为逐通道控制。

#html.elem("div", attrs: (class: "essay-main-image"))[
  #image("images/chat-state-evolution.svg", width: 100%, alt: "线性注意力状态更新机制的发展。")
]

这个发展过程体现了一个技术思想：固定容量的内部状态不仅需要写入机制，还需要选择性更新与遗忘机制。#course-note("n6")

=== 4.3 Sparse Attention 与 KV Compression

Sparse Attention 的思路是：并不是所有历史 token 都必须相互计算 Attention。

它可以使用固定模式，也可以根据当前 Query 动态挑选 Top-K 相关 token。

而 KV Compression 并不一定减少需要关注的历史位置，而是压缩保留每个位置所需的状态。课程讲到了 GQA 和 DeepSeek 使用的 MLA 等方案。

*这里可以区分两个不同的问题：信息是否被选中，以及信息以多大代价被保存。*

现代模型常组合局部、循环、稀疏与全局机制，而不是只采用其中一种。#course-note("n7")

== 五、为什么有 1M Context Window，也不代表模型真正理解 1M？

对应 PPT 第 26–36 页

Neubig 强调，模型拥有足够的计算能力之后，还需要学会如何利用远距离信息。

=== 5.1 Position Encoding

课程比较了以下方法：

#table(columns: 2,
[方法], [主要思想],
[Absolute Position], [给不同位置加入位置表示],
[RoPE], [利用旋转变换体现相对位置关系],
[NoPE], [不加入显式位置编码，依靠因果结构或循环动态学习顺序],
[Position Interpolation], [将更长的位置范围映射到模型熟悉的范围],
[YaRN], [根据不同频率选择插值方式，并调整 Attention 的尺度],
)

其中，RoPE 和 YaRN 主要涉及如何让模型处理超出初始训练长度的位置；NoPE 则探索是否需要显式的位置编码。

但任何一种位置方案都不能单独保证远距离推理能力。#course-note("n8")

=== 5.2 长上下文训练

课程给出的训练路线是：

#html.elem("div", attrs: (class: "essay-main-image"))[
  #image("images/chat-training.svg", width: 100%, alt: "从短序列预训练到长任务适配。")
]

这不是要求所有模型都严格按照相同长度训练，而是说明渐进式扩展的一般思路。

另一个重要观点是：将许多无关短文档拼接成很长的序列，不等于模型学会了跨越很长距离利用信息。

真正有效的长上下文数据，需要具有长距离依赖关系，例如代码库中的跨文件关联、多阶段 Agent 轨迹，或需要结合早期证据才能完成的任务。

课程也介绍了 Context Parallelism：将长上下文计算分配到多块设备上，缓解单设备内存限制，但不自动消除完整 Attention 的总计算量。

== 六、Prompt Caching：Agent 工程中最直接的优化

对应 PPT 第 37–44 页

这是最值得 Agent 开发者掌握的部分之一。

Agent 的系统指令、工具定义和早期历史在相邻调用中通常是重复的。既然已经计算过一次，就没必要每次从头进行 Prefill。

=== Prompt Cache 如何复用前缀

#html.elem("div", attrs: (class: "essay-main-image"))[
  #image("images/chat-prefix-reuse.svg", width: 100%, alt: "三轮调用的前缀缓存、新输入与输出。")
]

图：三轮调用中的前缀复用。色块用于示意，不代表实测 token 数。

其中要区分：

*KV Cache* 是注意力计算保存 Key、Value 状态的机制；*Prompt Caching* 是跨请求复用相同 Prompt 前缀的计算结果。二者相关，但不能完全视为同一概念。#course-note("n9")

课程展示的当时多家模型 API 定价中，命中的缓存输入 token 价格经常只有普通输入 token 的约十分之一。但具体价格和缓存保留时间取决于提供商。

=== 一个非常容易被忽视的工程问题

假设系统提示词写成：

```text
You are a scheduling agent.
Current time: 2026-11-09 10:00:00
Available tools: ...
```

下一步修改时间：

```text
You are a scheduling agent.
Current time: 2026-11-09 10:00:01
Available tools: ...
```

即使只改变一个时间字段，也可能从该变化位置开始破坏后续前缀的缓存复用。

更好的设计是把不变的指令和工具描述放前面，把时间、最新观察和环境状态追加到后面。

中途频繁切换不同模型可能损失已有缓存收益，模型路由的策略需要同时考虑推理价格与缓存成本。

=== 相关的两种系统技术

#table(columns: 3,
[系统], [技术], [主要解决的问题],
[vLLM], [PagedAttention], [高效分配和管理 KV 内存],
[SGLang], [RadixAttention], [识别并共享不同请求的重复前缀],
)

因此，对于已经能运行的 Agent，优化 Harness 和输入组织方式，有时就能显著降低成本，而不需要修改模型。

== 七、Context Compaction：长程 Agent 的状态管理

对应 PPT 第 45–51 页

当 Context Window 快满时，很多 Agent 会对历史进行压缩，例如将几十轮工具调用总结成一小段文字。#course-note("n11")

但是教授提出了一个更有意义的理解：

*Compaction 不只是 Summarization，而应当被看作 State Estimation（状态估计）。*

=== 7.1 压缩的真正目标

记完整历史为 $H_t$，压缩后的工作状态为 $hat(s)_t$。

可以写成：

$ hat(s)_t = cal(C)(H_t; B) $

其中 $B$ 是允许使用的 token 预算。

理想情况下：

$ p(A_"future" | H_t) approx p(A_"future" | hat(s)_t) $

含义是：

即使删除了大量历史文本，Agent 仍然应该能够依据压缩后的状态，做出与拥有完整历史时相近的后续决策。

因此压缩需要同时满足三个要求：

1. *Behavioral Fidelity*：尽可能保持未来行为正确。
2. *Bounded Representation*：压缩结果满足 token 预算。
3. *Recoverability*：能够追溯原始证据，而不是将其永久丢失。

=== 7.2 到底应该保留什么？

课程推荐按信息的性质来处理，而不是统一摘要。

#table(columns: 2,
[信息类别], [处理方式],
[最初目标、用户明确约束], [原样保留],
[已经完成的步骤、重要决策], [编码成 Checkpoint],
[最近的工具调用和结果], [尽可能原样保留],
[大型日志、长文件], [保存到外部，保留检索地址],
[重复内容、已废弃尝试], [丢弃],
)

例如一个 Coding Agent 为解决 CI 超时读取了数万行日志。

压缩前记录了大量命令、失败和重试；压缩后只需要明确保存：超时原因、已验证的修复方案、日志路径，以及接下来该做什么。

这样才是以任务继续执行为目标的压缩。#course-note("n10")

=== 7.3 Repeated Compaction Drift

课程还讲了一个非常典型的失败现象。

#html.elem("div", attrs: (class: "essay-main-image"))[
  #image("images/chat-compaction-drift.svg", width: 100%, alt: "反复压缩让精确 CUDA 版本约束逐步丢失。")
]

每次摘要看起来都合理，但经过多次压缩，精确的要求最终被模糊化、甚至删除。

这就是反复压缩造成的语义漂移。#course-note("n12")

解决思路是让关键约束拥有更稳定的存储方式，并允许 Agent 在不确定时重新查询原始证据，而不是反复依赖上一次摘要。

=== 7.4 压缩应该怎么评估？

OpenHands 的早期压缩经验值得注意：压缩方案在 SWE-bench 上节省了 token，同时没有明显降低成绩，但上线后却出现忘记已经建立的 PR、重复创建 PR，以及遗忘对话中新增指令的问题。

这说明仅测试最终任务是否成功是不够的，必须在压缩后继续运行 Agent。

可以采用：

#html.elem("div", attrs: (class: "essay-main-image"))[
  #image("images/chat-continuation-eval.svg", width: 100%, alt: "以压缩后的任务继续执行评估策略。")
]

这比单独评估摘要的文本相似度更符合 Agent 的实际使用目标。#course-note("n13")

== 八、对长程 Agent 与调度研究的启发

结合我关注的长程 Agent、Jev 调度和 Agent Memory 方向，这一讲至少提供了一个值得借鉴的思路。

=== 1. 历史信息不应该全部等价对待

对于 Scheduling Agent，历史记录可以拆成不同类型：

#table(columns: 2,
[信息], [更合适的处理方式],
[调度目标、系统约束], [长期固定保存],
[当前队列、服务器状态], [实时更新],
[过去的动作与成本变化], [按时间窗口或统计特征保存],
[历史失败、异常拥塞], [作为可检索事件保存],
[已经过期的状态快照], [丢弃或汇总],
)

这可能比直接将过去若干步的完整文本拼接进 Context 更合理。

=== 2. 可以设计一个轻量级实验

保持 Actor、环境和决策频率一致，比较：

#table(columns: 2,
[方法], [Context 管理],
[Full History], [保留所有可用历史],
[Sliding Window], [只保留最近若干步],
[Naive Summary], [利用 LLM 定期总结],
[Structured State], [保存结构化任务状态和关键事件],
[Structured State + Retrieval], [在结构化状态之外支持历史证据检索],
)

评估累计成本、长期收益、约束违反率、状态回忆准确率、token 开销。

这可以测试：*在给定 Context Budget 下，什么信息表示方式最有利于 Agent 继续执行长程任务？*

不过需要强调：上下文管理主要解决信息保存与利用问题，并不直接解决我关注的 *myopic decision-making*。即便信息完全正确，Agent 仍可能只追求即时回报。要解决短视行为，还需要显式引入长期价值估计、规划或其他前瞻性决策机制。

=== 3. 这节课可以延伸出一个技术问题

*How can an agent compress long interaction histories while preserving decision-relevant information for future actions?*

这一问题还需要结合已有 CS 研究排查创新空间，但很适合作为评估 Agent Memory、Context Compaction 与长期任务表现之间关系的起点。

== 九、最后总结：这节课最值得记住的五个结论

*Context Window 大，不等于有效记忆好。*

模型是否能访问长历史，以及能否正确利用信息，是两个层次。

*高效 Attention 是模型层面的解决方案。*

局部、线性、稀疏和压缩技术各自在减少计算、内存或检索范围。

*Prompt Caching 是 Harness 层面很直接的优化。*

稳定前缀、减少无意义的 Prompt 变化，可显著改善重复调用成本。

*Compaction 应保存任务状态，而非仅缩短文本。*

重要的是让 Agent 在压缩后仍然知道任务目标、约束、进度和下一步。

*长程评估应该看未来行为。*

摘要质量与后续任务成功率不等价，反复压缩更需要检查长期稳定性。

*整节课的核心思想可以概括成一句话：*

长程 Agent 的关键不只是拥有更长的 Context，而是通过模型架构与 Harness 设计，经济、准确且持续地保留和利用对未来任务有价值的信息。

建议延伸阅读：MemGPT、LongLLMLingua、ReSum。课程下一讲进一步讨论跨任务的 Memory 与 Skills，与本讲的单次长上下文管理相互衔接。

== 课后自测

1. 历史每轮只增加固定长度，为什么累计输入仍可能平方增长？
2. 前缀缓存命中后，为什么模型仍可能受长上下文容量和 KV 读取限制？
3. 线性状态与显式 KV cache 分别容易丢失或保留哪些信息？
4. 如果压缩后“还能回答问题”，但不再遵守精确版本约束，算成功吗？
5. 怎样设计一个必须在多次压缩后继续行动的测试，而不只是测试摘要质量？

== 阅读材料

- #link("https://www.cmu-agents.com/#/schedule")[CMU 11-768 AI Agents · Fall 2026 课程日程]。
- #link("https://www.cmu-agents.com/slides/lecture-03-long-context.pdf")[Lecture 3 官方课件]：增长与推理（第 2–10 页）、架构与训练（第 11–36 页）、缓存（第 37–44 页）、压缩与评估（第 45–53 页）。本文配图保留课件原有署名与参考文献。
