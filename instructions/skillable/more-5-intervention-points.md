# MORE 5: Intervention points

Learn what the runtime you used actually enforces. Read this before you deploy anything.

| Point | Sees | Good for |
|:------|:-----|:---------|
| `input` | The user request | Blocking a prompt-injection payload |
| `pre_tool_call` | The tool name and arguments | Blocking a dangerous argument passed to a tool |
| `post_tool_call` | The tool result | Redacting a secret a tool returned |
| `output` | The final response | Blocking or redacting an unsafe answer |

1. [] Open `src/policy/guard_demo.py` and find where `guard_target` wraps DevBot.
1. [] Decide which of the four points `guard_target` can enforce.

>[+Hint] Which points?
>
> Only `input` and `output`. `guard_target` is a lightweight wrapper. It does not sit between the agent and its tools, so it cannot enforce `pre_tool_call` or `post_tool_call` rules, even when those rules are in the manifest.

>[!Alert] If you generate a policy with tool-call rules and rely on `guard_target` alone, those rules never fire. To enforce them, run the agent inside a full ACS host that calls ACS before and after every tool. The manifest is the same either way, so nothing you built is wasted.

>[!Knowledge] DevBot's weaknesses were written to surface in its output, so the `guard_target` demo blocks real violations rather than pretending to enforce tool calls. On your own agent, decide where each risk surfaces first, then choose the point, then choose a runtime that can enforce it.

>[!Note] **Success:** you know which intervention points your runtime enforces, and when you need a full ACS host.
