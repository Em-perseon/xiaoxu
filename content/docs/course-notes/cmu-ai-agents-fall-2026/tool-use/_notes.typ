#let note-data = (
n1: (title: [动作与工具的边界], brief: [工具让模型获取外部信息或执行操作；finish 只负责结束当前任务。], body: [
工具有两种作用：一是扩展模型原本做不到的事，例如读取账户余额、搜索最新信息或创建购物车；二是把模型不擅长精确完成的事交给程序，例如用计算器求和。

`finish(text)` 则是结束循环并返回最终回答的控制动作，不需要访问外部服务。模型生成一个动作请求后，Harness 仍需检查工具是否存在、参数是否合法、是否有执行权限，再决定执行或拒绝。
]),
n2: (title: [CodeAct 实验图], brief: [成功率衡量任务是否完成，交互轮次衡量完成任务需要多少轮调用。], body: [
#image("images/codeact-results.png", width: 100%, alt: "CodeAct 成功率与平均交互轮次。")

在图中展示的 8 个模型中，Code as Action 的成功率在 8 个模型上最高，交互轮次在 7 个模型上最少。扩大到实验比较的全部 17 个模型后，这两项计数均为 12/17。

代码可以把循环、数据处理和多次工具调用合并到一个动作里，从而减少模型与环境之间的往返；但这些实验计数并不保证代码接口在所有任务和权限设置下都优于结构化函数调用。
]),
n3: (title: [协议示例的适用范围], brief: [具体模型版本与服务端解析器必须匹配。], body: [
工具调用协议规定了调用从哪里开始、参数如何分隔、调用何时结束，以及如何表示调用 ID。例如，Qwen 3.8 使用函数与参数标签，Mistral Small 4 使用控制 token 和调用 ID，DeepSeek V3.2 使用 DSML 结构。

Parser 必须识别对应版本的协议。若模型输出函数标签，而 Parser 只等待 JSON 对象，即使模型选对了工具，也可能解析失败。同系列模型的不同版本不一定共用一种格式。
]),
n4: (title: [请求与返回的对应], brief: [调用 ID 标识一次请求，不只是一个工具名字。], body: [
模型生成工具名和参数，API 响应通常为这次调用附加唯一 ID。示例调用包含 `id: call_123`，结果消息使用 `tool_call_id: call_123`。即使同时多次调用同一个工具，也应按唯一 ID 匹配，而不能依靠结果返回顺序。
]),
n5: (title: [必填字段与取值约束], brief: [示例只要求 city；units 出现时才必须是 C 或 F。], body: [
`required: ["city"]` 只要求 city 出现，因此 `{"city":"Pittsburgh"}` 也符合示例 Schema。units 可以省略，但一旦提供，其值必须属于 `enum: ["C", "F"]`。

`additionalProperties: false` 禁止加入未声明的字段，例如 temperature。必填性、类型和取值范围是三个独立检查项；声明一个字段的 enum 不会自动把它变成必填字段。
]),
n6: (title: [按候选 token 屏蔽 logits], brief: [掩码作用于每个候选项，不是把整个 logits 向量设为负无穷。], body: [
令 $V_t$ 是当前前缀下可继续生成的 token 集合，候选 $v$ 的分数为：

$ z'_(t,v) = cases(z_(t,v) & "若" v in V_t, -infinity & "否则") $

$ p_t(v) = op("softmax")(z'_t)_v $

这里的合法性包括能否延伸到符合语法和受支持 Schema 的完整输出；空候选集合需要显式错误处理。
]),
n7: (title: [XGrammar 的逐步执行], brief: [复用已知的 token 合法性判定，把完整语法栈检查留给依赖上下文的少数候选。], body: [
XGrammar 先根据已经生成的字节更新下推自动机（PDA）的状态。对于仅由当前局部语法状态就能确定合法性的 token，直接复用缓存结果；依赖外层嵌套结构的候选，再检查完整语法栈。合并两类结果后，生成掩码、屏蔽不合法的 logits、采样，并继续更新状态。

检查必须深入到字节层：一个 token 可能同时包含引号、字段值和右括号，也可能只包含一个字符串的一部分。不能把 token 边界当作语法边界。持久化栈让多个候选分支共享未变化的栈结构，CPU 上的检查也可以与 GPU 推理重叠。
]),
n8: (title: [示例代码的边界], brief: [HTTP 路由只把请求接到函数上，实际服务还需要参数验证、身份认证和业务实现。], body: [
`@app.get("/weather")` 注册一个 HTTP 路由，并不自动实现天气查询或授权。`provider.lookup` 需要接入实际数据源；units 可以用 `Literal["C", "F"]` 限制取值，返回值可以用 Weather 数据模型验证。

若接口需要 API Key，Web 层应读取 `X-API-Key` 并验证其身份与权限。库函数负责业务计算，Web 层负责请求处理、参数验证、序列化与认证，OpenAPI 则描述接口供客户端发现和调用。
]),
n9: (title: [MCP 凭据隔离], brief: [MCP 凭据由 Harness 使用，上游凭据由 Server 使用。], body: [
#image("images/credential-brokering.png", width: 100%, alt: "Harness、MCP Server 与上游 API 的凭据边界。")

凭据可以保存在执行组件中，不必进入模型上下文。持有 MCP Key 的是客户端 / Harness，而非必须把 Key 写进模型上下文。Server 接受一种凭据，并在上游使用另一种凭据；仍需验证身份、授权具体动作并保护日志。
]),
n10: (title: [串行与并行延迟推导], brief: [相同工具耗时下，主要减少生成轮数与串行等待。], body: [
假设每次模型生成耗时 0.8 秒，天气、日历和航班工具分别耗时 1.2、0.9、1.1 秒。串行执行需要三次生成调用请求，再生成一次最终回答；并行执行可以一次生成三个请求，等待全部结果后再生成最终回答。

$ T_"serial" = 4 times 0.8 + 1.2 + 0.9 + 1.1 = 6.4 $

$ T_"parallel" = 2 times 0.8 + max(1.2, 0.9, 1.1) = 2.8 $

单位为秒。该估算忽略调度、排队和网络开销，前提是工具没有依赖、共享写入冲突或限流约束。
]),
n11: (title: [并发中的部分失败], brief: [结果乱序与部分失败需要分别处理。], body: [
`asyncio.gather(..., return_exceptions=True)` 可以同时等待多路调用，并把异常作为结果收集，而不因一路失败立即中断汇总。执行器返回调用 ID 和结果；某一路超时或失败不应让其他成功结果丢失。实现时还应将异常关联回原请求，并决定重试还是向模型返回失败观察。
]),
n12: (title: [Provider 错误率快照], brief: [工具调用失败可能发生在模型、Harness 或服务端，需要按失败环节诊断。], body: [
#image("images/provider-error-rates.png", width: 100%, alt: "OpenRouter Provider 工具调用错误率快照。")

这张 OpenRouter 错误率图记录的是 2026 年 8 月 27 日的状态。比较错误率时，需要对齐时间范围、流量构成和失败定义，不能把单日快照当作长期排名。

排查失败时可以分三层：模型是否选错工具、生成错误参数或忽视结果；Harness 是否解析失败、拒绝权限、验证失败或匹配错 ID；Provider / 工具是否超时、限流或执行报错。先定位失败层，才能决定该调整模型、修复适配器，还是重试外部服务。
]),
)

#let course-note(key) = {
  let item = note-data.at(key)
  show footnote: it => context {
    let number = counter(footnote).display(it.numbering)
    let fn-id = "fn-" + number
    let ref-id = "fnref-" + number
    html.elem("sup", attrs: (class: "footnote-ref"))[
      #html.elem("a", attrs: (class: "footnote-ref-link", href: "#" + fn-id, id: ref-id))[#number]
    ]
    html.elem("aside", attrs: (class: "marginnote course-note", id: fn-id))[
      #html.elem("sup")[#html.elem("a", attrs: (href: "#" + ref-id))[#number]]
      #it.body
    ]
  }
  footnote[
    #item.brief
    #html.elem("details", attrs: (class: "course-note-detail"))[
      #html.elem("summary")[#item.title]
      #html.elem("div", attrs: (class: "course-note-content"))[#item.body]
    ]
  ]
}
