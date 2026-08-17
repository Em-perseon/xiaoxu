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
    这是因为DPR 这个经典方法在原论文中使用两个独立的 BERT 编码器。\
    但用decoder-only也行我觉得，现在没有统一成 decoder-only。生产环境仍大量使用高效的 encoder embedding；但强性能 embedding 的前沿明显越来越多地利用 Qwen/Mistral 等大型 foundation LLM 作为 backbone。
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

== 分块策略
1. 带重叠的固定大小分块：每W个toekn切分一次，相邻文本块之间保留O个token的重叠。
2. 语义分块：使用句子或段落作为分块单位，确保每个块在语义上是完整的。
3. 感知文档结构的分块：对于结构化文档，按照其自然边界进行划分。
   - Markdown：在标题处切分；
   - HTML：在 `<section>`、`<article>` 标签处切分；
   - 代码：在函数定义或类定义处切分；
   - 表格：将整个表格作为一个整体，不在表格内部切分。
4. 父子分块：
    - 对于层次结构的文档，可以将父块和子块分别作为独立的检索单元；
    - 在检索时，先检索父块，再根据需要检索子块，以提高检索效率和准确性。


== 高级RAG模式
=== 查询转换
  用户在查询的时候往往不会输出一个比较完整的东西，查询会比较含糊、过短与文档匹配性比较差，查询转换技术就是会在搜索步骤之前改进检索。
  1. HyDE（Hypothetical Document Embeddings）不对查询做embedding，而是先生成一个假设答案，再对它进行embedding。背后的直觉来源于假设答案与真实文档之间是比较相似的，那么就通过这个假设的答案作为桥梁，沟通起query和document了。

  2. Step-Back Prompting：对于一个具体的问题，生成一个更一般的回退问题。同时检索合并后的原问题和回退问题。比如问在两个大气压下，水的沸点是多少？回退问题可以是“水的沸点受哪些因素影响？”，然后检索两个问题的结果。

  3. 多查询生成：生成M个多样化的查询改写，分别检索，然后合并结果。

=== 重排序
  第一阶段#footnote[第一阶段Embedding 检索只是在向量空间判断“语义像不像”，所以前 10 个未必就是真正最能回答问题的 10 个。]先“粗召回”一批可能相关的文档，第二阶段再精细判断它们到底谁最相关，然后重新排序。
  具体就是在初始检索到top-k候选后，cross-encoder会把query和候选文档拼接在一起，输入到一个BERT模型中，输出一个相关性分数，然后根据这个分数重新排序。

=== 上下文压缩
  检索到文本块被一些无关的段落包裹，就调用llm只抽取相关部分

=== Self-RAG
  训练耽搁模型来（1）决定是否检索，（2）在有检索或无检索的情况下生成，（3）使用特殊反思token批判自己的输出

=== CRAG：纠错式RAG
  CRAG会增加一个检索评估器，对检索到的文档评分并触发纠正动作：
  1. 检索top-k文档
  2. 为每个文档评分：正确/含糊/错误
  3. 如果所有文档都错误或含糊->回退到web索索
  5. 基于精炼后的上下文生成答案

=== Adaptive RAG
  Adaptive RAG根据预测复杂度将查询路由到不同检索策略：
  1. 不检索：模型可以从参数中回答的简答事实查询
  2. 单步RAG：面向中等难度查询的标准检索后盛出
  3. 多步RAG：面向复杂多跳问题的迭代检索
  训练一个用户查询复杂度标签训练的轻量分类器为每个传入查询选择对应的路径

=== Graph RAG
  Graph RAG从文档语料库当中构建知识图谱，并使用社区发现生成分层摘要：
  1. 实体抽取：LLM从每个文本块当中抽取实体和关系
  2. 图构建：构建图G=(V,E)，其中V是实体节点，E是关系边
  3. 社区#footnote[“社区”就是图里内部连接很紧密的一组节点。]发现：使用Leiden算法#footnote[Leiden 算法就是一种根据图中节点连接关系，把联系紧密的节点自动划分成不同社区的图聚类算法。]，在多个分辨率上寻找社区
  4. 社区摘要：LLM为每个社区生成摘要
  5. 查询：对全局查询，在社区摘要上做map-reduce#footnote[种把大任务拆成很多小任务并行处理（Map），再把这些小任务的结果汇总起来（Reduce）的方法]；对局部查询，使用标准向量搜索

  #html.elem("div", attrs: (class: "graph-rag-guide"))[
    *什么时候使用 Graph RAG？*

    - *使用 Graph RAG：* 当查询需要跨大量文档综合信息、归纳主题或发现整体关系时，例如“What are the main themes in this corpus?”（这个语料库的主要主题是什么？）。
    - *使用标准 RAG：* 当查询只需要定位少量相关片段或回答局部事实时，例如“What did document X say about topic Y?”（文档 X 对主题 Y 说了什么？）。
    - *需要权衡的成本：* Graph RAG 需要额外完成实体与关系抽取、图构建、社区发现和摘要维护，因此构建成本、更新成本与系统复杂度通常都高于标准 RAG。
  ]

