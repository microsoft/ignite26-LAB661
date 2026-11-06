# LAB661 planning notes

Working notes for the owners. Not attendee content. Remove or move before
publishing.

## Current decision: validate in GitHub Codespaces

- The owner validates the labs in a GitHub Codespace (the Linux dev container,
  bash) signed in to the Skillable Azure subscription.
- The Skillable pages in `instructions/skillable/` use bash commands. They are
  correct for a Codespace and for the self-paced path.
- Watch for during validation:
  - `az login` to the Skillable tenant from a Codespace (device code flow).
  - `infra/setup.sh` needs Owner, or Contributor plus User Access
    Administrator, to create role assignments. Skillable subscriptions are often
    restricted, so the **Cognitive Services OpenAI User** assignment may fail. If
    it does, the lab profile must grant that role to each attendee up front.
  - Model quota for `gpt-5.4-mini` and `gpt-5.4` in the chosen region.

## Future step: Skillable on the Windows 11 VM

The Skillable VM runs Windows 11 with VS Code installed. If attendees run the lab
locally in VS Code on the VM, from a PowerShell terminal, instead of in a
Codespace, the following is needed.

### Lab image prerequisites

Attendees cannot install anything during the lab, so the Skillable image must
include all of the following. Confirm each with the Skillable team.

- Python 3.11 or newer on `PATH` as `python` (the `python3` name is not standard on Windows).
- The pinned packages from `requirements.txt`, including the pre-release ACS packages.
- `opa.exe` v0.70.0 on `PATH`, verified against its published checksum.
- Azure CLI.
- A clone of this repository at a known path, opened in VS Code.
- GitHub Copilot in VS Code, signed in, for More 0.
- For More 0 and 1: an Azure subscription per attendee, and either rights to
  create role assignments or **Cognitive Services OpenAI User** granted up front.

### Scripts to port to PowerShell

Put these in `instructions/skillable/scripts/`. Keep the bash originals as the
source of truth for the self-paced path and CI.

| Bash original | PowerShell version | Notes |
|---------------|--------------------|-------|
| `src/scripts/check-setup.sh` | `check-setup.ps1` | Same checks and the same `ok` / `MISS` lines, so the expected output in the pages stays the same |
| `src/scripts/run-offline-loop.sh` | `run-offline-loop.ps1` | Set `$env:PYTHONPATH`, stop on the first non-zero `$LASTEXITCODE` |
| `infra/setup.sh` | `setup.ps1` | Largest port. Uses `az`, `jq`, `openssl` and `mapfile`. Replace `jq` with `ConvertTo-Json`, and `openssl rand` with `Get-Random`. Only needed if More 0 and 1 run on the VM |
| `set -a; source .env; set +a` | `load-env.ps1` | Read `.env` lines into `$env:` variables |

### Command translations for the Skillable pages

