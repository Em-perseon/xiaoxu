#import "../../../../../config.typ": template, tufted

#show: template.with(
  title: "检索增强生成（RAG）",
)

#html.elem("a", attrs: (class: "back-link", href: "/xiaoxu/docs/technical-docs/llm/"))[← 返回大语言模型的漫游指南]

#heading(level: 1, outlined: false)[检索增强生成（RAG）]

#outline(title: [目录], depth: 3)

== 引言

大模型本质是以参数化将知识存储到自己的内部，即一个又一个权重。这带来几个问题：
1. 幻觉：超出参数范围的知识，模型会凭空生成内容；
2. 过时：模型训练时的知识是静态的，无法及时更新
3. 领域知识的局限：即通用模型缺乏对于私有代码库、内部文档、专门法规或企业数据的了解

形式化地，令 $M_theta$ 表示参数为 $theta$ 的语言模型，$D = {d_1, d_2, ..., d_n}$ 为外部文档语料库。给定查询 $q$，仅依赖参数化知识时，生成回答 $a$ 的概率可写为：

$ P(a | q) = P_(M_theta)(a | q) $

引入检索后，回答概率对检索到的文档做边际化：

$ P(a | q, D) = sum_(d in D) P_(M_theta)(a | q, d) P_"ret"(d | q, D) $

其中，$P_"ret"(d | q, D)$ 表示在文档上面的检索分布#footnote[
  这里的检索分布，可以理解为：面对一个 question，从完整文档中找到与它对应的 document chunk。
]。这时候的生成就建立在了一个外部（非参数化知识）上了。

== RAG架构

标准RAG分为两个阶段：
1. Stage 1:离线索引流程
2. Stage 2:在线检索生成流程

具体情况如下图所示:
#figure(caption: "RAG架构图，紫色表示离线流程，绿色表示在线推理流程")[
  #image("rag_structure.png", width: 100%)
]

=== Stage 1:离线索引流程
1. 数据处理：对原始语料文本进行处理
2. 分块操作#footnote[
  2026-08-13：感觉关于这个 chunking 操作应该会有很多研究，不同的 chunking 方式会对 embedding 的效果产生很大影响。
]，将长文档切分为多个文本块，让其能够放入embedding模型的上下文窗口当中，又保持语义的连续性。
3. 嵌入操作，将每个文本块通过embedding模型映射为向量表示。
4. 存储操作，将向量表示和原始文本和元数据一起存入向量数据库，方便后续检索。

=== Stage 2:在线检索生成流程
1. 用户输入查询
2. 通过 Query Encoder#footnote[
  2026-08-13：更正，在实际运用当中，为了节省时间和成本，一般会直接使用现成的 embedding 模型来做 query embedding，而不是单独训练一个 Query Encoder。同理对于document embedding，也可以直接使用现成的 embedding 模型来做 document embedding，而不是单独训练一个 Document Encoder。如果效果不好，再考虑单独训练] 将查询映射为向量表示
3. 在向量数据库中检索与查询向量最相似的文档块
4. 将检索到的文档块和查询一起通过prompt输入到生成模型中，生成回答。