=== RAG-Fusion
  RAG-Fusion从原始查询生成多个搜索查询，分别检索，并使用RRF融合排序列表

== 高效RAG解码：REFRAG
  RAG的解码延迟指的是检索结果已经拿到之后，LLM 根据 Query + 检索到的文档逐 token 生成答案所花的时间。拼接进 LLM 上下文的检索段落通常很长，但只有少量内容相关，从而增加首 token 延迟（TTFT）和 KV cache 内存。REFRAG注意到一个现象：检索回来的段落彼此独立（它们是在重排序阶段经过多样化或去重后挑出来的），因此注意力模式呈块对角结构—跨段落的注意力大多接近于零。这种稀疏性说明，解码时在 RAG 上下文上做的大部分计算其实都是多余的。

  Compress-Sense-Expand框架 REFRAG通过三阶段解码策略利用这种结构：

  Compress：不会把检索到的长文档里每个 token 的 KV 都保存下来，而是把一段文本的多组 KV 压缩成少数几个“代表向量”，从而减少显存占用和计算量。假设一个检索段落包含 1000 个 token，压缩前需要保存：

  $
    op("KV")_"before"
    = ((K_1, V_1), (K_2, V_2), dots, (K_1000, V_1000))
  $

  如果将每 50 个连续 token 分为一组，并分别对 Key 和 Value 做 mean pooling，那么第 $j$ 组的代表向量为：

  $
    bar(K)_j
    = frac(1, 50)
      sum_(i=50(j-1)+1)^(50j) K_i,
    quad
    bar(V)_j
    = frac(1, 50)
      sum_(i=50(j-1)+1)^(50j) V_i,
    quad j = 1, dots, 20
  $

  压缩后只需要保存 20 组代表 KV：

  $
    op("KV")_"after"
    = ((bar(K)_1, bar(V)_1), (bar(K)_2, bar(V)_2), dots, (bar(K)_20, bar(V)_20))
  $

  因此，KV 组数从 1000 减少到 20，保留比例为 $20 / 1000 = 1 / 50 = 2%$，即减少约 $98%$#footnote[可以把它理解为：将检索文本的“逐 token 记忆”压缩成少量“分组摘要记忆”。]。

  Sense：在每个解码步骤，对压缩表示执行轻量注意力，以识别哪些段落块与当前token相关#footnote[就是每准备生成下一个 token 时，模型先用轻量注意力去检查那些压缩后的段落块，判断“生成当前这个 token，哪些段落最有用？”]。

  Expand：只为呗选中的块重建完整KV条目，并在稀疏活跃集合上执行精确注意力

  #html.elem("div", attrs: (class: "refrag-agent-box"))[
    *为什么 REFRAG 对智能体式 RAG 很重要*

    智能体式 RAG 对每个查询都要进行多轮检索，延迟会随着检索—推理—生成循环层层累加。像 REFRAG 这样的高效解码方法是不可或缺的基础设施：它们让每一轮的解码成本随上下文长度次线性增长，从而使迭代式的检索—推理—生成循环在大规模场景下依然可行。
  ]

== 智能体RAG
=== 动机：静态RAG的局限
  标准RAG遵循固定的先检索后生成模式#footnote[在标准情况下，用户query返回一个document，简单来说就是普通 RAG：我帮你查一次。Agentic RAG：你自己边想边查，prompt 告诉你该怎么查。]。它会在以下场景中失败：
  1. 多跳问题：“Who founded the company that acquired OpenAI’s main competitor in 2023?”需要串联多次检索#footnote[就是这个问题llm不是只搜索一次，因为第一次检索到的信息可能只解决问题的一部分。llm可能会想Openai是什么？然后联想competitor这样]
  2. 含糊查询：正确检索策略取决于已经找到的内容
  3. 异构来源：不同子问题需要不同知识库
  4. 迭代式细化：初始检索可能揭示需要另一个查询

  #html.elem("div", attrs: (class: "router-policy-box agentic-mdp-box"))[
    *把 RAG 视为马尔可夫决策过程*

    智能体式 RAG 将检索表述为一个序贯决策问题，可以将其形式化为：

    - *状态：* 当前上下文，即原始查询与截至当前已经检索到的文档；
    - *动作：* 检索、推理、生成以及停止；
    - *奖励：* 最终答案的正确性。

    在这个视角下，智能体学习的是一个“何时检索、检索什么以及何时停止”的策略，而不是始终执行固定次数的检索。
  ]

