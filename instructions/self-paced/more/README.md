# MORE labs

The core labs taught the whole loop. These go deeper on one topic each. They are
numbered in a suggested order, and each one stands on its own.

| Lab | You will learn | Needs Azure? |
|-----|----------------|--------------|
| [0. Drive the evaluation with the run-assert-eval skill](lab-0-assert-skill.md) | Set up Foundry, then let GitHub Copilot discover a risk, run the eval, generate a policy, and rerun it to prove the fix | Yes |
| [1. Go live with a real model](lab-1-live-run.md) | Run a real `assert-ai run` and generate a policy with a live LLM, by hand | Yes |
| [2. Browse runs in the ASSERT viewer](lab-2-viewer.md) | Inspect findings and compare runs with the local viewer | No |
| [3. Author custom Rego](lab-3-custom-rego.md) | Hand-write and test an ACS rule, including a `transform` that redacts instead of denies | No |
| [4. Adaptive red-teaming](lab-4-red-teaming.md) | Find an output that slips past the keyword policy and close the gap | No |
| [5. Intervention points and tool calls](lab-5-intervention-points.md) | What each ACS point is for, and why runtime tool-call enforcement needs a full host | No |
| [6. Gate CI on the policy](lab-6-ci-gate.md) | Fail a build when the policy stops blocking a known-bad class | No |

No Azure subscription? Start at MORE 2. The offline labs use the committed
baseline and the policy you generated in the core. If you have not run the core,
run `./src/scripts/run-offline-loop.sh` first.