== 检索方法
=== 稀疏检索：BM25和TF-IDF
  稀疏检索的方式是基于词频的检索方法，主要包括BM25和TF-IDF。稀疏检索的优点是计算速度快、实现简单，但缺点是无法捕捉语义信息，容易受到词汇表限制。
  $ op("TF-IDF")(t, d) = frac(f_(t, d), abs(d)) log frac(N, op("df")(t)) $

  其中：
  - $t$ 表示待检索的词项（term），$d$ 表示一篇文档；
  - $f_(t, d)$ 表示词项 $t$ 在文档 $d$ 中出现的次数；
  - $abs(d)$ 表示文档 $d$ 的长度，通常以词项或 token 的数量计算；
  - $N$ 表示语料库中的文档总数；
  - $op("df")(t)$ 表示包含词项 $t$ 的文档数量，即文档频率（document frequency）；
  - $log frac(N, op("df")(t))$ 表示词项 $t$ 的逆文档频率。词项出现得越普遍，该值越小。

  $
    op("BM25")(q, d)
    &= sum_(t in q) op("IDF")(t)
    frac(
      f_(t, d) (k_1 + 1),
      f_(t, d) + k_1 (1 - b + b frac(abs(d), op("avgdl")))
    )
  $

  其中：
  - $q$ 表示用户查询，$d$ 表示候选文档，$t$ 表示查询中的词项；
  - $op("BM25")(q, d)$ 表示文档 $d$ 与查询 $q$ 的相关性得分，分数越高通常表示越相关；
  - $op("IDF")(t)$ 表示词项 $t$ 的逆文档频率，用于降低常见词的权重；
  - $f_(t, d)$ 表示词项 $t$ 在文档 $d$ 中出现的次数；
  - $k_1$ 控制词频对得分的影响及其饱和速度，通常取正数；
  - $b$ 控制文档长度归一化的强度，取值范围通常为 $[0, 1]$；
  - $abs(d)$ 表示当前文档长度，$op("avgdl")$ 表示语料库中文档的平均长度。
=== 稠密检索
  稠密段落检索 #footnote[这个的作用是为了找到一个好的q和d的表示]（Dense Passage Retrieval, DPR）使用两个独立的基于 BERT #footnote[
    2026-08-14：不一定是这个Encoder(虽然后面可以知道为什么要训练一个Encoder)Decoder我觉得也行。\
    Decoder 大模型产生的高维 contextual representation (RAG当中的embeddingg都是指contextual representation，而不是普通的token embedding）确实可以拿来构造 RAG embedding,它的 hidden state 语义非常丰富，但这个向量空间不一定是一个好的 retrieval space。] 的编码器—查询编码器$E_(Q)$和段落编码器$E_(P)$—并用对比损失训练，使相关查询-段落对在embedding空间中彼此接近。

  在双编码器架构中，查询和段落分别被映射为向量，并通过点积计算相似度：

  $ op("sim")(q, p) = E_(Q)(q)^top E_(P)(p) $

  DPR 使用批内负样本进行训练。给定一个包含 $B$ 个查询—正段落对 ${(q_i, p_i^+)}_(i=1)^B$ 的批次，批次中的其他段落都会被视为当前查询的负样本，其对比损失为：

  $
    cal(L)_"DPR"
    = -frac(1, B) sum_(i=1)^B
    log frac(
      exp(frac(E_(Q)(q_i)^top E_(P)(p_i^+), tau)),
      sum_(j=1)^B exp(frac(E_(Q)(q_i)^top E_(P)(p_j), tau))
    )
  $

  其中，$E_(Q)$ 和 $E_(P)$ 分别表示查询编码器和段落编码器，$p_i^+$ 表示与查询 $q_i$ 相关的正段落，$B$ 表示批次大小，$tau$ 表示温度超参数；对于查询 $q_i$，批次中除 $p_i^+$ 之外的段落均作为负样本。难负样本，即词面相似但语义无关的段落，对于训练更强的检索器至关重要。

  训练出对应的查询编码器$E_(Q)$ 和段落编码器 $E_(P)$ #footnote[这个段落编码器不一定训练？可以用现成的embedding模型进行直接embedding吗？]后，后面就是比较的事情了，但大规模场景下，对数百万个embedding做枚举#footnote[就是query一条一条与document进行那个similarity计算]不太现实。因此引入了近似最近邻（Approximate Nearest Neighbor, ANN）搜索算法。ANN算法通过构建高效的数据结构（如倒排索引、树结构或图结构）来加速相似度搜索，从而在大规模向量空间中快速找到与查询向量最相似的文档向量。
  1. IVF（Inverted File Index）：将向量空间划分为多个子空间，并为每个子空间建立倒排索引，以便快速定位潜在的近邻。
  2. PQ（Product Quantization）：将向量分解为多个子向量，并对每个子向量进行量化，从而减少存储空间和计算复杂度。
  3. HNSW（Hierarchical Navigable Small World）：构建分层图结构，通过在图中导航来高效地搜索近邻。

