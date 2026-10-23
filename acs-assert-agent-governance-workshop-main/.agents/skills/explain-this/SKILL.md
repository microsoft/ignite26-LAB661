# Skill: explain-this

## Description

Explains outputs, concepts, or results a learner meets during the ACS + ASSERT
workshop. Helps them understand the "why" behind what they see.

## When to invoke

The learner says something like:

- "Explain this"
- "What does this mean?"
- "Why did that happen?"
- "What is [concept]?"
- "I don't understand this output"

## Behavior

1. **Identify the target.** Look at the learner's most recent output, result, or
   named concept.

2. **Explain at the right level.** Assume the learner knows basic Python, the
   shell, and general AI concepts. Do not assume they know ACS terminology,
   ASSERT internals, or OPA.

3. **Structure it.**
   - **What it is** in one sentence.
   - **Why it matters** here, in one or two sentences tied to the protect loop.
   - **How it connects** to the next step.

4. **Offer depth.** After the short version, offer to go deeper rather than
   dumping everything at once.

## Key concepts

| Concept | Short explanation |
|---------|-------------------|
| ACS | A stateless, deterministic, fail-closed policy runtime that evaluates an agent at intervention points and returns a verdict |
| ASSERT | A spec-driven evaluation framework that generates tests from a behavior spec and judges the transcripts |
| Intervention point | A moment ACS can inspect the agent: `input`, `pre_tool_call`, `post_tool_call`, `output` |
| Verdict | ACS's decision: `allow`, `warn`, `deny`, `escalate`, or `transform` |
| Finding | An evidence-backed behavior the agent violated, attributed to a taxonomy node |
| Deny target | A non-permissible violated node the generated policy will block |
| Permissible node | A behavior a guardrail must not deny; overrefusal is reported, not blocked |
| Manifest | The ACS file declaring which points are guarded and where the target value is |
| Rego bundle | The OPA policy that holds the actual rules |
| `guard_target` | The runtime wrapper that enforces the policy at `input` and `output` |
| handled vs strongly blocked | `handled` includes `warn`; `strongly blocked` counts only `deny` and `escalate` |
| Attack success rate | Share of adversarial prompts whose unsafe response reaches the user |

## Interaction pattern

- Keep the first pass to three to five sentences.
- Use an analogy when it helps.
- Always connect back to the loop: evaluate, generate, validate, guard, verify.
- Be honest about limits. If the learner is looking at a keyword rule, say plainly
  that it matches strings, not meaning, and point at the red-teaming lab.
