#import "../../../../../config.typ": template, tufted

#show: template.with(title: "Lecture 3：长上下文智能体的上下文管理")

#html.elem("a", attrs: (class: "back-link", href: "/xiaoxu/docs/course-notes/cmu-ai-agents-fall-2026/"))[← 返回 AI Agents · 2026 秋季]

= Lecture 3：长上下文智能体的上下文管理

*课程：* CMU 11-768 AI Agents · Fall 2026。\
*授课日期：* 2026 年 9 月 1 日；*讲师：* Graham Neubig。\
*课件：* #link("https://www.cmu-agents.com/slides/lecture-03-long-context.pdf")[Context Management for Long-Context Agents]。

*视频：* #link("https://www.youtube.com/watch?v=AiwCCvFW1uE")[Long Context Modeling for Agents]。

智能体运行得越久，历史就越长。模型需要找得到证据，系统需要负担得起计算，压缩之后还必须能够继续正确行动。这一讲把这三个问题连成了一条完整的工程链。

#html.elem("style")[
.course-note { float: right; clear: right; width: 22%; margin-right: 18%; margin-bottom: 1rem; font-size: .9rem; line-height: 1.5; }
.course-note p { width: auto; font-size: inherit; }
\@media (max-width: 760px) { .course-note { float: none; width: 100%; margin: 1rem 0; box-sizing: border-box; } }
.course-note-detail { margin-top: .45rem; }
.course-note-detail summary { cursor: pointer; font-weight: 600; line-height: 1.5; }
.course-note-content { max-height: 65vh; overflow: auto; padding: .4rem .2rem; }
.course-note-content figure, .course-note-content img { max-width: 100%; }
.course-note-content ul, .course-note-content ol { width: auto; padding-left: 1.3em; font-size: inherit; }
.course-note-content .essay-main-image { width: 100%; margin: .6rem 0; }
]

#outline(title: [目录], depth: 2)

#include "_body.typ"

#html.elem("link", attrs: (rel: "stylesheet", href: "/xiaoxu/assets/course-notes/image-viewer.css"))
#html.elem("script", attrs: (src: "/xiaoxu/assets/course-notes/image-viewer.js", defer: ""))[]
