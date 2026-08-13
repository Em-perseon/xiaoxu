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
  #html.elem("del")[query 通常短、像搜索意图；document 通常长、包含完整信息。所以专门训练 Query Encoder 可以让它学到“我应该去找什么样的文档”。]

  #html.elem("del")[2026-08-13：感觉这个 Query Encoder 的训练也会有很多研究，尤其是如何让 Query Encoder 和 Document Encoder 在 embedding 空间上对齐。]

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
  稠密段落检索 #footnote[这个的作用是为了找到一个好的q和d的表示]（Dense Passage Retrieval, DPR）使用两个独立的基于 BERT 的编码器—查询编码器$E_(Q)$和段落编码器$E_(P)$—并用对比损失训练，使相关查询-段落对在embedding空间中彼此接近。

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

  训练出对应的查询编码器和段落编码器#footnote[这个段落编码器不一定训练？可以用现成的embedding模型进行直接embedding吗？]后，后面就是比较的事情了，但大规模场景下，对数百万个embedding做枚举#footnote[就是query一条一条与document进行那个similarity计算]不太现实。因此引入了近似最近邻（Approximate Nearest Neighbor, ANN）搜索算法。ANN算法通过构建高效的数据结构（如倒排索引、树结构或图结构）来加速相似度搜索，从而在大规模向量空间中快速找到与查询向量最相似的文档向量。
  1. IVF（Inverted File Index）：将向量空间划分为多个子空间，并为每个子空间建立倒排索引，以便快速定位潜在的近邻。
  2. PQ（Product Quantization）：将向量分解为多个子向量，并对每个子向量进行量化，从而减少存储空间和计算复杂度。
  3. HNSW（Hierarchical Navigable Small World）：构建分层图结构，通过在图中导航来高效地搜索近邻。

=== 混合检索
  混合检索结合了稀疏检索和稠密检索的优点。它通过将两种方法的得分#footnote[就是将最后的similarity得分]进行加权融合，来提高检索的准确性和鲁棒性。混合检索的公式如下：

  $ op("score")_("hybrid")(q, d) = alpha op("score")_("sparse")(q, d) + (1 - alpha) op("score")_("dense")(q, d) $

  其中，$alpha$ 是一个权重参数，用于平衡稀疏检索和稠密检索的贡献。通过调整 $alpha$ 的值，可以在不同场景下优化检索性能。

  不同

== 参考资料
