# Troubleshooting

Known issues and fixes for problems you might hit. If something is not here, ask
GitHub Copilot Chat to help you debug, and paste the command and its output.

---

## Setup

### `opa: command not found`

ACS evaluates the generated Rego by shelling out to OPA, so the `opa` binary must
be on your `PATH`. The dev container installs it. Rebuild the container, then
confirm with `opa version`.

### `ModuleNotFoundError: No module named 'assert_ai'` or `... 'acs_generator'`

The Python packages did not install. Rebuild the dev container, or install the
pinned versions yourself from the repository root.

```bash
pip install -r requirements.txt
```

Then re-run `./src/scripts/check-setup.sh`.

### `ModuleNotFoundError: No module named 'devbot'`

Every command that touches the agent needs the `src` directory on the Python
path. Prefix the command with `PYTHONPATH=src`, for example
`PYTHONPATH=src python3 src/policy/guard_demo.py`. The helper scripts set this for
you.

---

## Evaluation

### `src/eval/show_findings.py` lists fewer than five deny targets

The deny targets come from the committed baseline in `data/results/`. If you
regenerated it and the count changed, you probably edited the prompt set or the
reference judge in `src/eval/build_baseline_fixture.py`. Restore it or re-run
`PYTHONPATH=src python3 src/eval/build_baseline_fixture.py` to rebuild the default
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
`src/policy/generate_offline.py` and regenerate. Remember that the injected-instruction
case leaks the same secret as the secret-disclosure case, so removing the
`secret_disclosure` rule drops two rows, not one.

### The generated Rego blocks a benign output (over-denial)

Your condition is too broad. Probe it in isolation with `opa eval` (see the
[custom Rego lab](../instructions/self-paced/more/lab-3-custom-rego.md)) and tighten the pattern. Keyword
rules over-match easily. This is a feature of the lab, not a defect, it is
why real deployments prefer a semantic classifier.

---

## Runtime guarding

### A `pre_tool_call` or `post_tool_call` rule never fires under `guard_target`

Expected. The `guard_target` helper enforces the `input` and `output` points
only. Tool-call points are written into the manifest but require a full ACS host
to enforce. See the [intervention points lab](../instructions/self-paced/more/lab-5-intervention-points.md).

### `AgentControlBlocked` raised on a benign prompt

The output happened to contain a blocked signature. Print the agent's raw answer
with `PYTHONPATH=src python3 -m devbot.agent "<prompt>"` and check which pattern
it tripped. If it is a genuine false positive, narrow the offending rule.

---

## Live track

### `assert-ai run` fails with an authentication or model error

The live track signs in with your Azure identity, not an API key. Check each of
these.

- Run `az account show` to confirm you are signed in to the subscription where
  you ran `infra/setup.sh`. If not, run `az login`.
- Copy `.env.example` to `.env`, paste the values the setup script printed, and
  confirm it has `ASSERT_AZURE_USE_AAD=1` and `DEVBOT_MODE=live`.
- A `401` or `403` usually means your **Cognitive Services OpenAI User** role has
  not applied yet. Wait a few minutes and try again.
- `azure-identity package is not installed` means the dev container predates the
  sign-in change. Rebuild the container, or run `pip install -r requirements.txt`.
- Confirm the model names in `src/eval/eval_config.yaml` match deployments in
  your Foundry resource.

The offline core does not need any of this.

### The viewer shows no suites

`assert-ai results` resolves `--results-dir` independently of your current
directory, so pass an absolute path, for example
`--results-dir "$(pwd)/data/results"`. See the
[viewer lab](../instructions/self-paced/more/lab-2-viewer.md).
