#import "../index.typ": template, tufted

#show: template.with(
  title: "瞎折腾",
)

#html.elem("a", attrs: (class: "back-link", href: "/xiaoxu/blog/"))[← 返回 Blog]

= 瞎折腾

一个放在 Blog 里的长期专题，记录那些不一定有明确结论的尝试：改网站、做小工具、试新框架、拆解奇怪的问题，以及“先做出来再说”的想法。

这里保留过程、试错和半成品。它可以是一篇完整文章，也可以只是一个短小的实验记录。

== 折腾记录

#html.elem("nav", attrs: (class: "section-index", aria-label: "瞎折腾记录"))[
  #html.elem("a", attrs: (href: "system-one-system-two-guidance/"))[#html.elem("span")[System One 执行，System Two 指导] #html.elem("b")[想法草稿　→]]
  #html.elem("a", attrs: (href: "can-jev-do-scheduling/"))[#html.elem("span")[Can JEV Do Scheduling? A 200-Event Pilot with Structured State and Objective History] #html.elem("b")[2026 · 09 · 23　→]]
  #html.elem("a", attrs: (href: "clash-verge-node/"))[#html.elem("span")[我要成为菲律宾人] #html.elem("b")[开始记录　→]]
]
