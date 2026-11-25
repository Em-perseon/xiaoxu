#import "../index.typ": template, tufted

#show: template.with(
  title: "Blog",
)

#html.elem("a", attrs: (class: "back-link", href: "/xiaoxu/"))[← 返回首页]

= Blog

#html.elem("nav", attrs: (class: "section-index", aria-label: "博客文章"))[
  #html.elem("a", attrs: (href: "first-steps-in-design-science-research/"))[#html.elem("span")[初入 Design Science Research 有感] #html.elem("b")[2026 · 11 · 25　→]]
  #html.elem("a", attrs: (href: "best-and-worst-of-times/"))[#html.elem("span")[这是一个很好的时代，这也是一个很坏的时代] #html.elem("b")[2026 · 10 · 29　→]]
  #html.elem("a", attrs: (href: "agent-evaluation-harness/"))[#html.elem("span")[别只看 Agent 的最后一句话] #html.elem("b")[2026 · 10 · 02　→]]
  #html.elem("a", attrs: (href: "2026-06-25-discussion/"))[#html.elem("span")[一次讨论] #html.elem("b")[2026 · 06 · 25　→]]
  #html.elem("a", attrs: (href: "2026-06-23-throatache/"))[#html.elem("span")[生病小记] #html.elem("b")[2026 · 06 · 23　→]]
  #html.elem("a", attrs: (href: "2026-06-01-experiment-notes/"))[#html.elem("span")[实验小记] #html.elem("b")[2026 · 06 · 01　→]]
  #html.elem("a", attrs: (href: "2026-05-25-first/"))[#html.elem("span")[为什么想要随笔] #html.elem("b")[2026 · 05 · 25　→]]
  #html.elem("a", attrs: (href: "tinkering/"))[#html.elem("span")[瞎折腾] #html.elem("b")[专题　→]]
  #html.elem("a", attrs: (href: "backlog/"))[#html.elem("span")[补坑] #html.elem("b")[专题　→]]
]
