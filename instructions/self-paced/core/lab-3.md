![Lab 3 · Generate and validate an ACS policy, step 4 of the core labs](../assets/banner-core-3.svg)

# Lab 3: Generate and validate an ACS policy

## Objective

Turn the five findings from Lab 2 into a deployable ACS policy, then prove the
policy blocks every known-bad output before you trust it. Generation proposes.
Validation disposes.

## Time estimate

About 15 minutes.

## Prerequisites

- Lab 2 complete. You have five deny targets and a baseline run.

---

## Step 3.1: How generation works

A policy has two parts. A **manifest** (`manifest.yaml`) declares which
intervention points are guarded and where the target value lives. A **Rego
bundle** holds the actual rules that OPA evaluates.

Generating them has exactly one step that needs an LLM. A model reads the
findings and *designs* the rules. Everything after that, compiling the design
into a real manifest and Rego and validating it, is deterministic.

The offline core keeps that one step offline by handing the generator a
pre-authored plan through a fake language model. The plan stands in for what the
LLM would propose. The policy it compiles into is real. Open
`src/policy/generate_offline.py` and read the `PLAN`. Each rule denies one unsafe
class at the `output` point when the response contains a signature of that class.

> On the live track, this whole step is one command:
> `assert-ai acs generate --run-dir <run> --out artifacts/acs/<suite> --model azure/gpt-5.4`.
> The model writes the plan; the rest is the same code you run offline.

## Step 3.2: Generate the policy

```bash
PYTHONPATH=src python3 src/policy/generate_offline.py
```

```text
Generated ACS policy (offline, deterministic)
  manifest:       artifacts/acs/contoso-devbot-shell-abuse-v1/manifest.yaml
  rego:           artifacts/acs/contoso-devbot-shell-abuse-v1/policy/devbot_shell_guardrails.rego
  report:         artifacts/acs/contoso-devbot-shell-abuse-v1/report.md
  guarded_points: output
```

## Step 3.3: Read the generated Rego

Never deploy generated policy you have not read. Open it.

```bash
cat artifacts/acs/contoso-devbot-shell-abuse-v1/policy/devbot_shell_guardrails.rego
```

Notice the shape. There is a `default output_verdict := {"decision": "allow"}`,
then an `else` chain of `deny` rules, each keyed to an unsafe signature. There
are four rules for the five deny targets, because the injected-instruction case
leaks the same secret as the secret-disclosure case, so one `sk-live` rule
covers both. Each rule fires only when `input.intervention_point == "output"`
and the output contains that signature, for example:

```rego
output_verdict := {
    "decision": "deny",
    "reason": "destructive_command",
    ...
} if {
    input.intervention_point == "output"
    contains(lower(input.policy_target.value), "rm -rf")
}
```

Then read the report, which records what the generator assumed and what it could
not verify statically.

```bash
cat artifacts/acs/contoso-devbot-shell-abuse-v1/report.md
```

The report is explicit that it did not verify "policy intent fully captures the
natural-language prompt." That is your job as the reviewer. In this offline demo
the rules use keyword matching, which is easy to read and fully deterministic. A
live LLM-generated policy often prefers a semantic classifier or annotator, which
generalizes better but must still be reviewed for over-denying.

## Step 3.4: Validate against the known-bad outputs

This is the step that earns your trust in the policy. `acs validate` replays
every known-bad example from the ASSERT run through the ACS runtime and OPA, and
reports how many the policy caught.

```bash
assert-ai acs validate \
  --manifest artifacts/acs/contoso-devbot-shell-abuse-v1/manifest.yaml \
  --run-dir data/results/contoso-devbot-shell-abuse-v1/baseline-unguarded \
  --require-block
```

```text
Validation: handled 5/5 (reacted, incl. warn); strongly blocked 5/5 (deny/escalate); handled_rate 100.0%
```

Two numbers, and the difference between them matters.

- **handled** counts examples the policy reacted to at all, including a `warn`.
  A warn notices the problem but still lets the output through.
- **strongly blocked** counts only `deny` and `escalate`, the verdicts that
  actually stop the output.

`--require-block` makes the command exit non-zero unless every known-bad example
is strongly blocked. That is the gate you want in CI. Here it is 5 of 5, so the
command succeeds.

## Step 3.5: Try to break the gate (optional)

Convince yourself the gate is real.

> [!WARNING]
> **Edit the generator before running the commands below.** In
> `src/policy/generate_offline.py`, comment out the entire `secret_disclosure`
> rule block in `PLAN` and save the file. Without this edit, regeneration keeps
> the rule and validation will still pass 5/5.

**First regenerate.**

```bash
PYTHONPATH=src python3 src/policy/generate_offline.py
```

**Then validate.**

```bash
assert-ai acs validate \
  --manifest artifacts/acs/contoso-devbot-shell-abuse-v1/manifest.yaml \
  --run-dir data/results/contoso-devbot-shell-abuse-v1/baseline-unguarded \
  --require-block
```

Now validation drops to 3 of 5 strongly blocked and the command exits non-zero.
Removing one rule cost you two rows. The `Secret disclosure` row falls through,
and so does `Embedded-instruction obedience`, because the injected-instruction
case leaked the same secret and was caught by that same rule. One deleted rule,
two reopened holes.

> [!WARNING]
> **Restore the rule before moving on.** Uncomment the entire
> `secret_disclosure` rule block in `PLAN` and save the file. Then regenerate
> the policy:
>
> ```bash
> PYTHONPATH=src python3 src/policy/generate_offline.py
> ```

---

## What just happened

You generated a real, deployable ACS policy from evidence and then proved, with
OPA, that it strongly blocks all five known-bad classes. You also saw the gate
fail when the policy is incomplete, which is what makes validation worth running.

## Checkpoint

Before moving to Lab 4, confirm:

- [ ] You read the generated Rego and the report
- [ ] `acs validate --require-block` reports 5/5 strongly blocked and exits 0
- [ ] You saw validation fail when a rule was removed, then restored it

**Next**: [Lab 4, Guard, verify, and explore More](lab-4.md)
