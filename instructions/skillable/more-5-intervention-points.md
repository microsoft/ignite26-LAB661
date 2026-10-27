# More 5: Intervention points

Learn what the runtime you used actually enforces. Read this before you deploy anything.

ACS has eight intervention points. These four matter most for an agent like DevBot.

| Point | Sees | Good for |
|:------|:-----|:---------|
| `input` | The user request | Blocking a prompt-injection payload |
| `pre_tool_call` | The tool name and arguments | Blocking a dangerous argument passed to a tool |
| `post_tool_call` | The tool result | Redacting a secret a tool returned |
| `output` | The final response | Blocking or redacting an unsafe answer |

1. [] Generate a demo policy that also guards tool calls. It writes to `artifacts/acs/toolcall-demo`, so the lab's policy is untouched.

   ++PYTHONPATH=src python3 src/policy/tool_call_demo.py++

1. [] Confirm the manifest declares both points. You see `pre_tool_call:` and `output:`.

   ++grep -n -E "^  (pre_tool_call|output):" artifacts/acs/toolcall-demo/manifest.yaml++

1. [] Probe the tool-call rule. This prints `deny`.

   ++echo '{"intervention_point":"pre_tool_call","policy_target":{"command":"rm -rf ~/work"}}' | opa eval -I -d artifacts/acs/toolcall-demo/policy 'data.agent_control_specification.devbot_shell_guardrails.pre_tool_call_verdict.decision' -f raw++

1. [] See which points `guard_target` actually calls. You see only `INPUT` and `OUTPUT`.

   ++grep -n "InterventionPoint\.[A-Z]" "$(python3 -c 'import assert_ai.integrations.acs.guard as g; print(g.__file__)')"++

>[!Knowledge] `guard_target` is a lightweight wrapper. It does not sit between the agent and its tools, so it cannot enforce `pre_tool_call` or `post_tool_call` rules, even though the demo manifest has one.

>[!Alert] If you generate a policy with tool-call rules and rely on `guard_target` alone, those rules never fire. To enforce them, run the agent inside a full ACS host that calls ACS before and after every tool. The manifest is the same either way, so nothing you built is wasted.

>[!Knowledge] DevBot's weaknesses were written to surface in its output, so the `guard_target` demo blocks real violations rather than pretending to enforce tool calls. On your own agent, decide where each risk surfaces first, then choose the point, then choose a runtime that can enforce it.

>[!Note] **Success:** you know which intervention points your runtime enforces, and when you need a full ACS host.
