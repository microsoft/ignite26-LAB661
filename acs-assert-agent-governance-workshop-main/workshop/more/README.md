# MORE labs

The core labs taught the whole loop. These go deeper on one topic each. They are
independent, so take them in any order.

| Lab | You will learn | Needs a key? |
|-----|----------------|--------------|
| [Author custom Rego](lab-custom-rego.md) | Hand-write and test an ACS rule, including a `transform` that redacts instead of denies | No |
| [Intervention points and tool calls](lab-intervention-points.md) | What each ACS point is for, and why runtime tool-call enforcement needs a full host | No |
| [Go live with a real model](lab-live-run.md) | Run a real `assert-ai run` and generate a policy with a live LLM | Yes |
| [Gate CI on the policy](lab-ci-gate.md) | Fail a build when the policy stops blocking a known-bad class | No |
| [Browse runs in the ASSERT viewer](lab-viewer.md) | Inspect findings and compare runs with the local viewer | No |
| [Adaptive red-teaming](lab-red-teaming.md) | Find an output that slips past the keyword policy and close the gap | No |
| [Drive evals with the run-assert-eval skill](lab-assert-skill.md) | Let your coding assistant discover a risk, run the eval, generate a policy, and rerun it to prove the fix | Yes |

All of the no-key labs run against the committed offline fixture and the policy
you generated in the core. If you have not run the core, do
`./scripts/run-offline-loop.sh` first.