=== 智能体RAG的架构
=== 多源路由
  智能体式 RAG 系统可以把不同的子查询路由到专门的知识源。道理很简单：不同类型的问题需要不同的检索后端—没有哪一个索引能在所有场景下都做到最好。

  为什么需要路由？考虑下面的金融分析助手的处理四类查询的场景：
  1. “What is our company’s PTO policy?” → 向量数据库（内部文档）
  2. “What did the Fed announce yesterday?” → Web 搜索（实时）
  3. “Show Q3 revenue by region” → SQL 数据库（结构化数据）
  4. “How does our auth middleware validate tokens?” → 代码索引（代码库）

  从单一索引平铺检索的方法要么找不到答案，要么返回无关段落。路由会在检索开始前为对应子问题选择正确工具。

  #figure(caption: "智能体式 RAG 控制流。智能体会迭代地规划、检索、评估充分性，并在返回答案前自检依据")[
  #image("rag_agent.png", width: 70%)
]

  *路由策略*：主要有以下三种方法：
  1. 基于规则的路由。关键词处罚（比如提到了SQL->数据库，URL模式->Web）。速度快且可解释，但对含糊查询很脆弱。
  2. 基于分类器的路由：轻量模型（例如微调后的 BERT 分类器，或查询 embedding 上的逻辑回归）预测最佳来源。延迟通常低于 10 ms，并可基于路由日志训练，但需要标注数据。
  3. 基于 LLM 的路由。LLM 自身在结构化输出调用中决定来源（见下面的 Listing）。最灵活—能处理新的查询类型并解释其推理—但会增加一次 LLM 调用延迟。

  #html.elem("div", attrs: (class: "router-policy-box"))[
    *学习策略的路由器*

    多源路由在最简单的形式下是一个分类问题，在最丰富的形式下则是一个规划问题。把路由器视为强化学习策略时，可以将其形式化为：

    - *状态：* 当前查询与对话历史；
    - *动作：* 选择知识来源，以及可选的查询重写；
    - *奖励：* 最终生成答案的质量。

    在这种定义下，路由器可以通过策略梯度技术（第八章）进行端到端优化，让来源选择与查询改写直接服务于下游答案质量。
  ]

  *实践考虑*
  1. 回退链: 如果主来源返回低置信度结果，尝试次优来源。
  2. 并行扇出: 对含糊查询，同时从多个来源检索，并通过 Reciprocal Rank Fusion融合结果。
  3. 成本意识: Web 搜索和 API 调用可能有金钱成本或速率限制；路由器应将这些因素纳入考虑。
  4. 可观测性: 记录每个路由决策及其理由—这对于调试和重新训练至关重要

=== 完整智能体式RAG实现
前面的章节介绍了单个组件—路由、检索、评估。一个完整的智能体式 RAG 系统会将这些组件编排为有状态节点图，其控制流取决于中间结果。下面的实现使用 LangGraph 将四个节点连接成一个循环：

1. Plan: 将用户查询分解为子查询（每个信息需求一个）。
2. Retrieve: 将每个子查询路由到合适来源并获取文档。
3. Evaluate: 判断累积上下文是否足以回答原始查询。
4. Generate: 使用检索文档中的引用综合最终答案。

关键设计模式是条件循环：评估后，智能体要么进入生成（如果上下文足够或迭代预算耗尽），要么带着细化后的子查询回到检索。这对应了 RL 智能体在信息收集动作上运行时的感知-动作-评估循环。

=== 工具增强RAG
  智能体还可以通过将检索与计算工具进行结合

