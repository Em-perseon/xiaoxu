#import "../../../config.typ": template, tufted

#show: template.with(
  title: "阅读记录",
)

#html.elem("a", attrs: (class: "back-link", href: "/xiaoxu/docs/"))[← 返回 Docs]

= 阅读记录

#html.elem("nav", attrs: (class: "section-index", aria-label: "阅读记录"))[
  #html.elem("a", attrs: (href: "example/"))[#html.elem("span")[示例阅读记录] #html.elem("b")[→]]
]
