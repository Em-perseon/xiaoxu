#import "_notes.typ": course-note

== 一、工具使用的整体框架

理解工具使用，需要回答五个问题：

#html.elem("div", attrs: (class: "essay-main-image"))[
  #image("images/course-framework.svg", width: 100%, alt: "工具能力、调用机制、格式约束、接口与系统评估五层框架。")
]

工具调用的基本分工是：

*Tool Use 不是 LLM 自己执行程序，而是 LLM 生成一个结构化的执行请求，由外部 Harness 负责解析、验证、执行和返回结果。*

== 二、Tool Calling 究竟是什么？

=== 2.1 为什么需要工具？

模型可以生成文字，但参数中并不包含所有实时信息，也不能仅凭文字预测就真正修改外部世界。

工具可以提供四类能力：

#table(columns: 3,
[需求], [对应工具], [提供的能力],
[实时信息], [Web Search], [获得最新信息],
[精确计算], [Calculator、Python], [执行确定性的计算],
[私有数据], [Database、Account API], [读取授权数据],
[外部操作], [Browser、REST API], [修改外部环境],
)

有一点很重要：并不是任务中能用工具，就一定应该调用工具。

调用工具还会带来延迟、费用、执行失败以及权限风险。因此工具选择本身也是 Agent 需要完成的决策。

=== 2.2 Tool Calling 的完整流程

举例：用户要求查询匹兹堡的天气。

#html.elem("div", attrs: (class: "essay-main-image"))[
  #image("images/tool-call-loop.svg", width: 100%, alt: "用户请求经过 LLM、Harness、外部工具，再将观察返回 LLM。")
]

LLM 实际生成的可能是：

```json
{
  "name": "get_weather",
  "arguments": {
    "city": "Pittsburgh"
  }
}
```

这段 JSON 本身不会查询天气。

外部框架需要识别出 `get_weather`，找到真正的执行函数，并传入 `city` 参数。

所以，完整的 Agent 执行系统至少包括：

$ "Agent" = "LLM" + "Harness" + "Tools" $

这是理解后面所有内容的基础。

=== 2.3 工具并不一定是外部 API

`finish(text)` 是一种控制动作。

它代表 Agent 结束当前任务并输出文字，但不必调用外部程序。

因此，Action 可以包括：

- 调用外部工具，例如 `search_web()`。
- 运行代码，例如 `execute_code()`。
- 执行具体应用功能，例如 `create_grocery_cart()`。
- 完成当前任务，例如 `finish()`。

最后一种是 Harness 层面的控制动作，不是普通外部服务。#course-note("n1")

== 三、Code as Action、JSON as Action、Text as Action 有什么区别？

这部分借鉴了 ICML 2024 的 CodeAct 研究。

它们的根本区别，是 *LLM 能表达怎样的动作，以及这些动作如何被执行*。

=== 3.1 三种 Action 表示

#table(columns: 3,
[方式], [例子], [特点],
[Text as Action], [`search, Pittsburgh`], [易于阅读，但缺少强类型约束],
[JSON as Action], [`{"name":"search","query":"Pittsburgh"}`], [结构明确，容易验证],
[Code as Action], [`result = search("Pittsburgh")`], [可表达循环、条件、变量和复杂计算],
)

真正的差别在执行能力上。

例如，需要搜索四个国家的商品价格，统一转换货币，并找出最便宜的国家。

JSON as Action 可能需要反复调用：

```text
lookup_price(country="USA")
lookup_price(country="Japan")
lookup_price(country="Germany")
lookup_price(country="India")
...
```

而 Code as Action 可以写：

```python
countries = ["USA", "Japan", "Germany", "India"]

prices = {}

for country in countries:
    price = lookup_price(country)
    rate = lookup_exchange_rate(country)
    shipping = estimate_shipping(country)

    prices[country] = price * rate + shipping

best_country = min(prices, key=prices.get)
```

