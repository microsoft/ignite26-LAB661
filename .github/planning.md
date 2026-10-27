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
