#import "../../../../../config.typ": template, tufted

#show: template.with(
  title: "检索增强生成（RAG）",
)

#html.elem("a", attrs: (class: "back-link", href: "/xiaoxu/docs/technical-docs/llm/"))[← 返回大语言模型的漫游指南]

= 检索增强生成（RAG）

== 引言

大模型本质是以参数化将知识存储到自己的内部，即一个又一个权重。这带来几个问题：
1. 幻觉：超出参数范围的知识，模型会凭空生成内容；
2. 过时：模型训练时的知识是静态的，无法及时更新
3. 领域知识的局限：即通用模型缺乏对于私有代码库、内部文档、专门法规或企业数据的了解

形式化地，令 $M_theta$ 表示参数为 $theta$ 的语言模型，$D = {d_1, d_2, ..., d_n}$ 为外部文档语料库。给定查询 $q$，仅依赖参数化知识时，生成回答 $a$ 的概率可写为：

$ P(a | q) = P_(M_theta)(a | q) $

引入检索后，回答概率对检索到的文档做边际化：

$ P(a | q, D) = sum_(d in D) P_(M_theta)(a | q, d) P_"ret"(d | q, D) $
#tufted.margin-note[
  这边检索分布我的理解是面对这样一个question去对应的完整文档当中找到这个question对应的一个document chunk
]

其中，$P_"ret"(d | q, D)$ 表示在文档上面的检索分布。这时候的生成就建立在了一个外部（非参数化知识）上了。



== 参考资料
