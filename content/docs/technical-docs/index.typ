#import "../../../config.typ": template, tufted

#show: template.with(
  title: "技术文档",
)

#html.elem("a", attrs: (class: "back-link", href: "/xiaoxu/docs/"))[← 返回 Docs]

= 技术文档

#html.elem("nav", attrs: (class: "section-index", aria-label: "技术专题"))[
  #html.elem("a", attrs: (href: "llm/"))[#html.elem("span")[大语言模型的漫游指南] #html.elem("b")[→]]
]
