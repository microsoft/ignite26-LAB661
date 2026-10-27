# Generate the policy

Compile the five findings into a deployable ACS policy.

>[!Knowledge] A policy has two parts. A **manifest** (`manifest.yaml`) declares which intervention points are guarded. A **Rego bundle** holds the rules that the Open Policy Agent (OPA) evaluates. Only one step needs an LLM: a model reads the findings and designs the rules. The core lab keeps that step offline by handing the generator a pre-authored plan, the `PLAN` in `src/policy/generate_offline.py`. The policy it compiles into is real.

1. [] Generate the policy.

   ++PYTHONPATH=src python3 src/policy/generate_offline.py++

1. [] Confirm the generator reports a manifest, a Rego file, a report, and `guarded_points: output`.

   ```text-nocopy
   Generated ACS policy (offline, deterministic)
     manifest:       artifacts/acs/contoso-devbot-shell-abuse-v1/manifest.yaml
     rego:           artifacts/acs/contoso-devbot-shell-abuse-v1/policy/devbot_shell_guardrails.rego
     report:         artifacts/acs/contoso-devbot-shell-abuse-v1/report.md
     guarded_points: output
   ```

1. [] Read the generated rules. Never deploy a policy you have not read.

   ++cat artifacts/acs/contoso-devbot-shell-abuse-v1/policy/devbot_shell_guardrails.rego++

1. [] Find the `default output_verdict := {"decision": "allow"}` line and the chain of `deny` rules under it.

1. [] Read the report, which records what the generator could not verify on its own.

   ++cat artifacts/acs/contoso-devbot-shell-abuse-v1/report.md++

>[!Knowledge] There are four rules for five deny targets. The injected-instruction case leaks the same secret as the secret-disclosure case, so one `sk-live` rule covers both. The rules here use keyword matching, which is easy to read and deterministic. A live, model-generated policy often prefers a semantic classifier, which generalizes better but still needs review.

>[!Note] **Success:** you generated a real ACS policy from evidence and read every rule in it.

===

# Validate the policy

Prove the policy blocks every known-bad output before you trust it.

1. [] Replay every known-bad example from the baseline through the policy.

   ```bash
   assert-ai acs validate \
     --manifest artifacts/acs/contoso-devbot-shell-abuse-v1/manifest.yaml \
     --run-dir data/results/contoso-devbot-shell-abuse-v1/baseline-unguarded \
     --require-block
   ```

1. [] Confirm the policy strongly blocked all five.

   ```text-nocopy
   Validation: handled 5/5 (reacted, incl. warn); strongly blocked 5/5 (deny/escalate); handled_rate 100.0%
   ```

>[!Knowledge] **Handled** counts every example the policy reacted to, including a `warn` that still lets the output through. **Strongly blocked** counts only `deny` and `escalate`, the verdicts that actually stop the output. `--require-block` makes the command fail unless every known-bad example is strongly blocked, which is the gate you want in CI.

>[!Note] **Success:** your policy strongly blocks 5 of 5 known-bad classes.

===

# Try to break the gate

This page is optional. Convince yourself the gate is real.

>[!Alert] **Edit the generator before running the commands below.** In `src/policy/generate_offline.py`, comment out the entire `secret_disclosure` rule block in `PLAN` and save the file. Without this edit, regeneration keeps the rule and validation will still pass 5/5.

1. [] **First regenerate.**

   ```bash
   PYTHONPATH=src python3 src/policy/generate_offline.py
   ```

1. [] **Then validate.**

   ```bash
   assert-ai acs validate \
     --manifest artifacts/acs/contoso-devbot-shell-abuse-v1/manifest.yaml \
     --run-dir data/results/contoso-devbot-shell-abuse-v1/baseline-unguarded \
     --require-block
   ```

1. [] Note how many classes are still strongly blocked, and whether the command succeeded.

>[+Hint] Why did removing one rule open two holes?
>
> Validation drops to 3 of 5 and the command fails. The `Secret disclosure` row falls through, and so does `Embedded-instruction obedience`, because the injected-instruction case leaked the same secret and was caught by that same rule.

>[!Alert] **Restore the rule before moving on.** Uncomment the entire `secret_disclosure` rule block in `PLAN` and save the file. Then regenerate the policy:
>
> ```bash
> PYTHONPATH=src python3 src/policy/generate_offline.py
> ```

>[!Note] **Success:** you watched the gate fail on an incomplete policy, which is what makes validation worth running.
