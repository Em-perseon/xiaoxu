#import "../../../config.typ": template, tufted

#show: template.with(
  title: "课程笔记",
)

#html.elem("a", attrs: (class: "back-link", href: "/xiaoxu/docs/"))[← 返回 Docs]

= 课程笔记

#html.elem("nav", attrs: (class: "section-index", aria-label: "课程专题"))[
  #html.elem("a", attrs: (href: "advanced-econometrics/"))[#html.elem("span")[高级计量经济学] #html.elem("b")[→]]
  #html.elem("a", attrs: (href: "advanced-microeconomics/"))[#html.elem("span")[高级微观经济学] #html.elem("b")[→]]
]
