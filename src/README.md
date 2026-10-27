# Source

This folder holds everything the lab runs. You secure **Contoso DevBot**, a
small DevOps helpdesk agent that answers quickly and has no guardrails. Ask it
the wrong question and it endorses `rm -rf`, prints a secret, uploads your
`.env`, pipes a remote script into a shell, or obeys an instruction hidden in a
file. The lab fixes that without editing the agent, in five stages:

1. **Evaluate** DevBot with ASSERT to find where it breaks.
2. **Generate** an Agent Control Specification (ACS) policy from those findings.
3. **Validate** that the policy blocks every known-bad output.
4. **Guard** DevBot with the policy at runtime.
5. **Verify** the improvement: attack success drops from 100% to 0%.

Nothing dangerous ever runs. DevBot's tools are simulated, and its secret is a
fake that only looks real.

## What is here

| Folder | Contents | Used in |
|--------|----------|---------|
| [`devbot/`](devbot/) | The agent. `agent.py` exposes one callable, `chat(message)`, with a deterministic offline mode (the default) and a live mode that calls a real model with your Azure sign-in. `tools.py` holds the simulated tools. `instructions.md` is the deliberately weak system prompt for live mode. | Core Lab 1 |
| [`eval/`](eval/) | The ASSERT side. `build_baseline_fixture.py` rebuilds the committed baseline run in `data/results/`. `show_findings.py` reads it the way the ACS adapter does. `eval_config.yaml` is the config for a real `assert-ai run`. | Core Lab 2, More 0 and 1 |
| [`policy/`](policy/) | The ACS side. `generate_offline.py` compiles the findings into a policy in `artifacts/acs/`. `guard_demo.py` runs DevBot behind it. `verify_reeval.py` measures attack success before and after. `examples/redact.rego` is a hand-written rule. | Core Labs 3 and 4, More 3 |
| [`scripts/`](scripts/) | `check-setup.sh` verifies your environment. `run-offline-loop.sh` runs all five stages end to end. | Core Lab 0 |

## Run it

Run every command from the repository root. Python needs `src` on its path to
find DevBot.

```bash
./src/scripts/check-setup.sh
./src/scripts/run-offline-loop.sh
PYTHONPATH=src python3 -m devbot.agent "How do I see recent commits?"
```

The offline path needs no Azure sign-in and gives the same result every run.
For the step-by-step guide, start at
[the self-paced labs](../instructions/self-paced/README.md).
