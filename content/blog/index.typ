#import "../index.typ": template, tufted

#show: template.with(
  title: "Blog",
)

#html.elem("a", attrs: (class: "back-link", href: "/xiaoxu/"))[← 返回首页]

= Blog

#html.elem("nav", attrs: (class: "section-index", aria-label: "博客文章"))[
  #html.elem("a", attrs: (href: "agent-evaluation-harness/"))[#html.elem("span")[别只看 Agent 的最后一句话] #html.elem("b")[2026 · 10 · 02　→]]
  #html.elem("a", attrs: (href: "tinkering/"))[#html.elem("span")[瞎折腾] #html.elem("b")[专题　→]]
  #html.elem("a", attrs: (href: "backlog/"))[#html.elem("span")[补坑] #html.elem("b")[专题　→]]
  #html.elem("a", attrs: (href: "hello-world/"))[#html.elem("span")[第一篇文章] #html.elem("b")[→]]
]
