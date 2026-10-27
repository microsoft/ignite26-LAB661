![MORE 5 · Intervention points and tool calls, optional offline lab](../media/banner-more-5.svg)

# MORE 5: Intervention points and tool calls

## Objective

Understand the four ACS intervention points, why the lab guards `output`,
and what it takes to enforce policy on tool calls at runtime. This is the most
important honesty lesson in the lab, so read it before you deploy anything.

## What you will learn

- What each intervention point is for.
- Why `guard_target` enforces `input` and `output` but not tool-call points.
- What a full ACS host adds.

---

## Step 1: The four points

ACS can inspect an agent at four moments. A policy chooses which to guard.

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

Nothing stops you from writing a `pre_tool_call` rule. If your generation plan
includes one, the generated manifest declares that point. You can confirm this by
generating a policy whose plan has a `pre_tool_call` rule and inspecting the
manifest, the `intervention_points` map will list `pre_tool_call` alongside
`output`.

The rule is real and lives in the manifest. The question is who enforces it.

## Step 3: The runtime boundary you must know

The `guard_target` helper you used in Lab 4 is a lightweight runtime wrapper. It
evaluates the policy at the `input` and `output` points only. It does not sit
between the agent and its tools, so it cannot enforce `pre_tool_call` or
`post_tool_call` rules, even when those rules exist in the manifest.

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

- Four points: `input`, `pre_tool_call`, `post_tool_call`, `output`.
- `guard_target` enforces `input` and `output`. Tool-call points need a full host.
- The manifest is portable, so nothing you build here is wasted when you move to
  a full host.
