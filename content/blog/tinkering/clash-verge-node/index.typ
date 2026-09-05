#import "../../index.typ": template, tufted

#show: template.with(
  title: "我要成为菲律宾人",
)

#html.elem("a", attrs: (class: "back-link", href: "/xiaoxu/blog/tinkering/"))[← 返回瞎折腾]

= 我要成为菲律宾人

总是说懒惰是人类进步的阶梯，但我感觉贪小便宜也是。某天晚上，因为眼馋别人可以低价开通菲律宾区的gpt，于是我也想要尝试一下，本来以为一件很水到渠成的事情，结果就是折腾了很久，抱着既然折腾了不能白折腾的心态，写下了这个“瞎折腾”
板块的第一个blog。

首先第一个问题出现在，可能是openai某一次更新或者是防护力度的加大，本来在gpt升级那一块可以切换国家的，那自然而然点击切换一下的事情，但现在不是这样了，具体情况如下图所示

#figure(caption: "ChatGPT 方案页面对比：左图保留国家切换选项，右图已不再显示该选项。")[
  #context {
    if target() == "html" {
      html.elem("div", attrs: (class: "screenshot-comparison"))[
        #html.elem("div", attrs: (class: "screenshot-comparison-item"))[
          #html.elem("p", attrs: (class: "screenshot-label"))[原来：有国家切换选项]
          #image("chatgpt-country-selector.png", width: 100%)
        ]
        #html.elem("div", attrs: (class: "screenshot-comparison-item"))[
          #html.elem("p", attrs: (class: "screenshot-label"))[现在：没有国家切换选项]
          #image("chatgpt-current-plans.png", width: 100%)
        ]
      ]
    } else {
      grid(
        columns: (1fr, 1fr),
        gutter: 12pt,
        [
          #align(center)[*原来：有国家切换选项*]
          #image("chatgpt-country-selector.png", width: 100%)
        ],
        [
          #align(center)[*现在：没有国家切换选项*]
          #image("chatgpt-current-plans.png", width: 100%)
        ],
      )
    }
  }
]

对比来看，前一张图（左图）可以打开国家下拉菜单并选择菲律宾；后一张图（右图）没有国家切换入口，只显示当前可用的方案和工作空间选项。

但是，我发现换节点还是可以实现换区的，那么只要我切换到菲律宾的节点，就也还行，但第二个问题来了，我的订阅当中没有菲律宾节点，于是怀着出现问题解决问题的态度，我就去看是否有和我同类型的问题的人，以及他们是如何解决的，还真给我找到一个，在linux.do的一篇帖子下有人说可以试一下cliproxy。顺着这个线索，我查了一下这个cliproxy是何方神圣，发现它是一个住宅ip的代理池。

诶，代理池这个我熟啊，之前因为需要持续爬虫tripadvisor，因为反爬机制的存在，需要不断切换ip，就需要一个代理ip池，我就在这个上面找到了我要的菲律宾的ip，但导入又是一个问题了，之前是直接在python代码当中按照示例填入账号和密码就可以使用代理了，但导入到clash当中又是另外一回事了。

#figure(caption: "Clash Verge 的配置与节点编辑菜单。")[
  #image("clash-verge-edit-menu.png", width: 65%)
]

但这也不是事，ai时代，不懂就问ai，于是请教了g老师几轮之后，我大彻大悟了，就是去上面图片当中的这个位置点击编辑图片，将我们的在cliproxy上购买的节点信息填入就行了，然后再在文件另外一个位置增加一个显示的信息就ok了。但又有一个问题就是我突发奇想，我能否在clash verge当中直接导入cliproxy的订阅链接呢？

理想很美好，现实很骨感，这是不行的，cliproxy明确说明无法直接链接到菲律宾，事实上g老师给我的解决方案也是那种套壳式的解决方案。事情到这应该也完成得差不多了，差不多也成为一个菲律宾人了，但是我就想着不行我就偏偏要行，我想着如果我有一个海外的服务器进行一个转发呢？这个想法很久之前就有了，于是我就去调研了一下vps这个东西，结果发现水还挺深，有免费的oracle的，但听说好像要排队要抢。也有付费的，但现在好像不是黑五，一看价格，不是我能负担得起的，拜拜了。

以上大概就是我某晚的一整个折腾的过程，后续也包括订阅的折腾，但没有成功，我就没有继续折腾了，毕竟也比较晚了，记录一下第一份这个折腾过程吧。