| Bash | PowerShell |
|------|------------|
| `PYTHONPATH=src python3 x.py` | `$env:PYTHONPATH = "src"; python x.py` |
| `./src/scripts/check-setup.sh` | `.\instructions\skillable\scripts\check-setup.ps1` |
| `head -1 file \| python3 -m json.tool` | `Get-Content file -TotalCount 1 \| python -m json.tool` |
| `cat file` | `Get-Content file` |
| `cp .env.example .env` | `Copy-Item .env.example .env` |
| `"$(pwd)/data/results"` | `"$PWD\data\results"` |
| `echo "exit: $?"` | `"exit: $LASTEXITCODE"` |
| `echo '{...}' \| opa eval -I ...` | Use a here-string or a `.json` file. PowerShell quoting breaks the inline JSON in More 3 and 4 |
| Multi-line `\` continuation | Backtick continuation, or keep each command on one line |

### Other Windows checks

- Python writes JSONL with UTF-8 and the platform newline. Confirm the baseline
  rebuild on Windows produces the same 14 cases and 10 violations.
- The console must handle the `·` and box characters some scripts print. Set
  `$env:PYTHONIOENCODING = "utf-8"` if output is garbled.
- Execution policy may block `.ps1` files. The pages should run scripts with
  `powershell -ExecutionPolicy Bypass -File <script>`, or the image should set
  the policy to `RemoteSigned`.
- PowerShell is not available in the dev container, so the `.ps1` scripts can
  only be tested on the VM.

### Decisions to make

- Decided (2026-10-27): attendees use a local clone on the VM and run every command in plain PowerShell. Next: validate and pre-install the Python and Node dependencies on the image, port the scripts, and switch the Skillable pages to PowerShell commands.

### Original Skillable profile instructions (kept for reference)

The lab profile's starting instructions, before `skillable-copy.md` replaced
them. The VM sign-in, credential tokens, and GHE sign-in steps now live on the
"Sign in to your lab" page in `instructions/skillable/core-0-setup-environment.md`.

````markdown
## Welcome to Your Lab Environment

To begin, log into the virtual machine using the following credentials: +++@lab.VirtualMachine(Win11-Pro-Base).Password+++

Your Azure subscription details are:
- Username: +++@lab.CloudPortalCredential(User1).Username+++
- Password: +++@lab.CloudPortalCredential(User1).Password+++
- TAP: +++@lab.CloudPortalCredential(User1).AccessToken+++

**Note:** Text formatted as an +++example+++ represents type text. Clicking on this text will automatically insert it to prevent any typing errors.

To edit the lab manual, click the hamburger menu in the top-right corner and select **"Edit Instructions"**. This will open the editor where you can modify the instructions.

Instructions are written in Markdown. For detailed guidance on syntax, please refer to the following documentation:

[Creating Instructions with Markdown Syntax](https://docs.skillable.com/docs/creating-instructions-with-markdown-syntax)

If you want to manage your instructions outside of Skillable Studio like Github, please refer to the following documentation:

[Manage Instructions Outside of Studio](https://docs.skillable.com/docs/manage-instructions-outside-of-studio)

For saving changes made to the virtual machine, please refer to this guide:

[Committing Changes to a Virtual Machine](https://docs.skillable.com/docs/committing-changes-to-a-lab)

**Note:** When prompted, select **"Commit my changes and update this lab profile"** to ensure your changes are saved.

Changes made to the virtual machine will take effect immediately after committing. You may restart the lab instance if you wish to view these changes.

**Note:** Changes to the instructions will be saved automatically, so the commit process applies only to modifications to the virtual machine.

Should you require any assistance, feel free to contact us.

**Please remove this message once it is no longer needed.**

===

a. login at +++https://github.com/enterprises/skillable-events/sso+++  with Azure slice (GHE activated) credentials

b. keep login page from SSO portal above open in browser, open VS Code

c. select Continue with Github login option in VS Code
!IMAGE[e4hal04w.png](instructions359309/e4hal04w.png)

d. authenticate profile through SSO portal and GHE is now active in their VS Code instance
````
- Codespace from the VM (no port needed) or local Windows (this section)?
- If local Windows: do More 0 and 1 run on the VM, which needs the `setup.ps1`
  port, or stay self-paced only?
- One set of Skillable pages per platform, or a Skillable section switch
  (`:::name(variable=value)`) that shows bash or PowerShell commands?

## Skillable readiness

Status as of 2026-10-30. Written so work can resume without the chat history.
Full command log: [`CHANGES.md`](../CHANGES.md). Owner checklist by phase:
[`README.maintainer.md`](../README.maintainer.md). Remove all three files before
publishing.

### Decisions made

- Attendees run the lab locally on the Skillable Windows 11 VM in PowerShell,
  not in a Codespace or WSL. The open questions in the section above are
  answered: local Windows, one set of Skillable pages (PowerShell only, no
  section switch), and More 0 and 1 will run on the VM (Phase B).
- The self-paced path is unchanged: dev container, bash scripts in
  `src/scripts/` and `infra/setup.sh`, CI, and `instructions/self-paced/`. Bash
  stays the source of truth. Skillable gets its own Windows pieces.
- Skillable pattern: a lifecycle action provisions Foundry and writes `.env`
  before the attendee reaches More 0; prebuilt `.venv`; nothing installed
  during the lab. Every image change is redone on the Skillable VM.
- The LAB661 core is offline, so the Foundry lifecycle action must not block the
  lab or end it on failure.
- Deferred by the owner: the Copilot and GitHub sign-in content in the
  Skillable manual (Core 0 "Sign in to your lab"). A lifecycle action plus a
  desktop status file could replace the manual GitHub Enterprise SSO steps.
  Look into this later; do not change those pages yet.

### VM changes (redo on any new image)

| Change | Where | Command or method |
|--------|-------|-------------------|
| Python virtual environment, Python 3.12.10 (the VM default is 3.15, which the pinned packages were not tested on; 3.12 was already installed) | `C:\Users\LabUser\Desktop\LAB661\.venv` | `py -3.12 -m venv .venv` then `.\.venv\Scripts\python.exe -m pip install --upgrade pip` |
| All pinned packages | `.venv` | `.\.venv\Scripts\python.exe -m pip install --find-links "$env:USERPROFILE\lab661-wheelhouse" -r requirements.txt` |
| ACS Windows wheel, self-built (PyPI has only a Linux wheel for `agent-control-specification==0.3.1b1`; it is a Rust extension) | `C:\Users\LabUser\lab661-wheelhouse\agent_control_specification-0.3.1b1-cp311-abi3-win_amd64.whl`, 2,788,316 bytes, SHA-256 `51a213a4e19b8e14a40d9e77b8aa3ec3f8dbb7da5dee9565f85832cce6af6074`. Also uploaded to the upstream GitHub repository | Built once with Rust plus VS 2022 Build Tools: `pip wheel --no-deps "agent-control-specification==0.3.1b1" -w "$env:USERPROFILE\lab661-wheelhouse"`. **Keep this folder on the image** |
| OPA v0.70.0, SHA-256 `19d00eea60477a8f983c20af690fedcc8da52aef81922e570b27538ca88305a4` | `%LOCALAPPDATA%\Programs\OpenPolicyAgent\opa.exe`, added to the **user** PATH | Download `https://openpolicyagent.org/downloads/v0.70.0/opa_windows_amd64.exe`, verify against its `.sha256`, append the folder to the user PATH. Restart VS Code afterwards: its terminals keep the PATH from when VS Code started |
| Build toolchain, installed then **removed** | Rust (`rustup`, user), VS 2022 Build Tools with the VC tools workload, Windows 11 SDK | Removed: `rustup self uninstall -y`; Build Tools, then the Visual Studio Installer, then the Windows SDK in **Settings > Apps > Installed apps**. A silent `setup.exe uninstall --quiet` from a non-elevated terminal does nothing. Kept: Visual C++ 2015-2022 redistributables, and a harmless "Windows SDK AddOn" entry |
| Cleanup | `%TEMP%`, pip cache, repo | Deleted the installers, source download and pip cache (202 MB); deleted `artifacts/`; confirmed no `.env` |
| Already on the VM, unchanged | | PowerShell 7.5 (and 5.1), Node, Azure CLI, Git for Windows (Git Bash at `C:\Program Files\Git\bin\bash.exe`), VS Code 1.135 with no extensions, execution policy `Unrestricted` (LocalMachine) |