=== 混合检索
  混合检索结合了稀疏检索和稠密检索的优点。它通过将两种方法的得分#footnote[就是将最后的similarity得分]进行加权融合，来提高检索的准确性和鲁棒性。混合检索的公式如下：

  $ op("score")_("hybrid")(q, d) = alpha op("score")_("sparse")(q, d) + (1 - alpha) op("score")_("dense")(q, d) $

  其中，$alpha$ 是一个权重参数，用于平衡稀疏检索和稠密检索的贡献。通过调整 $alpha$ 的值，可以在不同场景下优化检索性能。

  两个虽然都是计算similarity，但实际的意义不同，一个是看词频，一个是看语义。因此不同系统的分数不能直接比较。Reciprocal Rank Fusion(RRF)通过基于排名而不是分数来避免这个问题。

  $ op("RRF")(q, d) = sum_(m=1)^M frac(1, k + op("rank")_(m)(q, d)) $

  其中，$q$ 表示查询，$d$ 表示候选文档，$M$ 表示参与融合的检索系统数量#footnote[(M) 表示参与融合的检索结果列表数量。在本例中包含稀疏检索和稠密检索两份列表，因此 (M=2)。RRF 也可以同时融合更多结果，例如 BM25、DPR 和另一个向量检索模型，此时 (M=3)。]，$op("rank")_(m)(q, d)$ 表示文档 $d$ 在第 $m$ 个检索系统中针对查询 $q$ 的排名，$k$ 表示平滑常数，用于减小排名靠前的文档之间过大的分数差异。文档在多个检索系统中的排名越靠前，其 RRF 得分越高。

  #html.elem("div", attrs: (class: "rrf-example"))[
    *计算示例*

    对同一个查询 $q$，假设稀疏检索的排序为 $d_A > d_B > d_C$，稠密检索的排序为 $d_C > d_A > d_B$，并取 $k = 60$。此时：

    $ op("RRF")(q, d_A) = frac(1, 60 + 1) + frac(1, 60 + 2) approx 0.03252 $

    $ op("RRF")(q, d_B) = frac(1, 60 + 2) + frac(1, 60 + 3) approx 0.03200 $

    $ op("RRF")(q, d_C) = frac(1, 60 + 3) + frac(1, 60 + 1) approx 0.03227 $

    因此，融合后的最终排序为 $d_A > d_C > d_B$。虽然两种检索方法的原始相似度分数不可直接比较，但它们各自给出的排名可以通过 RRF 稳定地合并。
  ]

=== 学习式稀疏检索：SPLADE

SPLADE（Sparse Lexical and Expansion Model）使用预训练遮蔽语言模型为查询和文档生成定义在整个词表上的稀疏向量。

#heading(level: 3, outlined: false)[一、为什么需要 SPLADE]

传统稀疏检索（如 BM25）依赖精确的词面匹配。当查询使用 “car”，而文档使用 “automobile” 时，即使二者语义相同，BM25 也可能无法召回该文档。稠密检索（如 DPR）能够捕捉语义关系，但结果较难解释；在高吞吐的在线查询场景中，查询向量编码通常依赖 GPU，同时还需要维护规模较大的向量索引。

SPLADE 生成的向量仍然是词表空间中的稀疏向量，因此可以像 BM25 一样使用倒排索引；同时，模型能够学习同义词和相关概念的词项扩展，从而获得语义匹配能力。

#heading(level: 3, outlined: false)[二、模型如何生成稀疏表示]

下面以输入文本“苹果手机的价格”为例。这里描述的是 SPLADE 的可微分表示生成过程，该过程在训练和推理时都会执行。

