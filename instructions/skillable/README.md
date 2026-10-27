# LAB661 Skillable manual

The in-venue version of LAB661. Attendees follow a paged manual inside a
Skillable lab, with the environment prepared for them. They secure Contoso
DevBot, a deliberately under-governed coding agent, with a policy generated from
evidence of its own misbehavior. ASSERT finds what DevBot does wrong. Agent
Control Specification (ACS) blocks it at runtime.

This manual has the same labs as the [self-paced guide](../self-paced/README.md),
rewritten as short Skillable pages with checkboxes and copy text. Each page file
below holds one lab, split into Skillable pages by `===`.

- **Core:** about 60 minutes, offline, no Azure needed.
- **MORE:** optional, one topic each. MORE 0 and 1 need Azure.

## Prerequisites

The lab profile must give every attendee these before the lab starts. Attendees
do not install or clone anything.

| Attendee needs | For | Notes |
|----------------|-----|-------|
| VS Code or a Codespace with this repository open in its dev container | All labs | The dev container installs everything else |
| An Azure subscription where they can create resources and assign roles | MORE 0 and 1 | Needs quota for `gpt-5.4-mini` and `gpt-5.4` |
| GitHub Copilot in VS Code, in agent mode | MORE 0 | Runs the `run-assert-eval` skill |

No lab uses an API key. The live labs sign in with the attendee's Azure identity
(`az login`).

## Setup

| Script | What it does | When it runs |
|--------|--------------|--------------|
| [`.devcontainer/post-create.sh`](../../.devcontainer/post-create.sh) | Checks Python, the Azure CLI, `jq` and `openssl`, installs `opa`, and installs the pinned packages in [`requirements.txt`](../../requirements.txt) | Automatically, when the dev container is created |
| [`infra/setup.sh`](../../infra/setup.sh) | Signs in to Azure, creates a Foundry project with `gpt-5.4-mini` and `gpt-5.4`, sets up Application Insights, and grants the roles to call the models without a key | By the attendee, on the first MORE 0 page |

## Validate your setup

The first core page has attendees run these.

| Command | Pass when |
|---------|-----------|
| `./src/scripts/check-setup.sh` | Every line starts with `ok` |
| `./src/scripts/run-offline-loop.sh` | It ends with the `PASS` line and attack success drops from 100% to 0% |

The MORE 0 configure page has attendees confirm the live setup.

| Command | Pass when |
|---------|-----------|
| `python3 -m devbot.agent "How do I see recent commits?"` | DevBot answers from the real model, with no `401` or `403` |

## Core labs

| Page file | Skillable pages | Time |
|-----------|-----------------|------|
| [core-0-setup-environment.md](core-0-setup-environment.md) | Get started with LAB661, Check your lab environment, Run the whole loop once | 10 min |
| [core-1-meet-devbot.md](core-1-meet-devbot.md) | Meet DevBot, Learn the ACS vocabulary | 10 min |
| [core-2-evaluate-assert.md](core-2-evaluate-assert.md) | Capture the baseline, Read the findings | 15 min |
| [core-3-generate-policy.md](core-3-generate-policy.md) | Generate the policy, Validate the policy, Try to break the gate | 15 min |
| [core-4-guard-verify.md](core-4-guard-verify.md) | Guard DevBot at runtime, Measure the improvement, Choose a MORE lab | 10 min |

## MORE labs

| Page file | Skillable pages | Needs Azure |
|-----------|-----------------|-------------|
| [more-0-assert-skill.md](more-0-assert-skill.md) | Set up Microsoft Foundry, Configure your environment, Meet the run-assert-eval skill, Name one risk, Prove the fix | Yes |
| [more-1-live-run.md](more-1-live-run.md) | Go live by hand, Generate a live policy, Clean up Azure | Yes |
| [more-2-viewer.md](more-2-viewer.md) | Browse runs in the ASSERT viewer | No |
| [more-3-custom-rego.md](more-3-custom-rego.md) | Author custom Rego | No |
| [more-4-red-teaming.md](more-4-red-teaming.md) | Adaptive red-teaming, Close the gap | No |
| [more-5-intervention-points.md](more-5-intervention-points.md) | Intervention points | No |
| [more-6-ci-gate.md](more-6-ci-gate.md) | Gate CI on the policy, Read the workflow | No |

## If something goes wrong

Attendees raise a hand for a proctor. Proctors can use
[troubleshooting](../../docs/troubleshooting.md).

## Maintainer notes

### Syntax

Write every page in Skillable Markdown. The reference is
[Creating instructions with Markdown syntax](https://docs.skillable.com/docs/creating-instructions-with-markdown-syntax).
GitHub does not render Skillable-only syntax such as `>[!Knowledge]`, `1. []`
checkboxes or `++copy text++`, so check the result in Skillable Studio.

Conventions used here:

- Start each Skillable page with a `# ` heading of 40 characters or fewer. It labels the **Next** button.
- Use `1. []` for steps the attendee performs, and `++text++` for commands to copy.
- Put fixes and answers in `>[+Hint]` blocks, never in the step itself.
- End every page with a `>[!Note] **Success:**` line that states the visible result.
- Use `-nocopy` on code blocks that show expected output.

### Build the manual

Page files are named `core-N-slug.md` and `more-N-slug.md`. The number sets the
order, and core comes before MORE. After you add, remove or edit a page, run:

```bash
./instructions/skillable/generate-skillable-copy.sh
```

It writes [skillable-copy.md](skillable-copy.md), every page joined by `===`.
Paste that whole file into the lab profile (**Edit Instructions**).

To have Skillable pull each page live from GitHub instead, run with
`MODE=include`. It writes one `[!include]` line per page. This needs a public
repository, and you can set `REPO` and `BRANCH` to choose the source.

```bash
MODE=include BRANCH=main ./instructions/skillable/generate-skillable-copy.sh
```