=== Search-R1：通过RL训练的智能体式RAG
  上面的智能体式 RAG 方法依赖提示工程式编排 — 智能体的搜索行为由指令控制，而不是通过训练学得。Search-R1采用一种根本不同的方法：它通过强化学习训练 LLM，使其在推理过程中学习何时搜索、搜索什么以及搜索多少次。

  核心思想。 Search-R1 扩展了 DeepSeek-R1推理框架，将搜索引擎查询视为 RL 训练循环中的动作。在思维链生成期间，模型可以发出特殊 token <search>query</search> 来触发从搜索引擎实时检索。检索结果会被注入回推理上下文，模型随后继续生成。

  形式化设置。模型生成一条由推理内容与搜索动作交错组成的轨迹：

  $
    underbrace(op("think")_1, "reasoning")
    arrow.r
    underbrace("<search>" q_1 "</search>", "action")
    arrow.r
    underbrace([op("results")_1], "observation")
    arrow.r
    op("think")_2
    arrow.r
    "<search>" q_2 "</search>"
    arrow.r
    dots
    arrow.r
    op("answer")
  $

  其中，`think` 表示模型的推理过程，`<search>q_i</search>` 表示第 $i$ 次搜索动作，`results_i` 表示搜索引擎返回的观察结果。整条轨迹——包括推理、搜索和最终答案——由一个终端奖励统一打分；该奖励取决于最终答案相对于真值标签的正确性。

  #figure(caption: "Search-R1（RL 训练）与基于 prompt 的智能体式 RAG 对比")[
    #table(
      columns: (0.9fr, 1.5fr, 1.25fr),
      align: (left, left, left),
      inset: 8pt,
      stroke: 0.6pt + rgb("d8dee8"),
      table.header(
        [*维度*],
        [*基于 prompt 的智能体式 RAG*],
        [*Search-R1*],
      ),
      [搜索决策],
      [Prompt／启发式],
      [通过 RL 学得],
      [查询构造],
      [Prompt 驱动（如“rewrite query”）],
      [端到端训练],
      [搜索次数],
      [固定，或由 LLM 在推理时决定],
      [学习最优次数],
      [训练信号],
      [无（模型冻结）],
      [正确性奖励],
      [搜索整合],
      [追加到上下文],
      [与 CoT 交错],
      [失败恢复],
      [重试启发式],
      [学习回退或查询改写],
      [模型推理开销],
      [框架开销（如 LangGraph）],
      [模型原生行为],
    )
  ]

  #html.elem("div", attrs: (class: "router-policy-box search-r1-shift-box"))[
    *Search-R1：范式转变*

    - *传统 RAG 问的是：* “面对这个查询，我该检索些什么？”这是在生成之前便确定下来的流程决策。
    - *Search-R1 问的是：* “根据目前已经推理到的程度，我还需要更多信息吗？如果需要，提出哪个具体问题才能补上这块缺口？”这是在生成过程中做出的、可以通过训练学习的决策。

    这就像两种学生：一种在开考前先把课本整体翻一遍；另一种则是在解题途中发现卡住时，才有针对性地查找参考资料。后者通常更高效，也更有的放矢。
  ]

== 评估

评估 RAG 系统比单独评估检索器或生成器更困难，因为错误可能出现在流程中的任何一环，并且会逐层累积。再完善的生成器也无法弥补一次无关的检索；反过来，再完善的检索结果，一旦遇到产生幻觉或忽略上下文的生成器，也只能被浪费。

因此，有效的 RAG 评估需要同时覆盖三个层次：

1. *检索质量：* 检索器是否找到了正确段落？常用指标包括 Recall、Precision、MRR 和 NDCG；
2. *生成质量：* 答案是否正确、忠实于检索上下文并且完整？常见维度包括 Correctness、Faithfulness 和 Answer Relevance；
3. *端到端质量：* 完整系统是否真正满足用户需求？可以通过人类偏好、任务成功率和延迟调整后的效用进行评估。

一个常见失败模式是只优化其中一个层次。例如，使用很大的 $K$ 最大化 Recall@$K$，可能会让上下文充满边缘相关段落，反而降低最终生成质量。下面的指标同时覆盖检索结果的召回、准确性与排序质量，从而帮助判断系统瓶颈出现在哪个阶段。

=== 检索指标

令 $cal(R)_K$ 表示针对某个查询返回的前 $K$ 个检索文档集合，$cal(R)^star$ 表示该查询的相关文档集合。

*Recall@$K$。* 衡量全部相关文档中，有多少出现在前 $K$ 个检索结果里：

$
  op("Recall@K")
  = frac(
    abs(cal(R)_K ∩ cal(R)^star),
    abs(cal(R)^star)
  )
$

*Precision@$K$。* 衡量前 $K$ 个检索结果中，有多少是真正相关的文档：

$
  op("Precision@K")
  = frac(
    abs(cal(R)_K ∩ cal(R)^star),
    K
  )
$

