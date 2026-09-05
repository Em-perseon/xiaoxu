#import "../index.typ": template, tufted

#show: template.with(
  title: "补坑",
)

#html.elem("a", attrs: (class: "back-link", href: "/xiaoxu/blog/"))[← 返回 Blog]

= 补坑

一个用来填坑的长期清单。番剧、电视剧、电影、书和游戏都可以放在这里，重点不是一次性清空，而是留下想看的东西，并记录自己走到哪里。

== 当前清单

#table(
  columns: (1.5fr, 0.9fr, 1fr, 1.8fr),
  align: (left, left, left, left),
  inset: 8pt,
  stroke: 0.6pt + luma(70%),
  table.header(
    [*条目*],
    [*媒介*],
    [*状态*],
    [*进度 / 备注*],
  ),
  [—], [—], [—], [还没有开始记录。],
)

== 状态说明

- *想看：* 已经记下，但还没有开始；
- *进行中：* 正在补，下一次可以直接接着看；
- *搁置：* 暂时停下，保留已经看到的进度；
- *已完成：* 补完后留下几句简单记录。

每个条目可以只保留四个信息：媒介、状态、进度和备注。这样既能记录番剧和电视剧，也能自然扩展到电影、书和游戏。

#html.elem("div", attrs: (class: "section-empty"))[
  这个清单不追求一次性清空；坑可以慢慢填，记录本身也是进度。
]