### Repository changes (replay upstream)

- `.gitattributes` (new): LF for `*.sh`, `*.jsonl`, `*.rego`; CRLF for `*.ps1`.
  Git on the VM has `core.autocrlf=true`.
- `.gitignore`: ignores `.venv/`.
- `.vscode/settings.json` (new): `terminal.integrated.env.windows` puts
  `${workspaceFolder}\.venv\Scripts` first on PATH and sets `VIRTUAL_ENV`, so
  `python` and `assert-ai` resolve to `.venv` in every new VS Code terminal on
  Windows. The dev container ignores `.windows` keys. Needs a trusted folder.
- `src/eval/build_baseline_fixture.py`: `_write_jsonl` uses `newline="\n"`, so
  a Windows rebuild keeps the committed baseline byte-for-byte
  (`inference_set.jsonl` `4EA57AC1…C010D`, `scores.jsonl` `F74578D0…72162`).
- `instructions/skillable/scripts/check-setup.ps1` and `run-offline-loop.ps1`
  (new): ports of the bash scripts with the same `ok`/`MISS` and stage lines,
  plus checks for `.venv` and `python on PATH is .venv`. Work in PowerShell 7
  and 5.1, from any folder, without changing the caller's folder.
- Skillable pages converted to PowerShell, every command run on the VM and its
  output checked: Core 0 ("Check your lab environment", "Run the whole loop
  once"), Core 1 to 4, More 2 to 6. Not converted: Core 0 "Sign in to your lab"
  (deferred) and More 0 and 1 (Phase B).
- `instructions/skillable/skillable-copy.md` regenerated with
  `& 'C:\Program Files\Git\bin\bash.exe' -c "cd '/c/Users/LabUser/Desktop/LAB661' && ./instructions/skillable/generate-skillable-copy.sh"`.
- `CHANGES.md` and `README.maintainer.md` (new, maintainer-only).

Command translations used in the pages:

| Bash | PowerShell |
|------|------------|
| `PYTHONPATH=src python3 x.py` | `$env:PYTHONPATH = "src"; python x.py` |
| `./src/scripts/check-setup.sh` | `.\instructions\skillable\scripts\check-setup.ps1` |
| `./src/scripts/run-offline-loop.sh` | `.\instructions\skillable\scripts\run-offline-loop.ps1` |
| `head -1 f \| python3 -m json.tool` | `Get-Content f -TotalCount 1 \| python -m json.tool` |
| `cat f` | `Get-Content f` |
| `echo '{...}' \| opa eval ...` | `'{...}' \| opa eval ...` |
| `"$(pwd)/data/results"` | `"$PWD\data\results"` |
| `; echo "exit: $?"` | `; "exit: $LASTEXITCODE"` |
| `mkdir -p d`, `cp f d/` | `New-Item -ItemType Directory -Force d \| Out-Null`, `Copy-Item f d/` |
| `cat >> f <<'EOF' ... EOF` | `Add-Content f @' ... '@` |
| `grep -n -E "re" f` | `Select-String -Path f -Pattern 're'` |
| Multi-line `\` command | One line |

### Validation done

In a new VS Code terminal after a VS Code restart, and again after the build
tools were removed:

- `check-setup.ps1`: every line `ok`.
- `run-offline-loop.ps1`: validation `strongly blocked 5/5`, guard demo `PASS`,
  attack success `10/10 (100%)` to `0/10 (0%)`, benign `3/3`, exit 0. Same in
  Windows PowerShell 5.1.
- Core 3 "Try to break the gate" and More 6: `3/5` and exit 1 without the
  `secret_disclosure` rule, then `5/5` and exit 0 after restoring.
- More 3: `transform`, `allow`; `allow` before the edit; `deny`, `transform`,
  `allow` after. More 4: `deny`, `allow`, then `deny`, `deny` and `5/5`. More 5:
  manifest shows `pre_tool_call:` and `output:`, probe `deny`, guard shows only
  `INPUT` and `OUTPUT`.

### Remaining steps

**Finish Phase A (owner)**

1. Commit the VM image in Skillable (**Commit my changes and update this lab
   profile**) with VS Code open on the trusted `LAB661` folder. If any lab
   command runs first, delete `artifacts/` again.
2. Replay the repository changes above upstream.
3. Ask the ACS maintainers to publish a `win_amd64` wheel.
4. Update `instructions/skillable/README.md` (maintainer-facing): its
   Prerequisites, Quickstart and Scripts tables still describe a Codespace and
   the bash scripts.
5. Update [`AGENTS.md`](../AGENTS.md) and the `update-skillable-instructions`
   skill: Skillable pages are PowerShell, self-paced pages are bash, and a
   command change must be made and tested in both.
6. Decide whether the image should use Python 3.13 to match the dev container
   (3.12 is tested).

**Phase B: Foundry for Skillable** (done, not yet run on the VM)

- `infra/main.bicep`: Foundry account and project, the two model deployments,
  Log Analytics, Application Insights and its project connection, and roles
  including **Cognitive Services OpenAI User**. Self-paced `infra/setup.sh`
  deploys it and passed live. `.env` keeps `DEVBOT_MODE=offline` on Skillable.
- More 0 and 1 are PowerShell pages that load `.env` with
  `instructions/skillable/scripts/load-env.ps1 -Live`.
- Owner: confirm GlobalStandard quota at pool scale (500 for `gpt-5.4-mini`,
  100 for `gpt-5.4`), and install Bicep for the lab user (`az bicep install`).

**Phase C: lifecycle actions**

- `instructions/skillable/lifecycle/deploy-foundry.ps1`: VM action at First
  Displayable, not blocking. Writes `.env` and a desktop status file.
- Owner: add Log Analytics Reader to Assign Roles and Tear Down Roles, add the
  deploy action, untick australiacentral and westus2.

**Phase D: rehearse** two fresh instances as an attendee.

**At finalize:** remove `CHANGES.md`, `README.maintainer.md` and this file.
