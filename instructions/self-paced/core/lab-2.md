![Lab 2 · Evaluate with ASSERT, step 3 of the core labs](../media/banner-core-2.svg)

# Lab 2: Evaluate with ASSERT

## Objective

Turn "DevBot feels unsafe" into a precise, evidence-backed list of what to
block. You will capture a baseline evaluation and read its findings the way the
ACS adapter reads them.

## Time estimate

About 15 minutes.

## Prerequisites

- Lab 1 complete. You have seen DevBot misbehave.

---

## Step 2.1: What ASSERT does

ASSERT is spec-driven. You describe, in natural language, the behaviors an agent
should and should not exhibit. ASSERT then generates adversarial and benign test
prompts from that spec, sends them to the agent, records each conversation, and
uses an LLM judge to score every conversation against your behavior taxonomy. It
writes three artifacts per run:

| File | Contents |
|------|----------|
| `inference_set.jsonl` | The full transcript of each test conversation |
| `scores.jsonl` | The judge's verdict per case, including which taxonomy nodes were violated |
| `taxonomy.json` | The behavior categories, each marked permissible or not |

The ASSERT to ACS adapter reads exactly these three files.

## Step 2.2: Capture the baseline run

A real ASSERT run needs a model to generate tests and to judge. The offline core
captures the same three artifacts deterministically instead, by running DevBot
over a fixed red-team prompt set and applying a small reference judge. The output
is a faithful ASSERT run directory.

```bash
PYTHONPATH=src python3 src/eval/build_baseline_fixture.py
```

The first two lines read as follows, then the script prints the full path of
each file it wrote.

```text
Wrote baseline fixture to data/results/contoso-devbot-shell-abuse-v1/baseline-unguarded
  cases: 14   policy_violations: 10
```

> The committed baseline is already in the repo, so this step is really "see how
> the baseline was produced." On the [live track](../more/lab-1-live-run.md) you
> replace this one command with `assert-ai run --config src/eval/eval_config.yaml`
> and everything downstream is identical.

## Step 2.3: Look at the raw evidence

Open one transcript and one score. This is what the judge saw.

```bash
head -1 data/results/contoso-devbot-shell-abuse-v1/baseline-unguarded/inference_set.jsonl | python3 -m json.tool
head -1 data/results/contoso-devbot-shell-abuse-v1/baseline-unguarded/scores.jsonl | python3 -m json.tool
```

In the score, notice `verdict.dimensions.policy_violation` and the
`verdict.node_judgments` list. Each node judgment says whether a specific
taxonomy category was `relevant` to this case and whether it was `violated`. That
node-level detail is what lets ACS attribute a violation to a specific behavior.

## Step 2.4: Read the findings the way ACS does

Now read the run through the real adapter and see the summary it produces.

```bash
PYTHONPATH=src python3 src/eval/show_findings.py
```

After a short header naming the suite, run, behavior, and target, you see:

```text
Overall dimensions (violation rate across all scored cases):
  overrefusal             0%  (0/14)
  policy_violation       71%  (10/14)

Deny targets (non-permissible behavior nodes ASSERT saw violated):
  - Data exfiltration
  - Destructive shell command issuance or endorsement
  - Embedded-instruction obedience
  - Remote code execution endorsement
  - Secret disclosure

Intervention points with evidence: output
```

There are your five deny targets. Two facts about this summary matter.

**Permissible nodes are not deny targets.** The taxonomy marks `Bounded safe
shell assistance` and `Safe refusal` as permissible. Even though DevBot's benign
answers were categorized under `Bounded safe shell assistance`, that node never
becomes a deny target. A guardrail can restrict actions, it cannot compel
helpfulness, so ACS refuses to write a rule that would deny the agent's safe
answers. Overrefusal is reported as a dimension for your awareness, not turned
into a block.

**Every violation surfaces at `output`.** The adapter recovered the offending
assistant text from the transcripts and attributed it to the `output`
intervention point. That is why the policy you build next guards `output`.

## Step 2.5: Note your baseline

Write down the headline: **policy_violation 71% (10 of 14 cases)**. That is the
number you will drive down. Ten of the fourteen prompts produced an unsafe
response, and every one of the five unsafe classes fired.

---

## What just happened

You converted a vague worry into five named, evidence-backed deny targets, each
with a representative unsafe output and a measured violation rate. This is the
input ACS needs. You did not guess at what to block. The evaluation told you.

## Checkpoint

Before moving to Lab 3, confirm:

- [ ] `src/eval/show_findings.py` lists five deny targets
- [ ] You understand why the permissible nodes are excluded
- [ ] You noted the baseline `policy_violation` rate

**Next**: [Lab 3, Generate and validate an ACS policy](lab-3.md)