1. *分词。* Tokenizer 将输入文本转换为 $N$ 个 token，例如 `[苹果] [手机] [的] [价格]`。
2. *上下文编码。* BERT 为每个 token 生成一个 $H$ 维 hidden state，得到 $N times H$ 的 hidden-state 矩阵，其中 $H$ 是模型的 hidden size，例如 768。
3. *词表投影。* MLM Head #footnote[Masked Language Modeling Head，掩码语言模型预测头]将每个 token 位置分别投影到大小为 $abs(V)$ 的完整词表#footnote[
  “完整词汇空间”指 Tokenizer 预先定义的全部 token，而不是当前句子中出现的几个词。假设 $abs(V)=30,522$，就可以把它想成 30,522 个位置固定的槽位：第一个位置永远对应词表中的第一个 token，第二个位置永远对应第二个 token，以此类推。
  #linebreak()#linebreak()
  输入端有 Token Embedding Matrix $E in RR^(abs(V) times 768)$。某个 Token ID 为 $k$ 时，embedding lookup 只取 $E$ 的第 $k$ 行，得到 $e_k in RR^768$。
  #linebreak()#linebreak()
  输出端则把 MLM Head 产生的 $tilde(h)_i in RR^768$ 与词表中的全部 30,522 行同时比较。若采用权重共享，可写为 $z_i = E tilde(h)_i + b in RR^abs(V)$。所以 $z_i$ 有 30,522 个 logit，每个位置表示对应词表 token 的预测分数，例如“苹果”为 8.7、“米饭”为 8.2、“汽车”为 -1.7。
  #linebreak()#linebreak()
  “权重共享”不是说输入 embedding 和输出 logits 是同一种向量，而是说输入查表和输出打分复用了同一个参数矩阵 $E$：输入时按 Token ID 取其中一行，输出时则用 hidden state 与它的所有行计算分数。
]，因此得到 $N times abs(V)$ 的 logit 矩阵。记第 $i$ 个 token 位置对第 $j$ 个词表词项产生的 logit 为 $z_(i,j)$。

4. *非负激活。* 对每个 logit 进行变换：

$ a_(i,j) = log(1 + op("ReLU")(z_(i,j))) $

5. *按列聚合。* 对于每一个词表词项 $j$，原始 SPLADE 沿 $N$ 个 token 位置求和：

$ w_j = sum_(i=1)^N a_(i,j), quad j = 1, ..., abs(V) $

聚合并不是把矩阵中的所有值混在一起，而是分别处理每一个词表列。例如，“售价”这一列在四个 token 位置上的激活值若为 `0.1、0.4、0.2、7.3`，求和聚合后其权重为 `8.0`。对全部 $abs(V)$ 列执行相同操作后，$N times abs(V)$ 矩阵就变成 $abs(V)$ 维向量。SPLADEv2 则将这里的求和改为最大值聚合。

最终向量可能包含“苹果”“手机”“价格”，也可能激活原文中没有直接出现的“售价”。后者就是模型学习到的词项扩展。

#heading(level: 3, outlined: false)[三、SPLADE 如何训练]

上述表示生成过程本身可以直接运行，但未经检索训练的预训练 MLM 只学会了预测词语，并不知道哪些查询和文档应该匹配，也不会主动产生适合倒排索引的稀疏表示。因此，SPLADE 以预训练 MLM 为初始化，再针对检索任务进行端到端训练。

查询和文档分别被编码为稀疏向量 $w_q$ 与 $w_d$，相关性通过点积计算：

$ op("score")(q, d) = w_q^top w_d $

一种常见训练方式是批内对比学习。对于包含 $B$ 个查询—正文档对的批次，其他查询对应的正文档可以作为当前查询的批内负样本：

$
  cal(L)_"rank"
  = -frac(1, B) sum_(i=1)^B
  log frac(
    exp(frac(op("score")(q_i, d_i^+), tau)),
    sum_(j=1)^B exp(frac(op("score")(q_i, d_j^+), tau))
  )
