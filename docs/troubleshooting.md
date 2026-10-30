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
rules can over-match benign content. Use deterministic rules for checks on
structured tool arguments and trusted state, or semantic annotators when the
decision requires interpreting free-form content. Re-test against unsafe and
benign cases.

---

## Runtime guarding

### A `pre_tool_call` or `post_tool_call` rule never fires under `guard_target`

Expected. The `guard_target` helper enforces the `input` and `output` points
only. Tool-call points declared in the manifest need host integration around
actual tool execution. See the [intervention points lab](../instructions/self-paced/more/lab-5-intervention-points.md).

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
- Confirm `.env` exists. `infra/setup.sh` writes it; if it is missing or out of
  date, run setup again and answer `y` when it asks to replace `.env`.
- A `401` or `403` usually means your **Cognitive Services OpenAI User** role has
  not applied yet. Wait a few minutes and try again.
- `DefaultAzureCredential failed to retrieve a token` means you are not signed
  in, for example after a container rebuild. Run `az login --use-device-code`.
- `azure-identity package is not installed` means the dev container predates the
  sign-in change. Rebuild the container, or run `pip install -r requirements.txt`.
- Confirm the model names in `src/eval/eval_config.yaml` match deployments in
  your Foundry resource.

The offline core does not need any of this.

### The run-assert-eval skill says `node` is missing

The skill uses Node.js to fetch research sources. Rebuild the dev container, then
confirm `./src/scripts/check-setup.sh` shows `node on PATH`. After a rebuild,
sign in again with `az login --use-device-code`.

### The skill asks permission before each command

Set the chat's permissions to **Allow All** before you start, as More 0 Step 3
describes. Then open a new chat and paste the Step 5 prompt again.

### The skill's research is slow, or a source returns `404`

Research fetches several papers and guides before it proposes test dimensions,
so it can take several minutes. A `404` means a page moved; the skill looks for
another copy and continues. Wait for the dimension review.

### `Rate limiter: waiting ...s for model ... cooldown`

ASSERT is pacing its calls to stay under the model deployment's tokens-per-minute
limit. It waits and retries, so nothing is lost; the run is only slower. Running
More 0 and More 1 at the same time makes it worse.

If the chat looks stuck while ASSERT waits, move the command to the background
with the play icon on its terminal, then tell the skill to continue. It resumes
faster than waiting for the foreground command to return.

`infra/setup.sh` deploys `gpt-5.4-mini` at 500K tokens per minute and `gpt-5.4`
at 100K. ASSERT generates test cases on `gpt-5.4-mini` with 8 parallel calls, so
it needs the extra headroom. If your quota is lower, deployment fails with a
"check quota" warning; run setup again with a smaller capacity, for example
`MINI_CAPACITY=200 MODEL_CAPACITY=50 bash infra/setup.sh`. Setup does not change
the capacity of a deployment that already exists. To raise an existing one:

```bash
RG=rg-lab661-foundry
ACCT=$(az cognitiveservices account list -g $RG --query '[0].name' -o tsv)
VER=$(az cognitiveservices account deployment show -g $RG -n $ACCT --deployment-name gpt-5.4-mini --query properties.model.version -o tsv)
az cognitiveservices account deployment create -g $RG -n $ACCT --deployment-name gpt-5.4-mini \
  --model-name gpt-5.4-mini --model-version $VER --model-format OpenAI \
  --sku-name GlobalStandard --sku-capacity 500 --query sku.capacity -o tsv
```

### `cd viewer` fails after a run

ASSERT prints `cd viewer && npm run dev` at the end of a run. That browser viewer
ships only in ASSERT's source repository, not in the PyPI package this lab
installs. Use the `assert-ai results` commands instead, as in the
[viewer lab](../instructions/self-paced/more/lab-2-viewer.md). For a live run,
pass `--results-dir "$PWD/artifacts/results"`.

### Live results are not under `artifacts/results/`

Installed from PyPI, ASSERT 0.3.0 resolves relative result paths against its own
install folder, so runs land under `site-packages/artifacts/results/`. Add
`--override artifacts_root="$PWD/artifacts"` to `assert-ai run`, and point the
`acs` commands at the run with `--run-dir`, as the live labs do.

### The skill reports a validation error in its dimension review

Its validator checks the review's bookkeeping fields. The skill fixes the field
and reruns the check on its own; the test design does not change. Let it finish.

### No `examples/` folder appears

The skill writes the config only after you approve the dimension review. Until
then there is nothing under `examples/`.

### The viewer shows no suites

`assert-ai results` resolves `--results-dir` independently of your current
directory, so pass an absolute path, for example
`--results-dir "$(pwd)/data/results"`. See the
[viewer lab](../instructions/self-paced/more/lab-2-viewer.md).
