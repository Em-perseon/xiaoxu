#import "../../config.typ": template, tufted

#show: template.with(
  title: "Docs",
)

#html.elem("a", attrs: (class: "back-link", href: "/xiaoxu/"))[← 返回首页]

= Docs

#html.elem("nav", attrs: (class: "section-index", aria-label: "文档分类"))[
  #html.elem("a", attrs: (href: "course-notes/"))[#html.elem("span")[课程笔记] #html.elem("b")[→]]
  #html.elem("a", attrs: (href: "technical-docs/"))[#html.elem("span")[技术文档] #html.elem("b")[→]]
  #html.elem("a", attrs: (href: "reading-notes/"))[#html.elem("span")[阅读记录] #html.elem("b")[→]]
  #html.elem("a", attrs: (href: "writing-example/"))[#html.elem("span")[写作示例] #html.elem("b")[→]]
]