这段代码只计入价格、汇率和运费；实际比较还需要按业务规则加入税费等成本。

=== 3.2 为什么 CodeAct 有优势？

CodeAct 的关键思想是：

*让代码成为一种组合多个工具调用的 Meta-tool（元工具）。*

它能够把原本需要多轮交互的任务变成一个可执行程序，并直接利用成熟编程语言提供的循环、变量、函数和控制流。

CodeAct 实验分别比较了任务成功率和交互轮次：

- 在图中展示的 8 个模型子集中，Code 在 8/8 个模型上取得最高成功率。
- 在该子集中，7/8 个模型使用 Code 所需的交互轮次最少。
- 在全部 17 个模型的对比中，Code 在这两项统计上分别达到 12/17。

这些结果来自特定任务与模型的 CodeAct 实验，不能直接外推为所有 Agent 场景下代码动作都更好。#course-note("n2")

=== 3.3 为什么没有所有 Agent 都采用 CodeAct？

因为更强的表达能力也意味着更广泛的执行权限。

#html.elem("div", attrs: (class: "essay-main-image"))[
  #image("images/codeact-tradeoffs.svg", width: 100%, alt: "CodeAct 的程序表达能力与执行风险并列比较。")
]

JSON 工具调用通常只允许执行预先定义的函数，权限边界更容易明确。

CodeAct 则需要 Sandbox、资源限制、权限管理和执行日志。

所以更准确的结论是：

- *JSON as Action* 更适合明确、标准化、易于审计的业务接口。
- *Code as Action* 更适合需要大量程序化组合的复杂任务。

这也解释了为什么很多 Agent Harness 会同时提供结构化工具和代码执行环境。

== 四、Tool Calling 的底层机制：Template、Parser 和 Harness

这一部分解释了一个重要问题：*为什么使用同一个模型，不同 Provider 的 Tool Calling 表现还可能不同？*

=== 4.1 Tool Call 本质上仍然是 Token Generation

普通语言模型预测下一个 token：

```text
The weather is sunny.
```

支持工具调用的模型可以输出特殊格式：

```xml
<tool_call>
{"name": "get_weather",
 "arguments": {"city": "Pittsburgh"}}
</tool_call>
```

从底层模型角度看，这仍然是在预测 token。

区别在于，Harness 会把符合特定协议的输出识别为 Tool Call，而不是将其当成普通自然语言展示。

=== 4.2 Chat Template 到底是谁写的？

以 Qwen 风格的输入为例，结构化消息会经过如下转换：

#html.elem("div", attrs: (class: "essay-main-image"))[
  #image("images/chat-template.svg", width: 100%, alt: "结构化 API 消息经 Chat Template 变为带角色标记的输入序列。")
]

用户一般控制的是 Messages、System Prompt 和 Tools 的定义；*Chat Template 通常由模型发行方提供，或由推理框架、API Provider 实现。*

在本地部署中，可以查看或修改模板，例如使用 Hugging Face 的：

```python
tokenizer.apply_chat_template(
    messages,
    tools=tools,
    tokenize=False,
    add_generation_prompt=True
)
```

但在托管 API 中，具体的序列化过程通常是由服务端处理的。

因此，即使用户提交相同的 Messages，也不能保证不同 Provider 最终送进模型的完整 token 序列完全一样。

=== 4.3 不同模型的 Tool Call Protocol 不一样

Qwen、Mistral 和 DeepSeek 可以用不同协议表达同一个工具调用。

#table(columns: 2,
[模型示例], [格式特征],
[Qwen], [使用 Tool Call、Function 和 Parameter 标签],
[Mistral], [使用专门的控制 token、结构化调用及 ID],
[DeepSeek], [使用 DSML 调用结构],
)

例如 Qwen 风格可以是：

```xml
<tool_call>
<function=get_weather>
<parameter=city>
Pittsburgh
</parameter>
</function>
</tool_call>
```

