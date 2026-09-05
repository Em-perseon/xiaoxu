#import "../../config.typ": template, tufted

#show: template.with(
  title: "Timeline",
)

#html.elem("a", attrs: (class: "back-link", href: "/xiaoxu/"))[← 返回首页]

= Timeline

#html.elem("div", attrs: (class: "timeline"))[
  #html.elem("article", attrs: (class: "timeline-item"))[
    #html.elem("time", attrs: (datetime: "2026-09-05"))[2026 · 09 · 05]
    #html.elem("div", attrs: (class: "timeline-content"))[
      #html.elem("h3")[我要成为菲律宾人]
      #html.elem("p")[记录在 ChatGPT 方案页面变化后，如何通过 Clash Verge 和代理节点继续折腾菲律宾区方案的过程。]
      #html.elem("p", attrs: (class: "timeline-link"))[#link("/xiaoxu/blog/tinkering/clash-verge-node/")[阅读这次折腾 →]]
    ]
  ]

  #html.elem("article", attrs: (class: "timeline-item"))[
    #html.elem("time", attrs: (datetime: "2026-08-23"))[2026 · 08 · 23]
    #html.elem("div", attrs: (class: "timeline-content"))[
      #html.elem("h3")[智能体记忆系统深化]
      #html.elem("p")[补充多轮对话记忆、多智能体共享记忆、强化学习训练记忆系统、记忆评估指标与长期评估缺口，并总结记忆系统的架构、操作和开放问题。]
      #html.elem("p", attrs: (class: "timeline-link"))[#link("/xiaoxu/docs/technical-docs/llm/agent-memory/")[阅读智能体记忆系统 →]]
    ]
  ]

  #html.elem("article", attrs: (class: "timeline-item"))[
    #html.elem("time", attrs: (datetime: "2026-08-20"))[2026 · 08 · 20]
    #html.elem("div", attrs: (class: "timeline-content"))[
      #html.elem("h3")[群组相对策略优化（GRPO）]
      #html.elem("p")[整理 GRPO 与 PPO 的差异、组内相对优势、裁剪目标、参考模型 KL 正则，以及 LLM 中去掉 Critic 后的训练流程。]
      #html.elem("p", attrs: (class: "timeline-link"))[#link("/xiaoxu/docs/technical-docs/llm/reinforcement-learning/grpo/")[阅读 GRPO 笔记 →]]
    ]
  ]

  #html.elem("article", attrs: (class: "timeline-item"))[
    #html.elem("time", attrs: (datetime: "2026-08-19"))[2026 · 08 · 19]
    #html.elem("div", attrs: (class: "timeline-content"))[
      #html.elem("h3")[PPO 与 LLM 对齐]
      #html.elem("p")[整理 PPO 的重要性采样、GAE、裁剪目标与 Actor-Critic 流程，并补充 LLM 中 policy、reference、value、reward 四类模型、per-token KL 奖励和实际损失实现。]
      #html.elem("p", attrs: (class: "timeline-link"))[#link("/xiaoxu/docs/technical-docs/llm/reinforcement-learning/ppo/")[阅读 PPO 笔记 →]]
    ]
  ]

  #html.elem("article", attrs: (class: "timeline-item"))[
    #html.elem("time", attrs: (datetime: "2026-08-18"))[2026 · 08 · 18]
    #html.elem("div", attrs: (class: "timeline-content"))[
      #html.elem("h3")[智能体记忆系统]
      #html.elem("p")[创建智能体记忆系统专题，整理认知架构中的四类记忆，并补充基于 RAG、摘要和知识图谱的记忆组织方式。]
      #html.elem("p", attrs: (class: "timeline-link"))[#link("/xiaoxu/docs/technical-docs/llm/agent-memory/")[阅读智能体记忆系统 →]]
    ]
  ]

  #html.elem("article", attrs: (class: "timeline-item"))[
    #html.elem("time", attrs: (datetime: "2026-08-17"))[2026 · 08 · 17]
    #html.elem("div", attrs: (class: "timeline-content"))[
      #html.elem("h3")[智能体 RAG、评估与微调]
      #html.elem("p")[补充智能体式 RAG 的 MDP 与路由视角、Search-R1 训练范式、RAG 检索与生成评估指标、常见失败模式，以及 RAFT 和检索器—生成器联合训练。]
      #html.elem("p", attrs: (class: "timeline-link"))[#link("/xiaoxu/docs/technical-docs/llm/rag/")[阅读 RAG 笔记 →]]
    ]
  ]

  #html.elem("article", attrs: (class: "timeline-item"))[
    #html.elem("time", attrs: (datetime: "2026-08-16"))[2026 · 08 · 16]
    #html.elem("div", attrs: (class: "timeline-content"))[
      #html.elem("h3")[高级 RAG 模式]
      #html.elem("p")[整理文档分块、查询转换、重排序、上下文压缩、Self-RAG、CRAG、Adaptive RAG、Graph RAG 与 RAG-Fusion，并补充 Graph RAG 的适用场景判断。]
      #html.elem("p", attrs: (class: "timeline-link"))[#link("/xiaoxu/docs/technical-docs/llm/rag/")[阅读 RAG 笔记 →]]
    ]
  ]

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
