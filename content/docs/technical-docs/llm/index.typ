#import "../../../index.typ": template, tufted

#show: template.with(
  title: "大语言模型的漫游指南",
)

#html.elem("a", attrs: (class: "back-link", href: "/xiaoxu/docs/technical-docs/"))[← 返回技术文档]

= 大语言模型的漫游指南

#html.elem("nav", attrs: (class: "section-index", aria-label: "大语言模型专题"))[
  #html.elem("a", attrs: (href: "rag/"))[#html.elem("span")[检索增强生成（RAG）] #html.elem("b")[→]]
  #html.elem("a", attrs: (href: "reinforcement-learning/"))[#html.elem("span")[强化学习入门] #html.elem("b")[→]]
]