*Mean Reciprocal Rank（MRR）。* 只关注每个查询首次出现相关文档的位置，并对其排名取倒数：

$
  op("MRR")
  = frac(1, abs(cal(Q)))
    sum_(i=1)^abs(cal(Q))
    frac(1, op("rank")_i)
$

其中，$cal(Q)$ 表示查询集合，$op("rank")_i$ 表示查询 $i$ 的第一个相关文档在结果列表中的排名；如果没有检索到相关文档，该查询的倒数排名记为零。

*Normalized Discounted Cumulative Gain（NDCG@$K$）。* 在考虑排名位置的同时，允许每个结果具有不同等级的相关性：

$
  op("NDCG@K")
  = frac(op("DCG@K"), op("IDCG@K")),
  quad
  op("DCG@K")
  = sum_(i=1)^K
    frac(op("rel")_i, log_2(i + 1))
$

其中，$op("rel")_i in {0, 1, 2, dots}$ 表示第 $i$ 个检索结果的分级相关性，$op("IDCG@K")$ 表示理想排序下能够获得的最大 DCG。

=== 生成指标

*忠实性（Faithfulness）。* 衡量生成答案是否以检索上下文为依据，也就是答案中的每一个事实性主张能否在检索文档中找到支持。该指标通常可以通过 LLM judge 拆分并核验答案中的主张：

$
  op("Faithfulness")
  = frac(
    "能够被检索上下文支持的主张数量",
    "答案中的主张总数"
  )
$

忠实性越高，表示答案越少包含脱离检索证据的幻觉内容。

*答案相关性（Answer Relevance）。* 衡量答案是否真正回应了原始问题。一种计算方式是从答案中反向生成 $N$ 个问题 $hat(q)_i$，再比较这些问题与原始查询 $q$ 的 embedding 相似度：

$
  op("AnswerRelevance")
  = frac(1, N)
    sum_(i=1)^N
    cos(E(q), E(hat(q)_i))
$

其中，$E(q)$ 表示原始查询的 embedding，$E(hat(q)_i)$ 表示根据答案生成的第 $i$ 个问题的 embedding。如果答案确实回应了原问题，反向生成的问题通常会与原查询更加相似。

*上下文精确率（Context Precision@$K$）。* 衡量相关文档是否集中在检索列表的靠前位置：

$
  op("ContextPrecision@K")
  = frac(1, K)
    sum_(k=1)^K
    op("Precision@k")
    dot 1[op("doc")_k "相关"]
$

其中，$1[op("doc")_k "相关"]$ 是指示函数：当第 $k$ 个文档相关时取 1，否则取 0。相关文档出现得越早，上下文精确率越高。

*上下文召回率（Context Recall）。* 衡量回答真值中需要的事实，有多少能够归因于当前检索上下文：

$
  op("ContextRecall")
  = frac(
    "可以归因于检索上下文的真值主张数量",
    "真值主张总数"
  )
$

上下文召回率较低意味着检索阶段遗漏了回答问题所需的关键信息，即使生成器本身能力很强，也难以生成完整答案。

=== RAGAs
  RAGAs（Retrieval Augmented Generation Assessment）提供了一个使用 LLM judge 的无参考评估框架#footnote[就是调用llm来评估针对用户的query的一套“检索得好不好 + 最终回答得好不好”的评测框架。]

=== 常见失败模式

#html.elem("div", attrs: (class: "rag-failure-box"))[
  #html.elem("div", attrs: (class: "rag-failure-title"))[需要监控的 RAG 失败模式]
  #html.elem("div", attrs: (class: "rag-failure-body"))[
    1. *检索遗漏：* 相关文档存在于语料库中，却没有被检索到。常见原因包括分块质量较差、embedding 模型不匹配，以及查询与文档之间存在较大的词汇差异。
    2. *上下文污染：* 检索到的文档包含错误、无关或彼此矛盾的信息，导致模型基于受污染的上下文生成错误答案。
    3. *Lost-in-the-Middle：* LLM 往往更关注长上下文的开头和结尾，位于中间位置的相关信息可能被忽略。
    4. *过度检索：* 检索过多文本块会稀释真正相关的信号，同时增加上下文长度、推理延迟与调用成本。
    5. *检索后仍然幻觉：* 模型忽略已经检索到的上下文，转而依靠参数化记忆生成答案，尤其容易发生在检索内容与训练数据相互矛盾时。
    6. *编造引用：* 模型将某个主张错误地归因于并不支持该主张的文档，形成看似有依据、实际无法验证的引用。
  ]
]