$

训练目标还会加入查询端和文档端的稀疏正则项#footnote[
  这里的 $cal(R)(w)$ 是“稀疏正则函数”的通用记号，不是前面的 RRF；$w$ 表示查询或文档的 SPLADE 词表权重向量。最直观的例子是 $L_1$ 正则：$cal(R)_("L1")(w) = sum_(j=1)^abs(V) abs(w_j)$，激活词项越多、权重越大，惩罚就越大。SPLADE 常用 FLOPS regularization：先计算批次中第 $j$ 个词项的平均激活 $mu_j = frac(1, B) sum_(i=1)^B w_j^((i))$，再计算 $cal(R)_"FLOPS" = sum_(j=1)^abs(V) mu_j^2$；某个词项若在许多样本中频繁激活，其惩罚会更大，从而缩短倒排列表并降低检索计算量。
]：

$ cal(L) = cal(L)_"rank" + lambda_q cal(R)(w_q) + lambda_d cal(R)(w_d) $

其中，排序损失让相关查询—文档对获得更高得分并与负样本拉开；稀疏正则项促使大量词项权重趋近于零。难负样本、批内负样本和教师蒸馏可以单独使用或组合使用，它们属于训练配方，而不是 SPLADE 编码结构的固定组成部分。

#heading(level: 3, outlined: false)[四、训练完成后如何检索]

1. *离线建立索引。* 使用训练完成的 SPLADE 编码所有文档，通过阈值或 top-$k$ 剪枝仅保留少量非零词项，再将结果写入倒排索引。
2. *在线编码查询。* 使用同一个训练完成的模型将查询编码为词表空间中的稀疏向量。
3. *执行检索。* 借助倒排索引计算查询与候选文档稀疏向量的点积，并返回得分最高的文档。

=== SPLADEv2

SPLADEv2 沿用 SPLADE 的词表稀疏表示与倒排索引检索方式，主要改进池化策略，引入知识蒸馏，并探索只扩展文档的高效变体，而不是重新设计一套检索流程。

*1. 最大值池化。* 原始 SPLADE 会把同一词项在所有输入位置上的激活相加；SPLADEv2 改为只保留其中最强的一次激活：

$ w_j = max_(1 <= i <= N) log(1 + op("ReLU")(z_(i,j))) $

其中，$z_(i,j)$ 表示第 $i$ 个输入 token 对词表词项 $j$ 产生的 logit，$w_j$ 是词项 $j$ 在最终稀疏向量中的权重。最大值池化可以避免某个词项仅因在多个位置反复获得较弱激活而累积出过高权重。

*2. 来自 cross-encoder 的知识蒸馏。* SPLADEv2 不只依赖“相关／不相关”的二元标签，而是让 cross-encoder 教师模型为正、负文档给出更细致的相关性分数。学生模型学习教师对两篇文档的相对偏好。对于三元组 $(q, d^+, d^-)$，先定义：

$
  Delta_s = s_s(q, d^+) - s_s(q, d^-), quad
  Delta_t = s_t(q, d^+) - s_t(q, d^-)
$

再使用 Margin-MSE 蒸馏损失：

$ cal(L)_"distill" = (Delta_s - Delta_t)^2 $

其中，$s_s$ 与 $s_t$ 分别表示 SPLADE 学生模型和 cross-encoder 教师模型的相关性分数。教师不仅告诉学生哪篇文档更相关，还告诉它两篇文档之间应当相差多少。

*3. 查询端与文档端分别控制稀疏程度。* 查询发生在在线检索阶段，需要尽量减少被访问的倒排列表；文档表示可以离线计算，因此通常允许保留更多词项。原始 SPLADE 已经允许为两端设置独立的正则权重，SPLADEv2 延续了这一设计：

