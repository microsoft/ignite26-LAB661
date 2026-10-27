# More 6: Gate CI on the policy

Turn validation into a build gate, so a regression that reopens a hole fails CI like a broken test.

1. [] Run the gate and print its exit code. It ends with `strongly blocked 5/5` and `exit: 0`.

   ++assert-ai acs validate --manifest artifacts/acs/contoso-devbot-shell-abuse-v1/manifest.yaml --run-dir data/results/contoso-devbot-shell-abuse-v1/baseline-unguarded --require-block; echo "exit: $?"++

1. [] Recreate a regression. This script regenerates the policy without the `secret_disclosure` rule. No source file changes.

   ++PYTHONPATH=src python3 src/policy/drop_rule.py++

1. [] Run the gate again. It now ends with `strongly blocked 3/5` and `exit: 1`. In CI, that fails the job.

   ++assert-ai acs validate --manifest artifacts/acs/contoso-devbot-shell-abuse-v1/manifest.yaml --run-dir data/results/contoso-devbot-shell-abuse-v1/baseline-unguarded --require-block; echo "exit: $?"++

1. [] Restore the full policy. Rerun the gate if you like; it prints `exit: 0` again.

   ++PYTHONPATH=src python3 src/policy/generate_offline.py++

>[!Note] **Success:** you watched the gate pass, fail on a regression, and pass again once the policy was restored.

===

# More 6: Read the workflow

The repository ships this gate as a GitHub Actions workflow.

1. [] Read it.

   ++cat .github/workflows/policy-gate.yml++

>[!Knowledge] It does what you just did by hand: install the pinned tools, regenerate the policy from the committed baseline, and run `acs validate --require-block`. It needs no credentials. It runs only when you start it from the **Actions** tab, and GitHub lists it there only once the file is on the repository's default branch. To gate every change, change its `on:` block to run on `push` and `pull_request`.

>[!Knowledge] Copy three habits into your own repos: pin actions by commit SHA, declare least-privilege permissions (`contents: read`), and pin or checksum every dependency.

>[!Note] **Success:** you have a gate that fails the build when the policy stops blocking a known-bad class. Grow the baseline, and the gate grows with it. That completes LAB661.
