![More 5 · Intervention points and tool calls, optional offline lab](../assets/banner-more-5.svg)

# More 5: Intervention points and tool calls

## Objective

Understand the ACS intervention points, why the lab guards `output`, and what it
takes to enforce policy on tool calls at runtime. This is the most important
honesty lesson in the lab, so read it before you deploy anything.

## What you will learn

- What the main intervention points are for.
- Why `guard_target` enforces `input` and `output` but not tool-call points.
- What a full ACS host adds.

---

## Step 1: The points

ACS can inspect an agent at eight moments: `agent_startup`, `input`,
`pre_model_call`, `post_model_call`, `pre_tool_call`, `post_tool_call`,
`output`, and `agent_shutdown`. You saw all eight as `default ..._verdict` lines
at the top of the generated Rego. A policy chooses which to guard. These four
matter most for DevBot.

| Point | Sees | Good for |
|-------|------|----------|
| `input` | The user request | Blocking a prompt-injection payload before the agent runs |
| `pre_tool_call` | The tool name and arguments | Blocking a dangerous argument, for example `rm -rf` passed to a shell tool |
| `post_tool_call` | The tool result | Redacting a secret a tool returned before the model sees it |
| `output` | The final response | Blocking or redacting an unsafe answer before the user sees it |

DevBot leaks by *speaking*. It prints a key or endorses `rm -rf` in its chat
reply. That is an `output` violation, which is why the generated policy guards
`output`.

## Step 2: A policy can guard tool calls too

A script generates a demo policy with one extra rule at `pre_tool_call`. It
writes to `artifacts/acs/toolcall-demo`, so the lab's own policy is untouched.

### Step 2.1: Generate the demo policy

```bash
PYTHONPATH=src python3 src/policy/tool_call_demo.py
```

```text
Wrote artifacts/acs/toolcall-demo/manifest.yaml
Guarded points: pre_tool_call, output
```

### Step 2.2: See both points in the manifest

```bash
grep -n -E "^  (pre_tool_call|output):" artifacts/acs/toolcall-demo/manifest.yaml
```

```text
11:  pre_tool_call:
18:  output:
```

### Step 2.3: Probe the tool-call rule with OPA

A tool call whose arguments contain `rm -rf` is denied.

```bash
echo '{"intervention_point":"pre_tool_call","policy_target":{"command":"rm -rf ~/work"}}' \
  | opa eval -I -d artifacts/acs/toolcall-demo/policy \
    'data.agent_control_specification.devbot_shell_guardrails.pre_tool_call_verdict.decision' -f raw
```

That prints `deny`. A safe tool call is allowed.

```bash
echo '{"intervention_point":"pre_tool_call","policy_target":{"command":"git log"}}' \
  | opa eval -I -d artifacts/acs/toolcall-demo/policy \
    'data.agent_control_specification.devbot_shell_guardrails.pre_tool_call_verdict.decision' -f raw
```

That prints `allow`. The rule is real and lives in the manifest. The question is
who enforces it.

## Step 3: The runtime boundary you must know

The `guard_target` helper you used in Lab 4 is a lightweight runtime wrapper.
See which points it calls, straight from its source.

```bash
grep -n "InterventionPoint\.[A-Z]" "$(python3 -c 'import assert_ai.integrations.acs.guard as g; print(g.__file__)')"
```

```text
148:            InterventionPoint.INPUT, {**ambient, "input": input_value}, input_value
152:            InterventionPoint.OUTPUT,
```

Only `input` and `output`. It does not sit between the agent and its tools, so
it cannot enforce `pre_tool_call` or `post_tool_call` rules, even when those
rules exist in the manifest, as they do in the demo policy.

Read that again, because it is the difference between a policy that protects you
and one that only looks like it does. If you generate a policy with tool-call
rules and then rely on `guard_target` alone, those rules never fire.

## Step 4: What a full host adds

To enforce tool-call points, the agent must run inside a full ACS host that
wraps every tool dispatch and calls ACS before and after each one. That host is
part of the Agent Governance Toolkit's ACS runtime, not the `guard_target`
convenience wrapper. The generated manifest is the same artifact either way, so
the policy you build here is portable to that host without changes.

The practical rule of thumb:

- Governing what the agent **says** to the user? `output` (and `input`) work
  with `guard_target` today.
- Governing what the agent **does** with tools? Write the `pre_tool_call` and
  `post_tool_call` rules into the manifest, and deploy under a full ACS host that
  enforces them.

## Step 5: Why the lab design is honest about this

DevBot's weaknesses were deliberately written to surface in its output, so the
`guard_target` demo blocks real, in-scope violations rather than pretending to
enforce tool calls it cannot. When you adapt this to your own agent, decide first
where each risk actually surfaces, then choose the point, then choose the runtime
that can enforce that point.

---

## Takeaways

- ACS has eight points. For an agent like DevBot, `input`, `pre_tool_call`,
  `post_tool_call`, and `output` matter most.
- `guard_target` enforces `input` and `output`. Tool-call points need a full host.
- The manifest is portable, so nothing you build here is wasted when you move to
  a full host.
