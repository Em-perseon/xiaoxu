#import "../config.typ": template, tufted

#show: template.with(
  title: "Home",
)

#html.elem("div", attrs: (class: "home-layout"))[
  #html.elem("aside", attrs: (class: "home-aside"))[
    #html.elem(
      "img",
      attrs: (
        class: "home-avatar",
        src: "/xiaoxu/assets/avatar.png",
        alt: "头像",
        width: "128",
        height: "128",
      ),
    )
  ]

  #html.elem("div", attrs: (class: "home-main"))[
    = Xiaoxu

    欢迎来到我的个人网站。

    这里会放我的文章、项目和一些长期整理的笔记。

    == 最近更新

    === 2026-06-01

    - #link("/xiaoxu/essays/")[随笔]：#link("/xiaoxu/essays/2026-06-01-experiment-notes/")[实验小记]

    === 2026-05-25

    - #link("/xiaoxu/essays/")[随笔]：#link("/xiaoxu/essays/2026-05-25-first/")[为什么想要随笔]
  ]
]
