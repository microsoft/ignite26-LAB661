![More 6 · Gate CI on the policy, optional offline lab](../assets/banner-more-6.svg)

# More 6: Gate CI on the policy

## Objective

Turn the validation step into a build gate. Once a policy protects your agent, a
regression that reopens a hole should fail CI the same way a broken test does.

## What you will learn

- How `acs validate --require-block` behaves as a pass/fail gate.
- How to wire it into GitHub Actions with no credentials.

---

## Step 1: The gate is just an exit code

`acs validate --require-block` exits 0 when every known-bad example is strongly
blocked, and non-zero otherwise. That is all a CI gate needs.

Confirm the passing case exits 0.

```bash
assert-ai acs validate \
  --manifest artifacts/acs/contoso-devbot-shell-abuse-v1/manifest.yaml \
  --run-dir data/results/contoso-devbot-shell-abuse-v1/baseline-unguarded \
  --require-block; echo "exit: $?"
```

The output ends with:

```text
Validation: handled 5/5 (reacted, incl. warn); strongly blocked 5/5 (deny/escalate); handled_rate 100.0%
exit: 0
```

## Step 2: Watch it fail

Recreate a regression. A script regenerates the policy with the
`secret_disclosure` rule removed, without editing any source file.

### Step 2.1: Drop a rule

```bash
PYTHONPATH=src python3 src/policy/drop_rule.py
```

```text
Dropped rule: secret_disclosure
Regenerated artifacts/acs/contoso-devbot-shell-abuse-v1/policy/devbot_shell_guardrails.rego
```

### Step 2.2: Run the gate again

```bash
assert-ai acs validate \
  --manifest artifacts/acs/contoso-devbot-shell-abuse-v1/manifest.yaml \
  --run-dir data/results/contoso-devbot-shell-abuse-v1/baseline-unguarded \
  --require-block; echo "exit: $?"
```

The output now ends with:

```text
Validation: handled 3/5 (reacted, incl. warn); strongly blocked 3/5 (deny/escalate); handled_rate 60.0%
ACS policy did not strongly block 2 known-bad example(s) (only deny/escalate counts as a block).
exit: 1
```

Two examples get through, the secret leak and the injected instruction that
leaks a secret. In CI, `exit: 1` fails the job.

### Step 2.3: Restore the full policy

```bash
PYTHONPATH=src python3 src/policy/generate_offline.py
```

Rerun the gate from Step 1. It prints `exit: 0` again.

## Step 3: The workflow

This lab ships the gate as a GitHub Actions workflow.

```bash
cat .github/workflows/policy-gate.yml
```

It does exactly what you just did by hand. Checks out the repo, installs Python,
OPA (checking its download against the published checksum), and the pinned
packages in `requirements.txt`, regenerates the policy from the committed
baseline, and runs `acs validate --require-block`. No credentials are involved,
because the whole thing runs against the committed offline baseline.

It runs only when you start it. On GitHub, open the **Actions** tab, pick
**policy-gate**, and select **Run workflow**. GitHub lists a manually started
workflow only once its file is on the repository's default branch, which it is
in your own fork. To gate every change instead,
replace the `on:` block with this and commit it.

```yaml
on:
  push:
    branches: [main]
  pull_request:
```

Three things worth copying into your own repos.

- The actions are **pinned by commit SHA**, not by a moving tag. That is a
  supply-chain hygiene default.
- The workflow declares **least-privilege permissions**, `contents: read` at the
  top level, so a compromised step cannot write to the repo.
- Every dependency is **pinned or checksum-verified**, so CI tests the same
  versions you ran locally.

## Step 4: Make it meaningful

A gate is only as strong as the evidence behind it. As you find new failure
classes with ASSERT, add them to the baseline run, regenerate, and the gate now
protects those too. The gate does not test that the policy is perfect. It tests
that the policy still blocks everything you have already proven it should.

---

## Takeaways

- `--require-block` turns validation into a pass/fail gate via its exit code.
- The gate runs offline, so it belongs in every PR.
- Grow the baseline and the gate grows with it.
