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

    #html.elem("p", attrs: (class: "home-lead"))[
      我在这里整理技术学习、课程笔记、阅读记录与偶尔写下的生活片段。
    ]

    #html.elem("nav", attrs: (class: "home-sections", aria-label: "网站内容"))[
      #html.elem("a", attrs: (href: "/xiaoxu/docs/"))[
        #html.elem("strong")[Docs]
        #html.elem("span")[课程、技术与阅读笔记]
      ]

      #html.elem("a", attrs: (href: "/xiaoxu/blog/"))[
        #html.elem("strong")[Blog]
        #html.elem("span")[较完整的文章与专题写作]
      ]

      #html.elem("a", attrs: (href: "/xiaoxu/essays/"))[
        #html.elem("strong")[Essays]
        #html.elem("span")[日常观察与随笔]
      ]

      #html.elem("a", attrs: (href: "/xiaoxu/timeline/"))[
        #html.elem("strong")[Timeline]
        #html.elem("span")[网站内容的更新轨迹]
      ]
    ]
  ]
]