$
  cal(L)
  = cal(L)_"distill"
  + lambda_q cal(L)_"FLOPS"^q
  + lambda_d cal(L)_"FLOPS"^d,
  quad lambda_q > lambda_d
$

这里的 $lambda_q > lambda_d$ 表示对查询端施加更强的稀疏约束，并不表示查询和文档必须使用两个结构不同的编码器。这不是 SPLADEv2 新增的机制，具体数值属于需要根据检索效果与延迟共同选择的超参数。

*4. FLOPS 正则化。* 单纯压低向量的 $L_1$ 范数，并不能阻止少数高频词项出现在大量文档中。原始 SPLADE 已经提出同时尝试 $L_1$ 与 FLOPS 正则；SPLADEv2 继续使用 FLOPS 正则项惩罚一个批次内被频繁激活的词项：

$
  overline(a)_j^x = frac(1, B) sum_(i=1)^B w_j^(x_i), quad
  cal(L)_"FLOPS"^x = sum_(j in V) (overline(a)_j^x)^2,
  quad x in {q, d}
$

其中，$overline(a)_j^x$ 是词项 $j$ 在查询批次或文档批次中的平均激活，$B$ 是批次大小。若一个词项在许多样本中都获得非零权重，它对应的平均激活及平方惩罚就会变大；训练因此会压低这类词项，避免形成过长的倒排列表。

*5. 更高效的模型配置。* SPLADEv2 的实验使用 DistilBERT-base 作为初始化主干。与 BERT-base 相比，它的参数量更小，可以降低查询与文档编码成本。论文还给出了 SPLADE-doc 变体：只对文档执行学习式扩展，查询仍使用原始词项，从而把文档侧计算全部放到离线阶段，以进一步降低在线检索延迟。

#heading(level: 3, outlined: false)[SPLADE v1 与 SPLADEv2 对比]

#table(
  columns: (1.05fr, 1.45fr, 1.65fr),
  align: (left, left, left),
  inset: 8pt,
  stroke: 0.6pt + rgb("d8dee8"),
  table.header(
    [*对比维度*],
    [*SPLADE v1*],
    [*SPLADEv2*],
  ),
  [token 位置聚合],
  [求和池化],
  [最大值池化],
  [实验主干],
  [BERT-base],
  [DistilBERT-base],
  [训练信号],
  [排序损失、批内负样本与难负样本],
  [加入 cross-encoder 教师蒸馏，并使用更难的负样本],
  [蒸馏损失],
  [无教师蒸馏],
  [Margin-MSE],
  [稀疏正则],
  [$L_1$ 或 FLOPS 正则，并分别设置 $lambda_q$、$lambda_d$],
  [延续 FLOPS 正则和查询／文档端的独立正则权重],
  [查询与文档扩展],
  [查询端和文档端都可以学习词项扩展],
  [保留双端扩展；另外提出只扩展文档的 SPLADE-doc 变体],
)

=== ColBERT：后期交互

普通双编码器会把整个查询或文档压缩成一个向量，再通过一次点积计算相关性。ColBERT（Contextualized Late Interaction over BERT）则保留查询和文档中每个 token 的 embedding，把查询—文档交互推迟到编码完成之后，因此称为“后期交互”。

