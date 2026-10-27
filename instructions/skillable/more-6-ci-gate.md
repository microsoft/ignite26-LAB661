# MORE 6: Gate CI on the policy

Turn validation into a build gate, so a regression that reopens a hole fails CI like a broken test.

1. [] Run the gate and print its exit code.

   ```bash
   assert-ai acs validate \
     --manifest artifacts/acs/contoso-devbot-shell-abuse-v1/manifest.yaml \
     --run-dir data/results/contoso-devbot-shell-abuse-v1/baseline-unguarded \
     --require-block
   echo "exit: $?"
   ```

1. [] Confirm you see 5 of 5 strongly blocked and `exit: 0`.
1. [] In `src/policy/generate_offline.py`, comment out one rule in the `PLAN`, regenerate, and run the gate again.

   ++PYTHONPATH=src python3 src/policy/generate_offline.py++

1. [] Confirm the exit code is no longer `0`. In CI, that fails the job.
1. [] Restore the rule and regenerate.

===

# MORE 6: Read the workflow

The repository ships this gate as a GitHub Actions workflow.

1. [] Read it.

   ++cat .github/workflows/policy-gate.yml++

>[!Knowledge] It does what you just did by hand: install the pinned tools, regenerate the policy from the committed baseline, and run `acs validate --require-block`. It needs no credentials. It runs only when you start it from the **Actions** tab. To gate every change, change its `on:` block to run on `push` and `pull_request`.

>[!Knowledge] Copy three habits into your own repos: pin actions by commit SHA, declare least-privilege permissions (`contents: read`), and pin or checksum every dependency.

>[!Note] **Success:** you have a gate that fails the build when the policy stops blocking a known-bad class. Grow the baseline, and the gate grows with it. That completes LAB661.
