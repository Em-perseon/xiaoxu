#import "../index.typ": template, tufted

#show: template.with(
  title: "第一篇文章",
)

#html.elem("a", attrs: (class: "back-link", href: "/xiaoxu/blog/"))[← 返回 Blog]

= 第一篇文章

这里写你的第一篇文章。

你可以把它改成正式标题，也可以删除这个文件夹后新建自己的文章。