#html.elem("span", attrs: (class: "marginnote colbert-side-note"))[
  #html.elem("span", attrs: (class: "colbert-diagram colbert-match-diagram"))[
    #html.elem("span", attrs: (class: "colbert-diagram-title"))[MaxSim 示例]
    #html.elem("span", attrs: (class: "colbert-token-label"))[查询 Query]
    #html.elem("span", attrs: (class: "colbert-token-grid colbert-query-tokens"))[
      #html.elem("span")[#html.elem("b")[苹果] #html.elem("i")[↓] #html.elem("code")[q₁]]
      #html.elem("span")[#html.elem("b")[手机] #html.elem("i")[↓] #html.elem("code")[q₂]]
      #html.elem("span")[#html.elem("b")[续航] #html.elem("i")[↓] #html.elem("code")[q₃]]
    ]
    #html.elem("span", attrs: (class: "colbert-search-note"))[每个 $q_i$ 都与下方所有 $d_j$ 比较]
    #html.elem("span", attrs: (class: "colbert-token-label"))[文档 Document]
    #html.elem("span", attrs: (class: "colbert-token-grid colbert-document-tokens"))[
      #html.elem("span")[#html.elem("b")[iPhone] #html.elem("i")[↓] #html.elem("code")[d₁]]
      #html.elem("span")[#html.elem("b")[电池] #html.elem("i")[↓] #html.elem("code")[d₂]]
      #html.elem("span")[#html.elem("b")[使用] #html.elem("i")[↓] #html.elem("code")[d₃]]
      #html.elem("span")[#html.elem("b")[时间] #html.elem("i")[↓] #html.elem("code")[d₄]]
      #html.elem("span")[#html.elem("b")[很长] #html.elem("i")[↓] #html.elem("code")[d₅]]
    ]
    #html.elem("span", attrs: (class: "colbert-best-matches"))[
      #html.elem("span")[q₁ → d₁：0.93]
      #html.elem("span")[q₂ → d₁：0.88]
      #html.elem("span")[q₃ → d₂：0.91]
    ]
    #html.elem("span", attrs: (class: "colbert-score-sum"))[0.93 ＋ 0.88 ＋ 0.91 ＝ *2.72*]
  ]
]

设查询包含 $abs(q)$ 个 token，文档包含 $abs(d)$ 个 token。对于每一个查询 token，ColBERT 都在文档的所有 token 中寻找与它最相似的一个，然后将这些最大相似度相加：

$
  s(q, d)
  = sum_(i=1)^abs(q)
  max_(1 <= j <= abs(d)) q_i^top d_j
$

这个运算称为 MaxSim。它比单向量双编码器更有表达能力，因为查询中的不同 token 可以分别匹配文档中的不同位置；它又比 cross-encoder 更适合大规模检索，因为文档 token embedding 可以提前离线计算，而不必在每次查询时把查询和每篇文档共同送入模型。

#html.elem("span", attrs: (class: "marginnote colbert-side-note"))[
  #html.elem("span", attrs: (class: "colbert-diagram colbert-pipeline-diagram"))[
    #html.elem("span", attrs: (class: "colbert-stage-labels"))[
      #html.elem("span")[编码阶段]
      #html.elem("span")[交互阶段]
    ]
    #html.elem("span", attrs: (class: "colbert-pipeline-core"))[
      #html.elem("span", attrs: (class: "colbert-encoded-pairs"))[
        #html.elem("span", attrs: (class: "colbert-flow-line"))[
          #html.elem("b")[Query]
          #html.elem("span")[→]
          #html.elem("span")[Encoder]
          #html.elem("span")[→]
          #html.elem("code")[q₁ q₂ q₃]
        ]
        #html.elem("span", attrs: (class: "colbert-flow-line"))[
          #html.elem("b")[Doc]
          #html.elem("span")[→]
          #html.elem("span")[Encoder]
          #html.elem("span")[→]
          #html.elem("code")[d₁ d₂ d₃ …]
        ]
      ]
      #html.elem("span", attrs: (class: "colbert-late-stage"))[
        #html.elem("b")[MaxSim]
        #html.elem("span")[→ Score]
      ]
    ]
    #html.elem("span", attrs: (class: "colbert-late-caption"))[↑ 编码完成后才发生交互]
  ]
]

*架构。* 查询编码器 $E_Q$ 和文档编码器 $E_D$ 通常以 BERT 类 encoder 为主干。二者不把整段文本压缩为一个 `[CLS]` 向量，而是为每个 token 保留一个 contextual embedding，再通过线性层投影到较低维度。以 128 维为例：

