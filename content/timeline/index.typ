#import "../../config.typ": template, tufted

#show: template.with(
  title: "Timeline",
)

#html.elem("a", attrs: (class: "back-link", href: "/xiaoxu/"))[← 返回首页]

= Timeline

#html.elem("div", attrs: (class: "timeline"))[
  #html.elem("article", attrs: (class: "timeline-item"))[
    #html.elem("time", attrs: (datetime: "2026-08-15"))[2026 · 08 · 15]
    #html.elem("div", attrs: (class: "timeline-content"))[
      #html.elem("h3")[检索增强生成笔记]
      #html.elem("p")[补充 SPLADE、SPLADEv2 与 ColBERT 的原理、公式和示例，完善完整词汇空间与权重共享的页边注，并增强文档标题层级。]
      #html.elem("p", attrs: (class: "timeline-link"))[#link("/xiaoxu/docs/technical-docs/llm/rag/")[阅读 RAG 笔记 →]]
    ]
  ]

  #html.elem("article", attrs: (class: "timeline-item"))[
    #html.elem("time", attrs: (datetime: "2026-08-13"))[2026 · 08 · 13]
    #html.elem("div", attrs: (class: "timeline-content"))[
      #html.elem("h3")[强化学习专题]
      #html.elem("p")[整理强化学习基础、DQN、策略梯度与 Actor-Critic。]
      #html.elem("p", attrs: (class: "timeline-link"))[#link("/xiaoxu/docs/technical-docs/llm/reinforcement-learning/")[阅读强化学习入门 →]]
    ]
  ]

  #html.elem("article", attrs: (class: "timeline-item"))[
    #html.elem("time", attrs: (datetime: "2026-08-05"))[2026 · 08 · 05]
    #html.elem("div", attrs: (class: "timeline-content"))[
      #html.elem("h3")[文档体系]
      #html.elem("p")[建立“大语言模型的漫游指南”与检索增强生成内容框架，同时加入高级计量经济学和高级微观经济学分类。]
      #html.elem("p", attrs: (class: "timeline-link"))[#link("/xiaoxu/docs/")[浏览文档 →]]
    ]
  ]

  #html.elem("article", attrs: (class: "timeline-item"))[
    #html.elem("time", attrs: (datetime: "2026-06-25"))[2026 · 06 · 25]
    #html.elem("div", attrs: (class: "timeline-content"))[
      #html.elem("h3")[一次讨论]
      #html.elem("p")[记录一段值得留下的讨论。]
      #html.elem("p", attrs: (class: "timeline-link"))[#link("/xiaoxu/essays/2026-06-25-discussion/")[阅读随笔 →]]
    ]
  ]

  #html.elem("article", attrs: (class: "timeline-item"))[
    #html.elem("time", attrs: (datetime: "2026-06-23"))[2026 · 06 · 23]
    #html.elem("div", attrs: (class: "timeline-content"))[
      #html.elem("h3")[生病小记]
      #html.elem("p")[一篇关于生病与生活状态的短记。]
      #html.elem("p", attrs: (class: "timeline-link"))[#link("/xiaoxu/essays/2026-06-23-throatache/")[阅读随笔 →]]
    ]
  ]

  #html.elem("article", attrs: (class: "timeline-item"))[
    #html.elem("time", attrs: (datetime: "2026-06-01"))[2026 · 06 · 01]
    #html.elem("div", attrs: (class: "timeline-content"))[
      #html.elem("h3")[实验小记]
      #html.elem("p")[记录实验过程中的片段与想法。]
      #html.elem("p", attrs: (class: "timeline-link"))[#link("/xiaoxu/essays/2026-06-01-experiment-notes/")[阅读随笔 →]]
    ]
  ]

  #html.elem("article", attrs: (class: "timeline-item"))[
    #html.elem("time", attrs: (datetime: "2026-05-25"))[2026 · 05 · 25]
    #html.elem("div", attrs: (class: "timeline-content"))[
      #html.elem("h3")[为什么想要随笔]
      #html.elem("p")[这个网站最初的一篇随笔。]
      #html.elem("p", attrs: (class: "timeline-link"))[#link("/xiaoxu/essays/2026-05-25-first/")[阅读随笔 →]]
    ]
  ]
]
