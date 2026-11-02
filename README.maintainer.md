# LAB661 maintainer guide: Windows 11 Skillable port

Owner actions for running LAB661 on the Skillable Windows 11 VM in PowerShell,
in the order you do them. Every file and VM change is logged in
[CHANGES.md](CHANGES.md) so you can replay it upstream and on the image.

This file is for maintainers. Remove it, or move it somewhere private, before
publishing.

## The approach

- **Self-paced stays as it is.** The dev container, the bash scripts
  (`src/scripts/*.sh`, `infra/setup.sh`), CI and `instructions/self-paced/`
  are unchanged. Bash stays the source of truth.
- **Skillable gets its own Windows pieces**, following LAB663's pattern. LAB663
  and LAB661 run on separate VMs, so every image change is redone here.
  - PowerShell versions of the attendee scripts in
    `instructions/skillable/scripts/`.
  - A prebuilt `.venv` in the repository root and `opa.exe` on the image.
    Attendees install nothing.
  - Later, Skillable lifecycle actions that deploy Foundry and write `.env`
    before the attendee arrives (modelled on LAB663's `skillable_lifecycles/`).
- **The core lab is offline.** Foundry only matters for More 0 and 1, so a
  Foundry setup failure must not block the core lab.

## Status

| Phase | What | State |
|-------|------|-------|
| A | VM image and offline core on Windows | Done on this VM. Waiting on your checks below |
| B | Foundry deployment for Skillable (Bicep + PowerShell), then More 0 and 1 pages | Not started |
| C | Skillable lifecycle actions | Not started |
| D | Full rehearsal on a fresh Skillable instance | Not started |

## Phase A: VM image and the offline core

Done on this VM (details and exact commands in [CHANGES.md](CHANGES.md)):

- `.venv` in the repository root with Python 3.12 and every pinned package.
  `agent-control-specification` has no Windows wheel on PyPI, so we built one
  from source and installed it.
- `opa.exe` v0.70.0 for the user, checked against its SHA-256.
- `.gitattributes` and an LF fix in `build_baseline_fixture.py`. A Windows
  rebuild leaves the committed baseline byte-for-byte unchanged.
- `instructions/skillable/scripts/check-setup.ps1` and `run-offline-loop.ps1`.
  Both pass in PowerShell 7 and Windows PowerShell 5.1, and the loop ends with
  attack success 100% to 0%.
- `.vscode/settings.json` puts `.venv` first on PATH in VS Code terminals on
  Windows only.
- Skillable pages Core 0 to 4 and More 2 to 6 converted to PowerShell, every
  command run on this VM. `skillable-copy.md` regenerated. Not changed: the
  sign-in page (see [Deferred](#deferred)) and More 0 and 1 (Phase B).

### Your actions now

1. ~~**Check a fresh VS Code terminal picks up `.venv`.**~~ Done 2026-10-30:
   after a VS Code restart, `check-setup.ps1`, `run-offline-loop.ps1` and two
   page commands all pass in a new terminal.
2. ~~**Save the ACS wheel somewhere outside the VM.**~~ Done: uploaded to the
   upstream GitHub repository. The local copy stays in
   `%USERPROFILE%\lab661-wheelhouse` on the image. **Do not delete that
   folder.** To rebuild `.venv` without any toolchains:

   ```powershell
   .\.venv\Scripts\python.exe -m pip install --find-links "$env:USERPROFILE\lab661-wheelhouse" -r requirements.txt
   ```
3. **Ask the ACS maintainers for a `win_amd64` wheel.** Until they publish one,
   every image depends on our self-built wheel.
4. ~~**Uninstall the build tools**~~ Done 2026-10-30: Rust, Build Tools, the
   Visual Studio Installer and the Windows SDK removed. The lab still passes.

### Before you commit the VM image

Do these right before **Commit my changes and update this lab profile**, so
attendees start from a clean checkout.

1. ~~Delete generated lab output~~ and ~~check there is no `.env`~~: done
   2026-10-30. If you run any lab command again before committing, rerun
   `Remove-Item -Recurse -Force artifacts`, because More 3's copy would
   otherwise already hold the `DROP TABLE` rule and Core 3 would show a policy
   the attendee hasn't generated yet.
2. Make sure there is no `.env` in the repository root (Phase C writes it per
   attendee).
3. Leave VS Code open on the `LAB661` folder, with the folder trusted.
4. Close VS Code and reopen it once, so its terminals inherit the user PATH
   that includes `opa`.

### Your actions at the end of Phase A

1. Replay the **Repo** entries in [CHANGES.md](CHANGES.md) upstream.
2. Update `instructions/skillable/README.md` (maintainer-facing). Its
   Prerequisites, Quickstart and Scripts tables still describe a Codespace and
   the bash scripts. Copilot can do this once you confirm the approach.

## Phase B: Foundry deployment for Skillable

Copilot will write a cut-down copy of LAB663's Bicep and PowerShell deployment:
a Foundry account and project, `gpt-5.4-mini` (500) and `gpt-5.4` (100), Log
Analytics, Application Insights, the tracing connection and roles, including
**Cognitive Services OpenAI User**, which DevBot and ASSERT need for keyless
calls. `infra/setup.sh` stays for self-paced. Copilot will then convert More 0
and 1 to PowerShell and test them against the real deployment. More 0 also has a
note about where ASSERT saves runs (`~/.local/lib/python3.13/...`) that needs
the Windows path.

Your actions:

1. Confirm GlobalStandard quota per attendee subscription in the chosen region
   (LAB663 uses `eastus2`): 500 for `gpt-5.4-mini` and 100 for `gpt-5.4`.
2. Install Bicep on the image for the lab VM user (LAB663 needs the same).
3. Sign in to the Skillable subscription on this VM so Copilot can rehearse the
   deployment with your identity before any lifecycle action exists.

## Phase C: Skillable lifecycle actions

Copilot will adapt LAB663's actions 01, 02, 04 and 06 (renamed to `Lab661`, and
with Cognitive Services OpenAI User added to 02 and 04), and write LAB661
versions of 03 (deploy, write `.env`, desktop status file) and 05 (teardown).
Unlike LAB663, the Foundry part of 03 should not block the lab, so attendees can
start the offline core while it deploys.

Your actions:

1. Export the current LAB661 lab profile's lifecycle actions, so we know what
   they replace.
2. Ask the tenant admin for the custom variables and the directory app secret
   LAB663 uses (attendee and setup-account object IDs, GitHub group and sync
   IDs). Confirm whether LAB661 runs in the same tenant and can reuse them.
3. Paste the actions into Skillable Studio and disable the originals they
   replace.

## Phase D: Rehearse

Start a fresh instance and work through it as an attendee, then tear it down.
Use LAB663's "Rehearse before opening the lab" list in its
`skillable_lifecycles/README.md` as the checklist.

## Deferred

- **Copilot and GitHub sign-in in the Skillable manual.** The current pages
  walk attendees through the GitHub Enterprise SSO sign-in by hand. LAB663
  replaces this with a lifecycle action (its action 01) plus a status-file
  check. Look into this later. Until then, the Copilot and GitHub sign-in
  content in `instructions/skillable/` is left unchanged.
- **Windows Python version.** We used the Python 3.12 already on the VM. The
  dev container uses 3.13. Decide whether the image should match.