而某种 Mistral 风格可以是：

```text
[TOOL_CALLS] [{"name":"get_weather",
"arguments":{"city":"Pittsburgh"}}]
```

两者在语义上表示同一个动作，但是模型输出的格式不同。

这意味着，推理框架需要有对应的 Parser 才能正确识别模型输出。#course-note("n3")

=== 4.4 为什么同一个 Qwen 在不同 Provider 上表现不同？

现在可以把原因分清楚：

#table(columns: 3,
[组件], [作用], [可能出现的差异],
[Chat Template], [将消息、工具定义转换为模型输入], [不同 Provider 使用不同序列化实现],
[Tool Parser], [将模型输出解析为结构化调用], [Parser 与模型输出协议不匹配],
[Constrained Decoding], [限制模型可以生成的格式], [不同约束实现和配置],
[Inference Engine], [执行模型计算与解码], [不同推理实现、数值精度或采样配置],
[Harness], [管理工具执行与结果返回], [工具定义、参数校验和错误处理不同],
)

所以，Tool Calling 的正确性不是模型权重一个因素决定的，而是整个执行系统共同决定的。

=== 4.5 OpenHands 在这里负责什么？

OpenHands 的工具执行分为初始化注册与逐次分发两个阶段。

#html.elem("div", attrs: (class: "essay-main-image"))[
  #image("images/harness-dispatch.svg", width: 100%, alt: "初始化注册工具；调用时解析、查找、校验、执行并返回结果。")
]

它先注册工具，建立工具名与执行器之间的映射，然后解析模型输出，检查参数，调用实际执行器。

结果通过 `call_id` 关联到原始调用，这对并行工具尤其重要，否则多个结果可能无法正确对应。#course-note("n4")

这里也可以澄清另一个概念：

- *Harness* 是整个 Agent 的执行与控制框架。
- *Sandbox* 是用来隔离高风险代码或程序执行的环境。

Sandbox 可以成为 Harness 的一部分，但二者不等价。



== 五、Constrained Decoding：为什么模型可以保证生成合法 JSON？

Constrained Decoding 在生成过程中限制候选 token，使输出满足规定的语法和 Schema。XGrammar 是一种高效实现，相关论文发表于 MLSys 2025。

=== 5.1 传统生成的问题

假设模型要生成：

```json
{
  "city": "Pittsburgh",
  "units": "F"
}
```

模型有可能输出：

```text
{"city": "Pittsburgh", "units": "K"
```

这段输出存在两个问题：缺少右括号，而且 `K` 不是允许的单位。

即使明确告诉模型只能输出合法 JSON，也不能从算法层面保证它一定遵守。

=== 5.2 JSON Schema 的作用

JSON Schema 可以声明一个工具接受哪些参数：

```json
{
  "type": "object",
  "properties": {
    "city": {"type": "string"},
    "units": {"enum": ["C", "F"]}
  },
  "required": ["city"],
  "additionalProperties": false
}
```

它描述四种约束：

1. Syntax：语法必须是合法 JSON。
2. Shape：对象应当包含预期字段。
3. Types：字段类型必须正确。
4. Values：字段取值必须在允许范围内。

但要注意：*JSON Schema 是约束的描述，而不是执行约束本身的算法。*#course-note("n5")

=== 5.3 Constrained Decoding 如何工作？

传统模型在每一步会产生一个词表范围内的 logits 向量。

$ p(x_t | x_(<t)) = op("softmax")(z_t) $

Constrained Decoding 会根据当前已经生成的内容，判断哪些 token 仍可能形成合法输出。

对于不合法的 token：

$ z'_t = -infinity $

对于合法的 token：

$ z'_t = z_t $

之后只在符合规则的候选中采样。#course-note("n6")

#html.elem("div", attrs: (class: "essay-main-image"))[
  #image("images/token-mask.svg", width: 100%, alt: "在 units 值位置允许 C 和 F，屏蔽 K。")
]

