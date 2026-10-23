# MORE: Browse runs in the ASSERT viewer

## Objective

Use ASSERT's built-in results browser to inspect the baseline run and read its
metrics the way a reviewer would, without writing any Python.

## What you will learn

- How to list suites and runs from the command line.
- How to read a run's dimensions and per-case detail.

---

## Step 1: Point the viewer at the workshop fixtures

The `assert-ai results` commands scan a results directory. The workshop's
committed run lives under `eval/fixtures/results`, so pass that path. Use an
absolute path, since the results root is resolved independently of your current
directory.

```bash
assert-ai results list --results-dir "$(pwd)/eval/fixtures/results"
```

```text
Suite                    Behavior Ca…  Prompt Tes…  Scenario Te…  Status
contoso-devbot-shell-a…  7             0            0             Has Evaluatio…
```

## Step 2: Read the run summary

```bash
assert-ai results status contoso-devbot-shell-abuse-v1 baseline-unguarded \
  --results-dir "$(pwd)/eval/fixtures/results"
```

You get the same numbers you computed in Lab 2, now as a formatted report.

```text
Target              devbot.agent:chat
Judge Model         reference-judge/deterministic
Total               14
...
Dimension         Flagged rate  Scored  Flagged / Pass
Overrefusal       0.0%          14      0 flagged / 14 pass
Policy violation  71.4%         14      10 flagged / 4 pass
```

The `Judge Model` reads `reference-judge/deterministic`, a reminder that this
baseline was captured offline. On the live track it would name the real judge
model.

## Step 3: Compare two runs

The viewer's real power is comparison, pinning a baseline and reading the delta.
You do not have a second run yet, but the shape of the command is:

```bash
assert-ai results compare <suite> <baseline-run> <candidate-run> \
  --results-dir "$(pwd)/eval/fixtures/results"
```

You get a second run by running the live track (a real `assert-ai run` produces
a fresh run under `artifacts/results/`), or by capturing a second baseline after
you change the agent. Comparison is how you prove an agent change moved a metric,
which is the same evaluate-and-verify discipline the core loop teaches, viewed
through evaluation instead of policy.

---

## Takeaways

- `assert-ai results list` and `results status` read runs with no code.
- Pass an absolute `--results-dir` to point the viewer at the workshop fixtures.
- `results compare` is how you read a before-and-after once you have two runs.