$
  q_i = op("Linear")(E_Q(q)_i) in RR^128,
  quad i = 1, ..., abs(q)
$

$
  d_j = op("Linear")(E_D(d)_j) in RR^128,
  quad j = 1, ..., abs(d)
$

因此，查询最终表示为一个 $abs(q) times 128$ 的矩阵，文档表示为一个 $abs(d) times 128$ 的矩阵。ColBERT 属于多向量检索：每段文本不是对应一个向量，而是对应一组 token 向量。

*训练。* 给定查询 $q$、正文档 $d^+$ 和一组负文档 ${d_1^-, ..., d_N^-}$，一种基本训练目标是 pairwise softmax 交叉熵：

$
  cal(L)_"ColBERT"
  = -log frac(
    exp(s(q, d^+)),
    exp(s(q, d^+)) + sum_(k=1)^N exp(s(q, d_k^-))
  )
$

其中，$s(q,d)$ 是前面的 MaxSim 分数。训练会提高查询与正文档之间的 token 级匹配分数，同时压低负文档的分数。负样本通常来自：

- *批内负样本：* 将同一训练批次中其他查询对应的正文档作为当前查询的负样本；
- *难负样本：* 使用 BM25 或已有检索器召回词面相似、但与查询语义无关的段落；
- *教师蒸馏：* ColBERTv2 使用 cross-encoder 为候选文档打分，再通过蒸馏监督和更具挑战性的负样本提升检索质量。

*索引与服务。* 建立索引时，所有文档的 token embedding 都会提前计算并存储；收到查询时，只需要实时编码查询 token，再与索引中的文档表示计算 MaxSim。这种设计带来以下特点：

- *离线文档编码：* 文档只编码一次，之后可以服务多次查询；
- *更大的索引：* 原始 ColBERT 每篇文档需要存储约 $abs(d) times 128$ 个数，通常明显大于只保存一个向量的稠密检索方法；
- *ColBERTv2 压缩：* 使用质心编号与量化残差近似保存 token embedding，在尽量保持检索质量的同时，将后期交互表示的存储空间缩小约 $6$ 到 $10$ 倍；
- *PLAID 加速：* PLAID 先利用质心交互与质心剪枝快速筛选候选文档，只对少量候选加载残差并执行更精确的 MaxSim，从而降低后期交互检索的延迟。

== 参考资料

- Haggai Roitman. [The Hitchhiker's Guide to Agentic AI: From Foundations to Systems — Chapter 16: Retrieval-Augmented Generation (RAG)](https://arxiv.org/html/2606.24937v2#Ch16). arXiv:2606.24937v2, 2026。本文内容主要参考该章。
- Thibault Formal, Benjamin Piwowarski, and Stéphane Clinchant. [SPLADE: Sparse Lexical and Expansion Model for First Stage Ranking](https://arxiv.org/abs/2107.05720). arXiv:2107.05720, 2021.
- Thibault Formal, Carlos Lassance, Benjamin Piwowarski, and Stéphane Clinchant. [SPLADE v2: Sparse Lexical and Expansion Model for Information Retrieval](https://arxiv.org/abs/2109.10086). arXiv:2109.10086, 2021.
- Omar Khattab and Matei Zaharia. [ColBERT: Efficient and Effective Passage Search via Contextualized Late Interaction over BERT](https://arxiv.org/abs/2004.12832). arXiv:2004.12832, 2020.
- Keshav Santhanam, Omar Khattab, Jon Saad-Falcon, Christopher Potts, and Matei Zaharia. [ColBERTv2: Effective and Efficient Retrieval via Lightweight Late Interaction](https://arxiv.org/abs/2112.01488). arXiv:2112.01488, 2021.
- Keshav Santhanam, Omar Khattab, Christopher Potts, and Matei Zaharia. [PLAID: An Efficient Engine for Late Interaction Retrieval](https://arxiv.org/abs/2205.09707). arXiv:2205.09707, 2022.
