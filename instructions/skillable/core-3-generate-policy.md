# Generate the policy

Compile the five findings into a deployable ACS policy.

>[!Knowledge] A policy has two parts. A **manifest** (`manifest.yaml`) declares which intervention points are guarded. A **Rego bundle** holds the rules that the Open Policy Agent (OPA) evaluates. Only one step needs an LLM: a model reads the findings and designs the rules. The core lab keeps that step offline by handing the generator a pre-authored plan, the `PLAN` in `src/policy/generate_offline.py`. The policy it compiles into is real.

1. [] Generate the policy.

   ++$env:PYTHONPATH = "src"; python src/policy/generate_offline.py++

1. [] Confirm the generator reports a manifest, a Rego file, a report, and `guarded_points: output`.

   ```text-nocopy
   Generated ACS policy (offline, deterministic)
     manifest:       artifacts\acs\contoso-devbot-shell-abuse-v1\manifest.yaml
     rego:           artifacts\acs\contoso-devbot-shell-abuse-v1\policy\devbot_shell_guardrails.rego
     report:         artifacts\acs\contoso-devbot-shell-abuse-v1\report.md
     guarded_points: output
   ```

1. [] Read the generated rules. Never deploy a policy you have not read.

   ++Get-Content artifacts/acs/contoso-devbot-shell-abuse-v1/policy/devbot_shell_guardrails.rego++

1. [] Find the `default output_verdict := {"decision": "allow"}` line and the chain of `deny` rules under it.

1. [] Read the report, which records what the generator could not verify on its own.

   ++Get-Content artifacts/acs/contoso-devbot-shell-abuse-v1/report.md++

>[!Knowledge] There are four rules for five deny targets. The injected-instruction case leaks the same secret as the secret-disclosure case, so one `sk-live` rule covers both. The rules here use keyword matching, which is easy to read and deterministic. A live-generated policy can use deterministic rules over structured arguments and trusted state, or semantic annotators for free-form content. Review either form against unsafe and benign cases.

>[!Note] **Success:** you generated a real ACS policy from evidence and read every rule in it.

===

# Validate the policy

Prove the policy blocks every known-bad output before you trust it.

1. [] Replay every known-bad example from the baseline through the policy.

   ++assert-ai acs validate --manifest artifacts/acs/contoso-devbot-shell-abuse-v1/manifest.yaml --run-dir data/results/contoso-devbot-shell-abuse-v1/baseline-unguarded --require-block++

1. [] Confirm the policy strongly blocked all five.

   ```text-nocopy
   Validation: handled 5/5 (reacted, incl. warn); strongly blocked 5/5 (deny/escalate); handled_rate 100.0%
   ```

>[!Knowledge] **Handled** counts every example the policy reacted to, including a `warn` that still lets the output through. **Strongly blocked** counts only `deny` and `escalate`, the verdicts that actually stop the output. `--require-block` makes the command fail unless every known-bad example is strongly blocked, which is the gate you want in CI.

>[!Note] **Success:** your policy strongly blocks 5 of 5 known-bad classes.

===

# Try to break the gate

This page is optional. Convince yourself the gate is real.

1. [] **First swap in a generator with the `secret_disclosure` rule commented out.**

   ++Copy-Item src/policy/lab-variants/generate_offline.no-secret-rule.py.txt src/policy/generate_offline.py -Force++

1. [] **Then regenerate.**

   ++$env:PYTHONPATH = "src"; python src/policy/generate_offline.py++

1. [] **Then validate.**

   ++assert-ai acs validate --manifest artifacts/acs/contoso-devbot-shell-abuse-v1/manifest.yaml --run-dir data/results/contoso-devbot-shell-abuse-v1/baseline-unguarded --require-block++

1. [] Note how many classes are still strongly blocked, and whether the command succeeded.

>[+Hint] Why did removing one rule open two holes?
>
> Validation drops to 3 of 5 and the command fails. The `Secret disclosure` row falls through, and so does `Embedded-instruction obedience`, because the injected-instruction case leaked the same secret and was caught by that same rule.

>[!Alert] **Restore the rule before moving on.** Lab 4 needs the full policy.

1. [] Copy the original generator back.

   ++Copy-Item src/policy/lab-variants/generate_offline.full.py.txt src/policy/generate_offline.py -Force++

1. [] Regenerate the full policy.

   ++$env:PYTHONPATH = "src"; python src/policy/generate_offline.py++

1. [] Confirm it is back to 5 of 5. It should report `strongly blocked 5/5` and succeed.

   ++assert-ai acs validate --manifest artifacts/acs/contoso-devbot-shell-abuse-v1/manifest.yaml --run-dir data/results/contoso-devbot-shell-abuse-v1/baseline-unguarded --require-block++

>[!Note] **Success:** you watched the gate fail on an incomplete policy, which is what makes validation worth running.