== RAG 与微调的协同

=== 何时结合 RAG 与微调

微调与 RAG 解决的是彼此互补的问题：

- *仅微调：* 模型可以学会特定的表达风格、输出格式和任务行为，但仍然可能产生事实性幻觉；
- *仅 RAG：* 模型可以访问外部事实，却不一定知道如何以最佳方式使用这些事实；
- *结合使用：* 微调模型学习如何利用检索上下文，例如引用信息来源、承认不确定性，以及忽略与问题无关的上下文。

=== RAFT：检索增强微调

RAFT（Retrieval-Augmented Fine-Tuning）使用相关文档与干扰文档的混合上下文训练模型回答问题，使模型学会识别并只使用真正相关的证据：

1. 对每个训练样本 $(q, a, d^star)$，额外采样 $k - 1$ 个干扰文档 ${d_i^-}$；
2. 将查询、相关文档和干扰文档共同作为微调输入：

$
  [q, d^star, d_1^-, dots, d_(k - 1)^-]
  arrow.r
  [op("chain-of-thought") + a]
$

3. 在思维链中显式引用相关文档 $d^star$，使答案建立在可识别的检索证据上。

RAFT 的训练目标可以写为：

$
  cal(L)_"RAFT"
  = -op("E")_((q, a, d^star, {d_i^-}))
    [
      log P_theta(
        op("CoT")(d^star) ⊕ a
        | q, d^star, {d_i^-}
      )
    ]
$

其中，$q$ 是查询，$a$ 是目标答案，$d^star$ 是与问题相关的文档，${d_i^-}$ 是干扰文档集合，$theta$ 表示生成模型参数。

=== 检索器—生成器联合训练

为了获得更高的端到端性能，可以联合训练检索器和生成器，使最终答案的训练信号通过生成步骤反向影响检索策略。令 $P_phi(d | q)$ 表示检索器为文档 $d$ 分配的概率，$P_theta(a | q, d)$ 表示生成器基于查询和文档生成答案的概率，则联合目标可以写为：

$
  nabla_(theta, phi) cal(L)
  = nabla_(theta, phi)
    [
      -log
      sum_(d in cal(D))
      P_theta(a | q, d)
      dot P_phi(d | q)
    ]
$

检索器参数 $phi$ 可以通过 REINFORCE 估计器更新，也可以将 $P_phi(d | q)$ 视为文档上的可微注意力分布进行优化。

#html.elem("div", attrs: (class: "router-policy-box joint-training-box"))[
  *联合训练的挑战*

  1. 随着检索器参数 $phi$ 持续变化，文档索引必须周期性刷新，通常需要采用异步索引更新；
  2. 训练信号较为稀疏，因为只有进入 top-$k$ 的少量文档能够对当前答案产生贡献；
  3. 如果检索器没有使用预训练参数进行良好初始化，联合训练过程可能不稳定。
]

== 参考资料

- Haggai Roitman. [The Hitchhiker's Guide to Agentic AI: From Foundations to Systems — Chapter 16: Retrieval-Augmented Generation (RAG)](https://arxiv.org/html/2606.24937v2#Ch16). arXiv:2606.24937v2, 2026。本文内容主要参考该章。
- Thibault Formal, Benjamin Piwowarski, and Stéphane Clinchant. [SPLADE: Sparse Lexical and Expansion Model for First Stage Ranking](https://arxiv.org/abs/2107.05720). arXiv:2107.05720, 2021.
- Thibault Formal, Carlos Lassance, Benjamin Piwowarski, and Stéphane Clinchant. [SPLADE v2: Sparse Lexical and Expansion Model for Information Retrieval](https://arxiv.org/abs/2109.10086). arXiv:2109.10086, 2021.
- Omar Khattab and Matei Zaharia. [ColBERT: Efficient and Effective Passage Search via Contextualized Late Interaction over BERT](https://arxiv.org/abs/2004.12832). arXiv:2004.12832, 2020.
- Keshav Santhanam, Omar Khattab, Jon Saad-Falcon, Christopher Potts, and Matei Zaharia. [ColBERTv2: Effective and Efficient Retrieval via Lightweight Late Interaction](https://arxiv.org/abs/2112.01488). arXiv:2112.01488, 2021.
- Keshav Santhanam, Omar Khattab, Christopher Potts, and Matei Zaharia. [PLAID: An Efficient Engine for Late Interaction Retrieval](https://arxiv.org/abs/2205.09707). arXiv:2205.09707, 2022.
