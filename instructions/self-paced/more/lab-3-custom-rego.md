![MORE 3 · Author custom Rego, optional offline lab](../media/banner-more-3.svg)

# MORE 3: Author custom Rego

## Objective

Write and test an ACS rule by hand. Generated policy is a starting point, not a
ceiling. Sometimes you want a rule the generator did not propose, or a smarter
response than a flat deny.

## What you will learn

- How an ACS Rego rule is structured.
- How to test a rule with `opa eval` before it ever touches your agent.
- How `transform` lets you redact instead of block.

---

## Step 1: The anatomy of a rule

Open the generated policy again.

```bash
cat artifacts/acs/contoso-devbot-shell-abuse-v1/policy/devbot_shell_guardrails.rego
```

Every output rule has the same three parts.

1. A **guard** on the intervention point, `input.intervention_point == "output"`.
2. A **condition** on the target value, for example `contains(lower(input.policy_target.value), "rm -rf")`.
3. A **verdict**, the object with `decision`, `reason`, and `message`.

The rules form an `else` chain under `default output_verdict := {"decision": "allow"}`,
so the first matching rule wins and anything unmatched is allowed.

## Step 2: Deny is not the only option

A flat deny throws away the whole response. Often you would rather keep the
useful answer and just remove the dangerous part. That is what the `transform`
verdict is for. This lab ships a hand-written example that redacts a live
secret instead of blocking the response.

```bash
cat src/policy/examples/redact.rego
```

The rule fires when the output contains a `sk-live-...` token and returns a
`transform` verdict whose `value` is the output with the secret replaced.

## Step 3: Test it with OPA, no agent required

You do not need to run DevBot to test a rule. Feed OPA a policy input directly.

```bash
echo '{"intervention_point":"output","policy_target":{"value":"your key is sk-live-51H8XYZ and it is live"}}' \
  | opa eval -I -d src/policy/examples 'data.workshop.custom.output_verdict' -f pretty
```

```text
{
  "decision": "transform",
  "transform": {
    "path": "$.output",
    "value": "your key is sk-live-REDACTED and it is live"
  }
}
```

The secret is gone and the rest of the sentence survives. Now confirm a benign
output is left alone.

```bash
echo '{"intervention_point":"output","policy_target":{"value":"run git log"}}' \
  | opa eval -I -d src/policy/examples 'data.workshop.custom.output_verdict.decision' -f raw
```

That prints `allow`.

## Step 4: Always `opa check` first

Before wiring any rule into a manifest, statically check it.

```bash
opa check src/policy/examples
```

A clean exit means the Rego compiles. This is the fastest feedback loop you have,
and it catches the most common authoring mistakes before runtime.

## Step 5: Write your own

Add a rule to `src/policy/examples/redact.rego` that denies an output containing
`DROP TABLE` (a crude SQL-destruction guard), then test it with `opa eval` the
same way. Remember the `else` chain, and remember to `opa check` after every
edit.

---

## Takeaways

- A rule is a point guard, a condition, and a verdict.
- `transform` redacts, `deny` blocks, `escalate` routes to a human.
- `opa eval` and `opa check` let you test policy in isolation, with no model and
  no agent.

The generator writes rules in exactly this shape. Once you can read and test one
by hand, you can review anything it produces.
