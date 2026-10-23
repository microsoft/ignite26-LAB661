# Microsoft Ignite 2026 repository instructions

This repository is a Microsoft Ignite 2026 session template. Use the **Ignite 2026 repository agent** for setup.

## Workflows

There are two workflows:

- `help me initialize repo` — populate README with session content
- `help me finalize repo` — clean up, validate, and prepare for publication

Plus:

- `help me handle issues` — triage and apply safe fixes to open GitHub issues

## Core rules

- Never fabricate session metadata, links, or content.
- Preserve authored content. Do not overwrite non-placeholder sections without confirmation.
- Use sentence case for Markdown headings.
- Use session-owner language. Announce the section being worked on. Do not narrate patches, diagnostics, or editor internals.
- Track answers within a workflow phase. Do not re-ask questions.
- Do not choose runtimes, install packages, scaffold implementation code, or run project test suites.

## Initialize scope

- Fill in README metadata: session code, title, description, learning outcomes (exactly three), technologies, content owners, delivery links.
- Do NOT run scripts, linters, or shell commands.
- Do NOT delete folders.
- Do NOT remove the "Before you're done" section.
- For workshops/labs: attendee path is always both (guided + self-paced). Do not ask.
- For workshops/labs: do not ask a separate live-demo question.

## Finalize scope

- Remove the "Before you're done" section and template markers.
- Confirm which unused folders to remove.
- Verify the repo is ready to publish by running through an inline checklist (placeholders, required README sections, and relative link targets).
- If any fail: report in plain language, propose fixes, ask permission to apply, then re-check.
- Once all pass: remove template-only tooling (`.github/agents/`, `.github/tests/`, `.github/copilot-instructions.md`, `.github/AGENT-WORKFLOW.md`). Remove `.github/` if empty.
- Report the repo as ready to publish.

## Folder purposes

- `instructions/` — attendee step-by-step guidance
- `docs/` — supporting reference material and architecture/context
- `src/`, `data/`, `infra/`, `.devcontainer/` — session-specific technical folders (optional)

Attendee guidance can remain in `docs/` for intentional MkDocs or docs-site patterns when the root README links clearly to the entry point.

## Session code prefixes

Accept: `BRK`, `WRK`, `LAB`, `ILL`, `LTG`, `THR`, `DEM`, `INV`, `PREL`, `PREB` followed by digits.

## Do not

- Do not close GitHub issues automatically.
- Do not delete authored content without confirmation.
- Do not modify validation scripts during normal workflows.
- Do not use language like "publication blocker", "focused Markdown diagnostics", "initialization readiness", or "local hypothesis". Write for a speaker, not a QA engineer.

## LAB661 planning notes (template tooling; removed at finalize)

Planning only until the owner says "GO!". `.DO-NOT-COMMIT/` is gitignored scratch space (it holds `WALKTHROUGH.md`). The source lab (`acs-assert-agent-governance-workshop-main/`) now sits at the repo root, untracked and not ignored, so do not commit it. Read it only when the owner asks.

### Session

- LAB661: Hill climbing for agents: From 60% to 90% with Open Source and Foundry.
- 75 minutes: about 15 minutes speaker time, 60 minutes hands-on lab.
- Attendees: developers and decision makers. Plain, concise, conversational, actionable language.
- Tech: ASSERT, Rubrics, Agent Control Specification (ACS), Microsoft Foundry observability, tracing, evaluation.
- Stack: Python, Codespaces / dev container.
- Foundry access: in-venue Skillable pre-provisions it per attendee. Self-paced adds a self-provisioning step.

### Pedagogy

- Constructionism plus debugging: try something, watch it break, fix it, reach an aha moment.
- Every module ends with a visible win. No click-through steps.
- Core loop: one measured change at a time, starting from an agent that scores about 60%.

### Decided plan (draft v2)

- Source: retrofit the Contoso DevBot ACS + ASSERT workshop from `.DO-NOT-COMMIT/`. Keep DevBot as the starter agent.
- Score: pass rate, the share of cases where a rubric says the agent did the right thing (block unsafe, help on safe). About 60% to 90%.
- Modes: live is the default (real model via Foundry, live ASSERT, live traces). Offline is a per-step fallback that replays recorded live evidence from `data/`. It is not a second set of modules.
- Foundry is for traces only. ASSERT and Rubrics score locally.
- Speaker time: about 7 minutes before the lab (problem and loop), about 8 after (take it back to your own agents).
- Core modules (60 minutes):
  - 0 Baseline, 10 min: review the rubric, run ASSERT live on a short DevBot spec with a small sample, score about 60%.
  - 1 Tighten the prompt, 15 min: edit DevBot's system prompt. Unsafe passes drop but safe requests get refused, so the score barely moves.
  - 2 Debug with traces, 15 min: find the cause in the Foundry traces, scope the rule, reach about 75%.
  - 3 Add a control, 15 min: generate an ACS policy and guard the agent. The first policy over-blocks. Validate, narrow it, reach about 90%, check cost and latency.
  - Wrap-up, 5 min.
