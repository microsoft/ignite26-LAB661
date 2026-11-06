# More labs

The core labs taught the whole loop. These optional labs go deeper on one topic
each. We recommend following them in the numbered order below. More 0 starts
with the Azure setup and live checks.

| Lab | You will learn | Needs Azure? |
|-----|----------------|--------------|
| [0. Drive the evaluation with the run-assert-eval skill](lab-0-assert-skill.md) | Set up Foundry, then let GitHub Copilot discover a risk, run the eval, generate a policy, and rerun it to prove the fix | Yes |
| [1. Go live with a real model](lab-1-live-run.md) | The manual path: run `assert-ai run` and generate a policy with a live LLM by hand, and spot a policy that never fires. Skip it if you finished More 0 | Yes |
| [2. Browse runs in the ASSERT viewer](lab-2-viewer.md) | Inspect findings and compare runs with the local viewer | No |
| [3. Author custom Rego](lab-3-custom-rego.md) | Hand-write and test an ACS rule, including a `transform` that redacts instead of denies | No |
| [4. Adaptive red-teaming](lab-4-red-teaming.md) | Find an output that slips past the keyword policy and close the gap | No |
| [5. Intervention points and tool calls](lab-5-intervention-points.md) | What each ACS point is for, and how Agent Hooks connects hosts to controls for tool-call enforcement | No |
| [6. Gate CI on the policy](lab-6-ci-gate.md) | Fail a build when the policy stops blocking a known-bad class | No |

No Azure subscription? Start at More 2. Finished More 0? Skip More 1 and go to
More 2. The offline labs use the committed
baseline and the policy you generated in the core. If you have not run the core,
run `bash src/scripts/run-offline-loop.sh` first.