实际实现还必须正确处理 tokenizer 中跨越多个语法片段的 token，不能简单地认为一个模型 token 对应一个完整语法单元。

=== 5.4 为什么涉及 Pushdown Automaton（下推自动机）？

因为 JSON 可以出现任意层数的嵌套结构：

```json
{
  "a": {
    "b": [
      {"c": 1}
    ]
  }
}
```

要判断下一个 token 是否合法，算法必须记住：

- 当前位于对象还是数组。
- 是否正在等待 Key 或 Value。
- 每一层嵌套应该怎样结束。

Pushdown Automaton（PDA）通过一个栈保存这种嵌套状态。

XGrammar 的一个优化是：将部分 token 合法性判断缓存起来，只对需要上下文判断的候选执行更复杂的检查，从而降低约束解码的额外开销。#course-note("n7")

=== 5.5 Constrained Decoding 不保证什么？

这是整部分最重要的一句话：

*Constrained Decoding guarantees form, not correctness.*

即使生成：

```json
{
  "city": "London",
  "units": "F"
}
```

完全合法，仍然可能是错误的操作，因为用户真正要求查询的是 Pittsburgh。

所以它不能保证：

- 调用了正确的工具。
- 参数语义符合用户意图。
- 工具调用拥有相应权限。
- 执行后任务一定成功。

它主要解决的是 *格式与 Schema 约束*，不是 Agent 的完整决策正确性。



== 六、REST API、FastAPI 和 MCP 到底是什么关系？

这里将 SDK、API、REST、FastAPI 和 MCP 放在同一条调用链上理解。

=== 6.1 从 Python Function 到 REST API

首先，最普通的 Python 函数：

```python
def get_weather(city: str, units: str = "F"):
    return provider.lookup(city, units)
```

它只能在具有相应运行环境和调用权限的程序中直接执行。

如果希望其他机器通过网络调用，就可以用 FastAPI 暴露一个 HTTP 接口：

```python
from fastapi import FastAPI

app = FastAPI()

@app.get("/weather")
def weather(city: str):
    return get_weather(city)
```

然后客户端能够通过 HTTP 请求访问该服务。#course-note("n8")

```text
GET /weather?city=Pittsburgh
```

这里的区别是：

#table(columns: 2,
[概念], [本质],
[Python Function], [进程内可执行函数],
[REST API], [通过 HTTP 暴露资源或操作的接口设计方式],
[FastAPI], [用于构建 Web API 的 Python 框架],
[OpenAPI], [描述 HTTP API 接口、参数和返回内容的规范],
[SDK], [对底层接口进行封装的开发工具包],
[MCP], [让 AI 应用发现并调用工具及其他能力的标准协议],
)

=== 6.2 MCP 为什么会出现？

假设有三个服务：天气、日历和文件系统。

如果没有统一的 Agent 接入协议，开发者可以分别为它们编写 API 连接和调用适配器。

MCP 的设计目标是建立标准化的 Host、Client 和 Server 交互方式。

#html.elem("div", attrs: (class: "essay-main-image"))[
  #image("images/mcp-host-clients.svg", width: 100%, alt: "一个 MCP Host 通过两个 Client 分别连接本地 stdio 与远程 HTTP Server。")
]

两种接口的关系是：

*MCP 是可选的 Agent-facing Interface，并不是访问 REST API 的必要条件。*

Agent 可以直接调用 REST API，也可以通过 MCP Server 间接调用。

=== 6.3 OpenAPI 和 MCP 的区别

#table(columns: 3,
[维度], [OpenAPI / REST], [MCP],
[主要用途], [描述和调用 HTTP 接口], [向 AI 应用提供标准化能力接口],
[发现机制], [获取 OpenAPI 文档], [运行时 `tools/list`],
[调用机制], [HTTP Method + URL], [MCP `tools/call`],
[参数结构], [可以使用 JSON Schema], [使用结构化工具 Schema],
[功能范围], [HTTP API 操作], [Tools、Resources、Prompts 等],
)

