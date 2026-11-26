#import "../index.typ": template, tufted

#show: template.with(
  title: "读论文",
)

#html.elem("a", attrs: (class: "back-link", href: "/xiaoxu/blog/"))[← 返回 Blog]

= 读论文

一个放在 Blog 里的论文阅读合集，用来记录平时精读或粗读过的文章。

精读的论文会单独写成一篇笔记，把核心思路、实现细节和自己的思考记下来；粗读的则随手记几句要点和第一印象，留个索引，方便以后回头翻。

== 精读

#html.elem("div", attrs: (class: "section-empty"))[
  第一篇精读笔记正在路上。
]

== 粗读

#table(
  columns: (1.6fr, 0.9fr, 0.8fr, 2.2fr),
  align: (left, left, left, left),
  inset: 8pt,
  stroke: 0.6pt + luma(70%),
  table.header(
    [*论文*],
    [*方向*],
    [*日期*],
    [*一句话记录*],
  ),
  [—], [—], [—], [还没有开始记录。],
)