- `more/` is take-home, self-paced only, and outside the Skillable manual: adaptive red-teaming, CI gate on the pass rate, cost and latency tuning via traces, deeper Rubrics (including a rubric bug that makes the score lie), ASSERT viewer, and the full ASSERT `run-assert-eval` skill. Custom Rego was dropped.
- Layout: `instructions/` holds written modules. `labs/core` and `labs/more` hold runnable material per module. `src/devbot/` holds the agent. `data/` holds recorded golden runs. `infra/` holds Foundry setup for self-paced. `docs/` holds background.
- Tooling: `assert-ai` 0.3.0 is on PyPI (Python 3.11 or newer). The `acs` extra needs pre-release `acs-generator` (0.3.1b0) and `agent-control-specification` (0.3.1b0 or newer), so pin exact versions in the dev container. `opa` is a separate binary.
- Foundry skill (`microsoft/azure-skills`, `microsoft-foundry`): traces are read from Application Insights with KQL. It documents no upload of traces from a file.
- Pre-install and cache all dependencies (pinned Python packages, `opa`, any ASSERT checkout) in the dev container image or Skillable environment. Attendees must not install or clone anything at lab runtime.
- The live path needs a Foundry project with `gpt-5.4-mini` and `gpt-5.4` deployed before the lab starts. In-venue Skillable pre-provisions it. Self-paced runs a setup script (prototype at `acs-assert-agent-governance-workshop-main/workshop/scripts/setup.sh`, untested against a subscription). The script also creates Log Analytics, Application Insights, a project connection and the RBAC for tracing (untested). DevBot does not emit traces yet.

### Build order (after "GO!")

1. Dev container, pinned dependencies, `infra/`.
2. DevBot agent with live model and tracing, the short spec, and the rubric.
3. Tune the spec and test set so the baseline lands near 60%, then record golden runs (needs live Foundry access).
4. Write the four core modules in `labs/core/` and the matching `instructions/` text.
5. Assemble the Skillable manual with the skill and write the self-paced guide.
6. Build the `more/` labs.
7. Run the final checks.

### Risks and unknowns

- Live runs vary, so instructions give ranges, not exact scores. Hitting about 60, 75 and 90 needs a tuned spec and test set.
- Unverified: ASSERT or DevBot spans reaching the Foundry portal, trace ingestion delay, per-attendee Foundry provisioning in Skillable, whether `opa` is still required with ACS 0.3.x, and offline trace replay (local viewer versus re-emitting spans to App Insights).
- The ACS packages are betas and could change.

### Return to later

- Self-paced scope and provisioning steps.
- Skillable page mapping and the live/offline switch (recommend an expandable hint plus one replay command, not a dropdown).
- Session title and README "Getting started" wording.
- Rubric specifics.
- Confirm `more/` is self-paced only.

### Repo state and structure

- README is already initialized: title, description, three learning outcomes, technologies, owners. No deck URL yet.
- README "Getting started" still has placeholder steps ("Step 1", "Step 2") and links attendee guidance to `docs/README.md`.
- Planned layout is in "Decided plan" above. `src/`, `data/`, `infra/`, `docs/` are still untouched placeholders; `labs/` and `.devcontainer/` do not exist yet.
- Lab path is always guided plus self-paced. Link attendee entry point from the root README (point to `instructions/` rather than `docs/` unless using a docs site).
- README owner `spiderpc` is Mike Shi (alt text fixed to match).
- Finalize removes `.github/` tooling, the "Before you're done" comment block, and unused placeholder folders.

### Attendee instructions layout

- `instructions/self-paced/README.md`: read in VS Code; provisions infra from scratch. Stub only.
- `instructions/skillable/`: numbered module files (`NN-slug.md`) plus `README.md`, the assembled paged manual (`===` page breaks) that the owner copies into Skillable. Maintained by the `update-skillable-instructions` skill in `.github/skills/`.
- Skillable uses one Markdown file per lab profile (pasted into Studio or synced from the default branch). Images go in `instructions/skillable/media/`.

### Final checks (do at finalize)

- Fix root README "Getting started": replace "Step 1", "Step 2" and point both paths at `instructions/self-paced/` and `instructions/skillable/` instead of `docs/README.md`.
- Replace or remove the `instructions/README.md` placeholder so it links to both paths.
- Remove the stub header comment and "none yet" module list from `instructions/skillable/README.md` once modules exist; confirm it matches the modules.
- Add the deck URL to the root README once available.
- Keep `.github/skills/update-skillable-instructions/` at finalize so others can maintain the repo. Finalize removes only `agents/`, `tests/`, `copilot-instructions.md`, and `AGENT-WORKFLOW.md`, so `.github/` stays.
- Remove unused placeholder folders and confirm `.devcontainer/` is added if needed.

