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
- **More:** optional, one topic each. More 0 and 1 need Azure.

## Prerequisites

The lab profile must give every attendee these before the lab starts. Attendees
do not install or clone anything.

| Attendee needs | For | Notes |
|----------------|-----|-------|
| A Windows 11 VM (`Win11-Pro-Base`) with VS Code, this repository, a prebuilt `.venv` and `opa.exe` already on it | All labs | Attendees do not install or clone anything. Image steps are in [README.maintainer.md](../../README.maintainer.md) |
| GitHub Enterprise sign-in through `https://github.com/enterprises/skillable-events/sso`, using the attendee's **Azure** credentials | More 0 | GitHub Copilot works only through this sign-in. The first page walks attendees through it |
| A pre-provisioned Foundry project with `gpt-5.4-mini` and `gpt-5.4` deployed, and `.env` written in offline mode | More 0 and 1 | The [`deploy-foundry.ps1`](lifecycle/deploy-foundry.ps1) lifecycle action deploys `infra/main.bicep` and writes `.env`. More 0 switches it to live |
| `@lab.CloudPortalCredential(User1)` Username, Password and AccessToken | Sign-in, More 0 | Shown on the first page with `+++` type text |

No lab uses an API key. The live labs sign in with the attendee's Azure identity
(`az login`).

## Quickstart

1. Sign in to the VM and open VS Code on the repository.
2. Open a terminal with **Terminal > New Terminal**. It opens in PowerShell, with `.venv` first on PATH.
3. Run every command in this guide from the repository root.

## Core labs

Work through these in order.

| Page file | Skillable pages | Time |
|-----------|-----------------|------|
| [core-0-setup-environment.md](core-0-setup-environment.md) | Sign in to your lab, Get started with LAB661, Check your lab environment, Run the whole loop once | 10 min |
| [core-1-meet-devbot.md](core-1-meet-devbot.md) | Meet DevBot, Learn the ACS vocabulary | 10 min |
| [core-2-evaluate-assert.md](core-2-evaluate-assert.md) | Capture the baseline, Read the findings | 15 min |
| [core-3-generate-policy.md](core-3-generate-policy.md) | Generate the policy, Validate the policy, Try to break the gate | 15 min |
| [core-4-guard-verify.md](core-4-guard-verify.md) | Guard DevBot at runtime, Measure the improvement, Choose a More lab | 10 min |

## More labs

These labs are optional. We recommend following them in the numbered order
below. More 0 starts by connecting to the pre-provisioned Azure resources.
Skillable tears the environment down afterward, so there is no cleanup page.

| Page file | Skillable pages | Needs Azure |
|-----------|-----------------|-------------|
| [more-0-assert-skill.md](more-0-assert-skill.md) | Connect to Microsoft Foundry, Validate your environment, Verify the run-assert-eval skill, Name one risk, Prove the fix | Yes |
| [more-1-live-run.md](more-1-live-run.md) | Go live by hand, Generate a live policy. Optional for anyone who finished More 0 | Yes |
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
order, and core comes before More. After you add, remove or edit a page, run:

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

## Scripts

These scripts are listed for reference. Attendees run the first three from the
lab pages.

| Script | What it does | When it runs |
|--------|--------------|--------------|
| [`scripts/check-setup.ps1`](scripts/check-setup.ps1) | Checks `.venv`, Python, ASSERT, ACS, OPA, Node and DevBot | Core 0 |
| [`scripts/run-offline-loop.ps1`](scripts/run-offline-loop.ps1) | Runs the five offline stages end to end | Core 0 |
| [`scripts/load-env.ps1`](scripts/load-env.ps1) | Loads `.env` into the terminal. With `-Live`, first switches `.env` to live mode | More 0 and 1 |
| [`lifecycle/deploy-foundry.ps1`](lifecycle/deploy-foundry.ps1) | Deploys `infra/main.bicep` with the subscription's service principal, writes `.env` in offline mode, and reports progress in `LAB661-Foundry-status.txt` on the desktop | Skillable lifecycle action, at First Displayable, not blocking |