FastMCP 可以读取现有 OpenAPI 描述，把其中的操作暴露为可发现、可调用的 MCP Tools。

因此，MCP 并不一定意味着重新实现原有后端业务逻辑；它可以作为现有 API 的适配层。

=== 6.4 MCP 的安全价值

一个典型安全问题是：让 Agent 直接用 `curl` 访问业务 API 时，API Key 可能暴露给它可以访问的 Shell 环境。

可以让 MCP Server 作为中间层，把客户端凭据与上游 API 凭据分开：

#html.elem("div", attrs: (class: "essay-main-image"))[
  #image("images/credential-boundary.svg", width: 100%, alt: "Harness 使用 MCP 凭据；Server 验证权限并以独立上游凭据访问 API。")
]

模型不需要看到上游服务的实际凭据。#course-note("n9")

这提供了更好的权限隔离，但仍需要正确配置认证、授权和执行策略。生产系统不应简单地把开发阶段的静态令牌方案当成完整安全方案。



== 七、为什么 Agent 要支持 Parallel Tool Calling？

多工具 Agent 很容易因为大量串行调用而产生较高延迟。

以分别查询天气、日历和航班信息为例，三路请求互不依赖时可以一起发起。

#html.elem("div", attrs: (class: "essay-main-image"))[
  #image("images/parallel-latency.svg", width: 100%, alt: "串行 6.4 秒与并行 2.8 秒的示例延迟对比。")
]

这组延迟按假设的模型与工具耗时计算，用于比较调度方式，不代表实测性能。#course-note("n10")

对于独立工具，可以将总延迟近似从多个工具耗时之和，压缩为最慢工具的耗时加上模型调用耗时。

并行的前提是：*只有不存在依赖或并发冲突的操作，才能安全并行。*

例如：

- 查天气、读取日历、查询航班可以并行。
- 查找客户 ID → 查询客户订单 → 退款，则需要按依赖顺序执行。

此外，当并行调用的结果以不同顺序返回时，Harness 应当保留每个调用的 `call_id`，避免结果错配。

这说明工具调用的效率不仅依赖 LLM 本身，还依赖 Harness 的编排策略。#course-note("n11")



== 八、Tool Calling 应该如何评估？

Berkeley Function Calling Leaderboard 覆盖了多种工具调用任务。评估一个实际 Agent 时，还需要区分工具选择、参数、调用轨迹与最终任务结果。

=== 8.1 四个层次的评估

#table(columns: 3,
[层次], [研究问题], [指标],
[Selection], [工具选对了吗？], [Precision、Recall],
[Arguments], [参数生成正确吗？], [AST / Schema Match],
[Trajectory], [工具调用顺序正确吗？], [Sequence Success],
[Task], [最终目标完成了吗？], [End-to-End Success],
)

这四者并不等价。

例如，一个 Agent 完全可能：

- 正确调用搜索工具。
- 生成符合 Schema 的查询。
- 成功获得搜索结果。
- 最后却忽视结果，回答错误。

因此，只评估 Function Calling Accuracy 无法充分反映 Agent 的真实任务能力。

=== 8.2 还需要评估工程表现

除任务正确性外，还需要衡量：

*Efficiency*：延迟、调用次数、token 使用量、成本。

*Reliability*：超时、重试、执行错误、部分任务失败。

*Safety*：权限、行为限制，以及工具的潜在副作用。

OpenRouter 在 2026 年 8 月记录的 Provider 工具调用错误率显示，不同服务提供商的运行可靠性可能不同。#course-note("n12")

它说明不同 Provider 的工具调用可靠性可能存在明显差异。因此，同一个模型的 Agent 性能并不只由模型权重决定，部署和执行环境也非常重要。



== 九、对 Agent 研究与开发的启发

这部分是结合调度研究的个人思考。

