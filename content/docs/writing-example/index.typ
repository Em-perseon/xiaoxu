#import "../../../config.typ": template, tufted

#show: template.with(
  title: "文档写作与插图示例",
)

#html.elem("a", attrs: (class: "back-link", href: "/xiaoxu/docs/"))[← 返回 Docs]

= 文档写作与插图示例

这个页面按照 Tufte 风格展示常用的正文、边栏图片、带边栏图注的正文图片、全宽图片和脚注。以后写文档时，可以直接复制对应示例。

== 一、正文结构

正文保持模板原本的主栏宽度。建议先写核心观点，再补充解释、例子或推导；一个段落尽量只处理一个问题。

```typst
== 一、章节标题

这里写正文。先给出核心观点，再展开解释。

=== 小节标题

1. 第一步；
2. 第二步；
3. 第三步。
```

== 二、右侧边栏图片

#tufted.margin-note[
  #image("layout-placeholder.svg")

  *图 1.* 这是放在右侧边栏中的图片和图注。
]

边栏图片与这段正文并排显示，但不会占用正文栏的宽度。它适合放补充示意图、局部细节、参考材料或简短说明。这正是参考站点首页放置图片与介绍文字时使用的结构。

可复制写法：

```typst
#tufted.margin-note[
  #image("你的图片.png")

  *图 1.* 在这里写图注。
]

在这里写与边栏图片对应的正文。
```

== 三、正文图片，图注位于边栏

使用 `figure` 时，图片留在正文区域，而图注会按照模板规则显示到右侧边栏。

#figure(caption: "正文中的图片，图注显示在右侧边栏。")[
  #image("layout-placeholder.svg", width: 100%)
]

可复制写法：

```typst
#figure(caption: "在这里写图注。")[
  #image("你的图片.png", width: 100%)
]
```

== 四、普通正文图片

不需要图注时，可以直接使用 `image`。图片会按照给定宽度出现在正文中。

#image("layout-placeholder.svg", width: 55%)

可复制写法：

```typst
#image("你的图片.png", width: 55%)
```

== 五、横跨正文与边栏的大图

当图表、流程图或实验结果需要更大空间时，可以使用 `full-width`。

#tufted.full-width[
  #image("layout-placeholder.svg", width: 100%)
]

可复制写法：

```typst
#tufted.full-width[
  #image("你的图片.png", width: 100%)
]
```

== 六、右侧边栏文字

#tufted.margin-note[
  这里可以放概念解释、补充信息、引用来源或阅读提示。
]

除了图片，边栏也可以放文字。边栏内容应当简短，并尽量紧跟它所解释的正文。

```typst
#tufted.margin-note[
  在这里写边栏说明。
]

在这里写对应的正文。
```

== 七、数学公式

行内公式直接放在一对 `$` 中，例如 $x^2 + y^2 = z^2$，可以和正文一起排列。

```typst
行内公式示例：$x^2 + y^2 = z^2$。
```

需要单独成行时，在公式内容两侧保留空格：

$ y = alpha + beta x + epsilon $

```typst
$ y = alpha + beta x + epsilon $
```

分数、求和、上下标和希腊字母可以这样写：

$ hat(beta) = frac(sum_(i=1)^n (x_i - overline(x)) (y_i - overline(y)), sum_(i=1)^n (x_i - overline(x))^2) $

```typst
$ hat(beta) = frac(
  sum_(i=1)^n (x_i - overline(x)) (y_i - overline(y)),
  sum_(i=1)^n (x_i - overline(x))^2
) $
```

== 八、脚注（正文右上角编号）

正文中插入 `#footnote[...]` 后，会出现右上角的小编号；注释内容会显示在右侧边栏，而不是页面底部。这与 [Tufted 示例站](https://tufted-blog.pages.dev/) 首页的写法相同。

我在目前的文档中包含了尽可能多的 Typst 用例#footnote[
  例如文字、段落、分级标题、公式、链接、脚注等。这块文字便是脚注，使用 `#footnote()` 函数编写。
]，你可以在源代码中看到这些内容的 Typst 实现。

可复制写法：

```typst
这里是正文#footnote[
  这里写脚注说明，它会出现在右侧边栏。
]，编号会自动出现在词句右上角。
```

与 `#tufted.margin-note[...]` 的区别：边栏说明没有编号；脚注会在正文里生成可点击的上标编号，并与边栏内容对应。

== 使用说明

- 图片文件放在当前 `index.typ` 所在的文件夹中。
- 把示例中的 `你的图片.png` 替换成真实文件名。
- 标准 Tufte 版式使用右侧边栏，不使用左右对称的双边栏。
- 在手机等窄屏设备上，边栏内容会自动回到正文附近。
