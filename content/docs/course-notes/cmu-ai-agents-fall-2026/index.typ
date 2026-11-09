#import "../../../../config.typ": template, tufted

#show: template.with(title: "CMU 11-768 AI Agents · 2026 秋季")

#html.elem("a", attrs: (class: "back-link", href: "/xiaoxu/docs/course-notes/"))[← 返回课程笔记]

= CMU 11-768 · AI Agents

*课程学期：2026 年秋季（Fall 2026）。* Carnegie Mellon University，授课教师为 Daniel Fried 与 Graham Neubig。

记录智能体课程的学习过程，围绕工具使用、上下文与记忆、规划、训练及评估组织笔记。课程日期以该秋季学期的课程表为准，不等同于我的整理日期。

#link("https://www.cmu-agents.com/#/schedule")[课程日程与材料 →]

#html.elem("nav", attrs: (class: "section-index", aria-label: "课程学习笔记"))[
  #html.elem("a", attrs: (href: "tool-use/"))[#html.elem("span")[Lecture 2 · 语言模型智能体的工具使用] #html.elem("b")[08 · 27　→]]
  #html.elem("a", attrs: (href: "long-context/"))[#html.elem("span")[Lecture 3 · 长上下文智能体的上下文管理] #html.elem("b")[09 · 01　→]]
]
