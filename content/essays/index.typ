#import "../../config.typ": template, tufted

#show: template.with(
  title: "Essays",
)

#html.elem("a", attrs: (class: "back-link", href: "/xiaoxu/"))[← 返回首页]

= Essays

#html.elem("nav", attrs: (class: "section-index", aria-label: "随笔"))[
  #html.elem("a", attrs: (href: "2026-06-25-discussion/"))[#html.elem("span")[一次讨论] #html.elem("b")[2026 · 06 · 25　→]]
  #html.elem("a", attrs: (href: "2026-06-23-throatache/"))[#html.elem("span")[生病小记] #html.elem("b")[2026 · 06 · 23　→]]
  #html.elem("a", attrs: (href: "2026-06-01-experiment-notes/"))[#html.elem("span")[实验小记] #html.elem("b")[2026 · 06 · 01　→]]
  #html.elem("a", attrs: (href: "2026-05-25-first/"))[#html.elem("span")[为什么想要随笔] #html.elem("b")[2026 · 05 · 25　→]]
]
