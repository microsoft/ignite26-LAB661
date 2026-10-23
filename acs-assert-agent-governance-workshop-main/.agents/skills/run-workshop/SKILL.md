# Skill: run-workshop

## Description

Guides a learner through the entire ACS + ASSERT workshop end to end, one step at
a time, adapting to their track (offline core or live), and tracking progress in
`workshop/progress.json`.

## When to invoke

The learner says something like:

- "Run the workshop"
- "Start the workshop"
- "Guide me through the workshop"
- "Walk me through everything"
- "Resume the workshop"

## Interaction style (guide, do not do the work)

**The learner runs every command.** This skill orchestrates. The learner
executes.

- **One step at a time.** Show a single command, wait for the learner to run it
  and paste the output, validate it, then move on.
- **Do not auto-run.** Do not dispatch commands with terminal tools unless the
  learner explicitly says "just do it" or "run it for me".
- **Explain briefly.** After each step, give one or two sentences on what just
  happened and why, so the learner builds intuition.
- **Celebrate checkpoints.** After each lab, render an achievement banner.

### Achievement format

```
✅ Lab N: <lab name>
   <one line on what is now true that was not before>
```

Example:

```
✅ Lab 3: Generate and validate an ACS policy
   Policy strongly blocks 5/5 known-bad classes; validation gate is green.
```

## Behavior

### 1. Resume or start

Read `workshop/progress.json`.

- **If it exists and is mid-run**: summarize where the learner left off (track,
  current step, last note) and ask whether to resume or start over.
- **If it does not exist or is the unfilled template**: initialize it from
  `.agents/skills/run-workshop/resources/progress.template.json` with
  `started_at` set to the current UTC time, and begin at Lab 0.

### 2. Route by track

Ask which track the learner wants.

- **Offline core** (default): no credentials. Walk `workshop/core/lab-0.md`
  through `lab-4.md` in order.
- **Live**: after the core, offer `workshop/more/lab-live-run.md`. Confirm they
  have provider credentials before starting it.

### 3. Drive each lab

For each lab, work step by step through its markdown. For every command:

1. Show the exact command from the lab.
2. Wait for the learner to paste output.
3. Compare against the expected output in the lab and confirm or debug.
4. Give the one or two sentence explanation.
5. Update `workshop/progress.json`.

### 4. Validate checkpoints

At the end of each lab, walk its checkpoint list. Do not advance until every box
is satisfied. If a checkpoint fails, route to the help-me-debug skill.

### 5. Finish

After Lab 4, congratulate the learner, show the final attack-success-rate result,
and offer the MORE labs by name from `workshop/more/README.md`.

## Guardrails

- Never invent output. If the learner's output differs from the lab, treat it as
  a real discrepancy and debug it.
- Never mark a checkpoint complete the learner has not actually hit.
- Keep the learner on their chosen track unless they ask to switch.
