# LAB661 self-paced guide

Run the lab on your own in GitHub Codespaces or VS Code. You secure Contoso
DevBot, a deliberately under-governed coding agent, with a policy generated from
evidence of its own misbehavior. ASSERT finds what DevBot does wrong. Agent
Control Specification (ACS) blocks it at runtime.

This guide has the same labs as the in-venue [Skillable manual](../skillable/README.md).
The difference is setup: here you open the environment yourself, and for the
live More labs you provision Microsoft Foundry in your own Azure subscription.

- **Core:** about 60 minutes, offline, no Azure needed.
- **More:** optional, one topic each. More 0 and 1 need Azure.

## Prerequisites

| You need | For | Notes |
|----------|-----|-------|
| A GitHub account with Codespaces, or VS Code with the Dev Containers extension and Docker | All labs | The dev container installs everything else |
| An Azure subscription where you can create resources and assign roles (Owner, or Contributor plus User Access Administrator) | More 0 and 1 | Needs quota for `gpt-5.4-mini` and `gpt-5.4` in your region |
| GitHub Copilot in VS Code, in agent mode | More 0 | Runs the `run-assert-eval` skill |

You do not need an API key for any lab. The live labs sign in with your Azure
identity (`az login`).

## Quickstart

1. Open the repository in a Codespace, or in VS Code with **Dev Containers: Reopen in Container**.
2. Wait for the container setup to finish.
3. Open a terminal. Run every command in this guide from the repository root.

## Core labs

Run the checkup script (`./src/scripts/check-setup.sh`) before going to
[Lab 0](core/lab-0.md).

Work through these in order.

| Lab | What you do | Time |
|-----|-------------|------|
| [Lab 0: Setup](core/lab-0.md) | Check your environment and run the whole loop once | 10 min |
| [Lab 1: Meet DevBot and map the risk](core/lab-1.md) | Watch DevBot misbehave and learn the ACS vocabulary | 10 min |
| [Lab 2: Evaluate with ASSERT](core/lab-2.md) | Capture a baseline and read five deny targets from it | 15 min |
| [Lab 3: Generate and validate an ACS policy](core/lab-3.md) | Generate a policy and prove it blocks every known-bad output | 15 min |
| [Lab 4: Guard, verify, and explore More](core/lab-4.md) | Guard DevBot at runtime and measure attack success drop from 100% to 0% | 10 min |

## More labs

Before the live More labs, after [More 0](more/lab-0-assert-skill.md) Steps 1
and 2:

| Command | Pass when |
|---------|-----------|
| `az account show --query name -o tsv` | It shows the subscription you used for `infra/setup.sh` |
| `python3 -m devbot.agent "How do I see recent commits?"` | DevBot answers from the real model, with no `401` or `403` |

Optional, numbered in a suggested order. Without an Azure subscription, start at
More 2. See the [More labs overview](more/README.md).

| Lab | What you do | Needs Azure |
|-----|-------------|-------------|
| [More 0: Drive the evaluation with the run-assert-eval skill](more/lab-0-assert-skill.md) | Set up Foundry, then let GitHub Copilot run the loop on a real model | Yes |
| [More 1: Go live with a real model](more/lab-1-live-run.md) | Run the same loop by hand with a real model | Yes |
| [More 2: Browse runs in the ASSERT viewer](more/lab-2-viewer.md) | Read and compare runs without writing code | No |
| [More 3: Author custom Rego](more/lab-3-custom-rego.md) | Write and test a rule, including one that redacts instead of blocks | No |
| [More 4: Adaptive red-teaming](more/lab-4-red-teaming.md) | Find an output that slips past the policy and close the gap | No |
| [More 5: Intervention points and tool calls](more/lab-5-intervention-points.md) | Learn what `guard_target` enforces and what a full ACS host adds | No |
| [More 6: Gate CI on the policy](more/lab-6-ci-gate.md) | Fail a build when the policy stops blocking a known-bad class | No |

When you finish More 0 and 1, delete the resource group so it stops costing
money: `az group delete --name rg-lab661-foundry --yes --no-wait`.

## If something goes wrong

See [troubleshooting](../../docs/troubleshooting.md), or ask GitHub Copilot Chat
to help you debug and paste the command and its output.

## Scripts

These scripts are listed for reference. You do not need to run either script now.

| Script | What it does | When it runs |
|--------|--------------|--------------|
| [`.devcontainer/post-create.sh`](../../.devcontainer/post-create.sh) | Checks Python, the Azure CLI, `jq` and `openssl`, installs `opa`, and installs the pinned packages in [`requirements.txt`](../../requirements.txt) | Automatically, when the dev container is created |
| [`infra/setup.sh`](../../infra/setup.sh) | Signs in to Azure, creates a Foundry project with `gpt-5.4-mini` and `gpt-5.4`, sets up Application Insights, and grants you the roles to call the models without a key | By you, in [More 0](more/lab-0-assert-skill.md) Step 1 |
