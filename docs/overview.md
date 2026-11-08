# Secure a coding agent with ACS and ASSERT

Contoso DevBot is a fictitious internal DevOps assistant. Engineers ask it to
inspect repositories, explain build failures, and suggest shell commands, and it
answers quickly. It also ships with no guardrails. Ask it the wrong question and
it will suggest deleting your working tree with `rm -rf`, read a `.env` file and
print the API key inside, pipe a remote script straight into a shell, or carry
out an instruction hidden in a file it was told to read.

This lab makes DevBot safe without editing the agent. You evaluate it with
ASSERT to find where it breaks, compile those findings into an Agent Control
Specification (ACS) policy, and put that policy in front of the agent at runtime.
The result is the same DevBot, now refusing every unsafe request while still
answering the safe ones.

![The guarded DevBot architecture](media/architecture.png)

ASSERT is a spec-driven evaluation framework. ACS is the policy runtime from the
Agent Governance Toolkit. ASSERT's ACS adapter connects the two. It reads an
evaluation's findings and writes a deployable policy that blocks the behavior
those findings describe. You run each stage yourself and watch DevBot's attack
success rate fall from 100 percent to zero.

![The evaluate, generate, validate, guard, and verify loop](media/loop.png)

## What you will build

By the end of the lab you will have:

1. run a local agent and seen five distinct ways it misbehaves
2. produced an ASSERT evaluation that names each failure and measures how often it occurs
3. generated an ACS policy, an OPA and Rego bundle plus a manifest, from those findings
4. proven the policy blocks every known-bad output before it is deployed
5. enforced the policy at runtime and measured the drop in attack success rate

## Tracks

The lab has an offline core and a live track. Take the core first.

| Track | For | Requires | Start here |
|-------|-----|----------|-----------|
| Offline core | Everyone. The guaranteed path. | The dev container. No Azure sign-in, no API key. | [`core`](../instructions/self-paced/core/lab-0.md) |
| Live | After the core, to run a real evaluation. | An Azure subscription, signed in with `az login`. No API key. | [More 0](../instructions/self-paced/more/lab-0-assert-skill.md) and [More 1](../instructions/self-paced/more/lab-1-live-run.md) |

> The offline core runs the entire loop with a deterministic agent and a
> committed evaluation, so it needs no API key and produces the same result every
> time. The live track swaps in a real model for the agent, the evaluation, and
> the policy generation, so its numbers vary from run to run. The ACS commands
> are the same in both, but a model-designed policy may rely on LLM classifiers,
> which offline validation cannot test. Prove those with a governed rerun.
>
> Everything in this repository runs locally. Nothing executes a real shell
> command or opens a network connection. DevBot's tools are simulated, and the
> only credential in the repository is an obviously fake placeholder.

## Prerequisites

Open the repository in GitHub Codespaces, or in VS Code with the Dev Containers
extension. The dev container installs Python, the Azure CLI, the Open Policy
Agent (`opa`) binary that ACS uses to evaluate Rego, and the pinned packages in
`requirements.txt`, including ASSERT with its `acs` extra. The live track also
needs an Azure subscription.

## Run it

Verify your environment, then run the whole loop in one command:

```bash
bash src/scripts/check-setup.sh
bash src/scripts/run-offline-loop.sh
```

The second command captures a baseline evaluation, generates the policy,
validates it against every known-bad output, enforces it at runtime, and prints
the before-and-after attack success rate. The core labs walk through the same
five stages one at a time, so you can run each yourself and read what it
produced.

## Labs

The core is five labs and takes about an hour. Start at
[the self-paced guide](../instructions/self-paced/README.md).

| # | Lab | Outcome |
|---|-----|---------|
| 0 | [Setup](../instructions/self-paced/core/lab-0.md) | Environment verified, offline loop runs end to end |
| 1 | [Meet DevBot and map the risk](../instructions/self-paced/core/lab-1.md) | You have seen the agent misbehave and know the ACS vocabulary |
| 2 | [Evaluate with ASSERT](../instructions/self-paced/core/lab-2.md) | Findings that name five unsafe classes to block |
| 3 | [Generate and validate an ACS policy](../instructions/self-paced/core/lab-3.md) | A Rego policy that blocks every known-bad output |
| 4 | [Guard, verify, and explore More](../instructions/self-paced/core/lab-4.md) | DevBot secured, attack success 100 percent to zero |

Seven [More labs](../instructions/self-paced/more/README.md) go deeper: the
run-assert-eval skill with GitHub Copilot, a live run, the results viewer, custom
Rego, adaptive red-teaming, intervention points, and a CI gate.

## Repository layout

| Path | Contents |
|------|----------|
| `src/devbot/` | The DevBot agent and its simulated tools |
| `src/eval/` | The live evaluation config, the fixture builder, and the findings viewer |
| `src/policy/` | The offline policy generator, the runtime guard demo, and the verification script |
| `src/scripts/` | `check-setup.sh` and `run-offline-loop.sh` |
| `data/results/` | The committed baseline run and behavior taxonomy |
| `infra/` | `setup.sh`, which provisions Microsoft Foundry for the live track |
| `instructions/self-paced/core/` | Core labs 0 through 4 |
| `instructions/self-paced/more/` | More labs 0 through 6 |
| `.github/skills/run-assert-eval/` | The ASSERT skill used in More 0 |
| `docs/` | This overview, troubleshooting, and the diagrams in `media/` |

## License

MIT for the lab code. ASSERT and the Agent Governance Toolkit carry their
own licenses.