=== 9.1 Jev 调度：把合法动作与优质决策分开

我研究的 Scheduling Agent 需要输出多个服务器的联合调度动作。

可以将输出设计成明确的结构：

```json
{
  "server_1": "queue_2",
  "server_2": "queue_3"
}
```

再利用 JSON Schema 约束结构，并用环境校验器检查：

- 服务器是否有资格处理对应队列。
- 是否违反容量约束。
- 联合动作是否可执行。

不过，*Constrained Decoding 保证格式合法，并不自动保证调度动作在业务约束下可执行，更不能保证它具有长期最优性。*

因此，可以将研究任务分为：

$ "Action Validity" quad "与" quad "Decision Quality" $

这样也有助于把模型的决策贡献与接口工程带来的收益区分开。

=== 9.2 CodeAct 对调度 Agent 是否值得借鉴？

我认为取决于任务结构。

如果 Agent 需要调用大量不同工具，编写程序、执行循环、处理复杂数据，那么 Code as Action 是值得考虑的。

但如果核心任务是：

根据当前队列状态，直接选择所有服务器的联合动作。

那么明确约束的结构化输出可能更适合做主方法。

因为我的研究重点不是让 LLM 编程，而是*让它做出更好的序贯运营决策*。

CodeAct 可以作为一种可比较的交互接口，但不应默认它一定能解决当前的 myopic 问题。

=== 9.3 Agent 的评估必须覆盖完整技术栈

对于同一 Scheduling Agent，可以分别报告：

#table(columns: 2,
[维度], [建议指标],
[Action Validity], [合法动作率],
[Task Performance], [累计持有成本、平均等待时间],
[Reliability], [解析失败、执行失败、重试率],
[Efficiency], [每步延迟、token 消耗、总成本],
[Long-Horizon Quality], [长期累计收益、相对基线的成本差距],
)

还应保持同样的动作空间、信息集、调用预算和环境条件，防止将不同工具接口或搜索预算的优势误归因为模型推理能力提升。

这也是 Agent 方法实验需要控制的变量。



== 十、工具使用的六个核心概念

#table(columns: 2,
[概念], [一句话理解],
[*Tool Calling*], [模型生成调用请求，外部系统执行],
[*Chat Template*], [将 Messages 和 Tools 序列化为模型输入],
[*Harness*], [负责工具注册、解析、验证、执行和状态管理],
[*Constrained Decoding*], [在生成阶段排除不符合语法和 Schema 的 token],
[*MCP*], [标准化 AI 应用发现和调用外部能力的方式],
[*CodeAct*], [允许模型用代码组合多个操作的 Action 范式],
)

这些机制可以概括为：

*Agent Tool Use is a systems problem, not merely a model capability.*

也就是说，Tool Calling 看起来只是模型生成一个函数名和参数，但完整的可靠性、效率和安全性，取决于模型协议、解析器、执行框架、工具接口和评估体系之间是否正确协同。

这也是为什么真正做 Agent 开发，不能只理解 Prompt 和模型 API，还需要理解 Harness、Constrained Decoding、工具编排和接口协议。

== 课后自测

1. 模型输出合法的 get_weather JSON 后，系统还必须完成哪些步骤？
2. 相同模型权重与 Messages，为什么不保证不同 Provider 的调用行为相同？
3. Schema 合法、业务可执行与长期决策质量分别由什么机制检查？
4. 什么条件下工具可以并行？结果乱序或部分失败时怎样恢复？
5. MCP 凭据与上游 API 凭据分别由哪个组件持有？

== 阅读材料

- #link("https://www.cmu-agents.com/slides/lecture-02-tool-use.pdf")[Lecture 2 官方课件（60 页）]。
- #link("https://arxiv.org/abs/2403.15452")[What Are Tools Anyway?]。
- #link("https://arxiv.org/abs/2402.01030")[Executable Code Actions Elicit Better LLM Agents（CodeAct）]。
