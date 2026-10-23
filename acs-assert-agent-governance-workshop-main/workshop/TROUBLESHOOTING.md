# Troubleshooting

Known issues and fixes for problems you might hit. If something is not here, open
Copilot Chat and say **"help me debug"**, which routes to the
[help-me-debug skill](../.agents/skills/help-me-debug/SKILL.md).

---

## Setup

### `opa: command not found`

ACS evaluates the generated Rego by shelling out to OPA, so the `opa` binary must
be on your `PATH`. The Python `acs` extra does not install it. Download the
single static binary from the [OPA docs](https://www.openpolicyagent.org/docs/latest/#running-opa)
and put it somewhere on your `PATH`, then confirm with `opa version`.

### `ModuleNotFoundError: No module named 'assert_ai'` or `... 'acs_generator'`

ASSERT is not on PyPI. Install it from a local clone with the `acs` extra.

```bash
git clone https://github.com/responsibleai/ASSERT.git
pip install -e "./ASSERT[acs]"
```

If `assert_ai` imports but `acs_generator` or `agent_control_specification` do
not, you installed ASSERT without the `[acs]` extra. Re-run the install with the
extra.

### `ModuleNotFoundError: No module named 'devbot'`

Every command that touches the agent needs the `src` directory on the Python
path. Prefix the command with `PYTHONPATH=src`, for example
`PYTHONPATH=src python3 policy/guard_demo.py`. The helper scripts set this for
you.

---

## Evaluation

### `eval/show_findings.py` lists fewer than five deny targets

The deny targets come from the committed baseline fixture. If you regenerated it
and the count changed, you probably edited the prompt set or the reference judge
in `eval/build_baseline_fixture.py`. Restore it or re-run
`PYTHONPATH=src python3 eval/build_baseline_fixture.py` to rebuild the default
14-case baseline.

### A permissible behavior is missing from the deny targets

That is correct, not a bug. ASSERT marks `Bounded safe shell assistance` and
`Safe refusal` as permissible, and the adapter never turns a permissible node
into a deny rule, because a guardrail cannot compel helpfulness. Overrefusal is
reported as a dimension instead. See Lab 2.

---

## Policy generation and validation

### `assert-ai acs validate` reports fewer than 5/5 strongly blocked

A rule is missing or does not match the known-bad output. If you were following
the Lab 3 "try to break the gate" step, restore the deleted rule in the `PLAN` in
`policy/generate_offline.py` and regenerate. Remember that the injected-instruction
case leaks the same secret as the secret-disclosure case, so removing the
`secret_disclosure` rule drops two rows, not one.

### The generated Rego blocks a benign output (over-denial)

Your condition is too broad. Probe it in isolation with `opa eval` (see the
[custom Rego lab](more/lab-custom-rego.md)) and tighten the pattern. Keyword
rules over-match easily. This is a feature of the workshop, not a defect, it is
why real deployments prefer a semantic classifier.

---

## Runtime guarding

### A `pre_tool_call` or `post_tool_call` rule never fires under `guard_target`

Expected. The `guard_target` helper enforces the `input` and `output` points
only. Tool-call points are written into the manifest but require a full ACS host
to enforce. See the [intervention points lab](more/lab-intervention-points.md).

### `AgentControlBlocked` raised on a benign prompt

The output happened to contain a blocked signature. Print the agent's raw answer
with `PYTHONPATH=src python3 -m devbot.agent "<prompt>"` and check which pattern
it tripped. If it is a genuine false positive, narrow the offending rule.

---

## Live track

### `assert-ai run` fails with an authentication or model error

The live track needs provider credentials. Copy `.env.example` to `.env`, fill in
your provider keys, and set `DEVBOT_MODE=live`. Confirm the model name in
`eval/eval_config.yaml` matches a deployment you can reach. The offline core does
not need any of this.

### The viewer shows no suites

`assert-ai results` resolves `--results-dir` independently of your current
directory, so pass an absolute path, for example
`--results-dir "$(pwd)/eval/fixtures/results"`. See the
[viewer lab](more/lab-viewer.md).
