# Windows 11 Skillable port: change log

Every change made on the LAB661 Skillable VM (`C:\Users\LabUser\Desktop\LAB661`)
while porting the lab to run locally on Windows 11 in PowerShell. Replay these in
the upstream GitHub repository and on the Skillable VM image.

Two kinds of change are listed:

- **Repo:** a file change to commit upstream.
- **VM:** a change to the Windows VM image. It is not in git, so redo it when you
  build or update the image.

## 2026-10-30

### VM: create the Python virtual environment

Python 3.15 (the default `python`) and Python 3.12 (python.org installer, under
`%LOCALAPPDATA%\Programs\Python\Python312`) were already on the VM. ASSERT needs
3.11 or newer. We used 3.12 rather than the default 3.15, because 3.15 is newer
than anything the pinned packages were tested on.

```powershell
cd C:\Users\LabUser\Desktop\LAB661
py -3.12 -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
```

Result: `Python 3.12.10`, `pip 26.2.2`.

### Repo: ignore the virtual environment

`.gitignore` now ignores `.venv/`, next to `.DO-NOT-COMMIT/`.

### VM: install the Python packages

`pip install -r requirements.txt` fails on Windows. `agent-control-specification`
publishes only a Linux wheel (`cp311-abi3-manylinux_2_28_x86_64`). On Windows pip
falls back to the source package, which is a Rust extension built with maturin, and
the build stops with "Cargo, the Rust package manager, is not installed".

Every other package has a Windows wheel. Install them without ACS:

```powershell
.\.venv\Scripts\python.exe -m pip install "assert-ai[azure-auth]==0.3.0" "litellm[proxy]==1.106.4"
.\.venv\Scripts\python.exe -m pip install --no-deps "acs-generator==0.3.1b0"
```

`acs-generator` is pure Python and depends only on `jsonschema` and `pyyaml`, which
the first command already installs.

**Resolved below:** `agent-control-specification==0.3.1b1` is installed from a
self-built Windows wheel. See "VM: build and install the ACS Windows wheel".

### VM: install OPA

OPA v0.70.0, the same version the dev container installs, checked against its
published SHA-256. Installed for the current user, because the terminal was not
elevated.

```powershell
$v = 'v0.70.0'
$dir = Join-Path $env:LOCALAPPDATA 'Programs\OpenPolicyAgent'
New-Item -ItemType Directory -Force $dir | Out-Null
$url = "https://openpolicyagent.org/downloads/$v/opa_windows_amd64.exe"
$exe = Join-Path $dir 'opa.exe'
$sha = Join-Path $env:TEMP 'opa.sha256'
Invoke-WebRequest $url -OutFile $exe
Invoke-WebRequest "$url.sha256" -OutFile $sha
$expected = ((Get-Content $sha -Raw).Trim() -split '\s+')[0].ToLower()
$actual = (Get-FileHash $exe -Algorithm SHA256).Hash.ToLower()
if ($expected -ne $actual) { Remove-Item $exe; throw 'checksum mismatch' }

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (($userPath -split ';') -notcontains $dir) {
    [Environment]::SetEnvironmentVariable('Path', ($userPath.TrimEnd(';') + ';' + $dir), 'User')
}
```

Result: `opa version` prints `Version: 0.70.0`. SHA-256
`19d00eea60477a8f983c20af690fedcc8da52aef81922e570b27538ca88305a4`. Open a new
terminal to pick up the PATH change.

### Repo: keep LF line endings

Git on the VM has `core.autocrlf=true`, so a Windows clone would check out the
bash scripts with CRLF and break them in the dev container if committed back.

- New `.gitattributes`: `* text=auto`, LF for `*.sh`, `*.jsonl` and `*.rego`,
  CRLF for `*.ps1`.
- `src/eval/build_baseline_fixture.py`: `_write_jsonl` opens the file with
  `newline="\n"`. Without it, a rebuild on Windows rewrites the committed baseline
  with CRLF.

Verified: after a rebuild on Windows, both baseline files keep their committed
SHA-256 (`inference_set.jsonl` `4EA57AC1…C010D`, `scores.jsonl` `F74578D0…72162`).

### Repo: PowerShell versions of the attendee scripts

New folder `instructions/skillable/scripts/`, for the Skillable VM only. The bash
originals in `src/scripts/` stay the source of truth.

- `check-setup.ps1`: the same checks and `ok`/`MISS` lines as `check-setup.sh`,
  plus a check for `.venv`. Uses `.venv\Scripts\python.exe` when it exists.
- `run-offline-loop.ps1`: the same five stages as `run-offline-loop.sh`. Sets
  `PYTHONPATH` for the run and restores it after, and stops on the first failing
  step.

Both run in PowerShell 7 and Windows PowerShell 5.1. Two 5.1 details are handled
in the scripts: native stderr under `$ErrorActionPreference = 'Stop'` becomes a
terminating error, and double quotes inside `python -c` code get mangled.

Tested before the ACS wheel existed: `check-setup.ps1` passed every check except
`agent-control-specification`, and `run-offline-loop.ps1` passed stage 1. Final
results are under "Validation on Windows" below.

### VM: build tools for the ACS wheel

Rust, minimal stable toolchain, for the current user, without changing PATH:

```powershell
$ri = Join-Path $env:TEMP 'rustup-init.exe'
Invoke-WebRequest 'https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe' -OutFile $ri
& $ri -y --profile minimal --default-toolchain stable --no-modify-path
```

Result: `cargo 1.99.1`.

The Visual Studio 2022 Build Tools installer, downloaded and its Microsoft
signature checked. Installing it needs admin, so the owner runs it (see
[README.maintainer.md](README.maintainer.md)):

```powershell
Invoke-WebRequest 'https://aka.ms/vs/17/release/vs_BuildTools.exe' -OutFile "$env:TEMP\vs_BuildTools.exe"
# In an elevated PowerShell:
Start-Process "$env:TEMP\vs_BuildTools.exe" -Wait -ArgumentList '--quiet', '--wait', '--norestart', '--nocache', '--add', 'Microsoft.VisualStudio.Workload.VCTools', '--includeRecommended'
```

### Repo: maintainer guide and this log

- `README.maintainer.md`: owner actions by phase. Remove before publishing.
- `CHANGES.md`: this file. Remove before publishing.

### VM: build and install the ACS Windows wheel

The owner installed Build Tools 2022 (17.14.37827.9, `isComplete: True`, no
reboot needed, empty error log). Then, in a normal terminal, with Rust on PATH
for that session only:

```powershell
$env:Path = "$env:USERPROFILE\.cargo\bin;$env:Path"
New-Item -ItemType Directory -Force "$env:USERPROFILE\lab661-wheelhouse" | Out-Null
.\.venv\Scripts\python.exe -m pip wheel --no-deps "agent-control-specification==0.3.1b1" -w "$env:USERPROFILE\lab661-wheelhouse"
.\.venv\Scripts\python.exe -m pip install --no-index --no-deps "$env:USERPROFILE\lab661-wheelhouse\agent_control_specification-0.3.1b1-cp311-abi3-win_amd64.whl"
.\.venv\Scripts\python.exe -m pip check
```

Result: `agent_control_specification-0.3.1b1-cp311-abi3-win_amd64.whl`, 2,788,316
bytes, SHA-256 `51a213a4e19b8e14a40d9e77b8aa3ec3f8dbb7da5dee9565f85832cce6af6074`.
`pip check` reports no broken requirements. The wheel is `abi3`, so it works on
any 64-bit Windows Python 3.11 or newer.

On a new image, skip the toolchains and install this saved wheel directly with
the `pip install --no-index --no-deps` line above.

The owner uploaded the wheel to the upstream GitHub repository and keeps the
local copy in `%USERPROFILE%\lab661-wheelhouse` on the image. With the wheelhouse
present, one command rebuilds the whole `.venv` with no Rust or Build Tools. Pip
takes the ACS wheel from the folder and every other package from PyPI (verified
with `--dry-run --ignore-installed`):

```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install --find-links "$env:USERPROFILE\lab661-wheelhouse" -r requirements.txt
```

### Repo: put `.venv` first on PATH in VS Code terminals on Windows

The VM has no VS Code extensions, so nothing activates `.venv` automatically. New
file `.vscode/settings.json` with a Windows-only key:

```json
{
    "terminal.integrated.env.windows": {
        "PATH": "${workspaceFolder}\\.venv\\Scripts;${env:PATH}",
        "VIRTUAL_ENV": "${workspaceFolder}\\.venv"
    }
}
```

Every new VS Code terminal on Windows should then resolve `python` and
`assert-ai` to `.venv`. The dev container (Linux) ignores `.windows` keys, so
self-paced is unchanged. `.gitignore` already allows `.vscode/settings.json`.
Verified by the owner in a new VS Code terminal: `python on PATH is .venv` is
`ok`. In that same terminal `opa` was `MISS`, because VS Code was started before
OPA was added to the user PATH. Restarting VS Code fixes it.

After restarting VS Code, the owner ran these in a new terminal, and all passed:
`check-setup.ps1` (every line `ok`), `run-offline-loop.ps1` (`5/5`, `PASS`, 100% to
0%, `Loop complete.`), the first Core 1 DevBot prompt (`[bounded_safe] ...`), and
the first More 4 OPA probe (`deny`).

`check-setup.ps1` gained a check, `python on PATH is .venv`, whose `MISS` hint
tells the attendee to open a new terminal or run `.\.venv\Scripts\Activate.ps1`.

### Repo: scripts no longer change the caller's folder

`check-setup.ps1` sets `PYTHONPATH` to the absolute `src` path instead of
changing folder. `run-offline-loop.ps1` uses `Push-Location` and `Pop-Location`.
Both now work when run from any folder and leave the terminal where it was.

### Validation on Windows

In PowerShell 7.5 and Windows PowerShell 5.1:

- `check-setup.ps1`: every line `ok`, exit 0.
- `run-offline-loop.ps1`: exit 0. Validation `strongly blocked 5/5`, guard demo
  `PASS`, attack success `10/10 (100%)` to `0/10 (0%)`, benign `3/3`.
- The committed baseline files keep their SHA-256 after every rebuild.

One gotcha: VS Code terminals inherit PATH from when VS Code started. After a
PATH change (OPA), restart VS Code or reload PATH in the terminal.

### Repo: Skillable pages converted to PowerShell

Every command below was run on the VM in PowerShell 7.5 and its output checked
against the page. Unchanged on purpose: the Copilot and GitHub sign-in page (Core
0, "Sign in to your lab"), and More 0 and 1 (need Azure, Phase B).

| Bash | PowerShell |
|------|------------|
| `./src/scripts/check-setup.sh` | `.\instructions\skillable\scripts\check-setup.ps1` |
| `./src/scripts/run-offline-loop.sh` | `.\instructions\skillable\scripts\run-offline-loop.ps1` |
| `PYTHONPATH=src python3 x.py` | `$env:PYTHONPATH = "src"; python x.py` |
| `head -1 f \| python3 -m json.tool` | `Get-Content f -TotalCount 1 \| python -m json.tool` |
| `cat f` | `Get-Content f` |
| `echo '{...}' \| opa eval ...` | `'{...}' \| opa eval ...` |
| `"$(pwd)/data/results"` | `"$PWD\data\results"` |
| `; echo "exit: $?"` | `; "exit: $LASTEXITCODE"` |
| `mkdir -p d` and `cp f d/` | `New-Item -ItemType Directory -Force d \| Out-Null` and `Copy-Item f d/` |
| `cat >> f <<'EOF' ... EOF` | `Add-Content f @' ... '@` |
| `grep -n -E "re" f` | `Select-String -Path f -Pattern 're'` |
| Multi-line `\` command | One line |

Per file:

- `core-0-setup-environment.md`: "Check your lab environment" and "Run the whole
  loop once" pages. New expected output from `check-setup.ps1`, and a hint for
  `python on PATH is not .venv`.
- `core-1-meet-devbot.md`: six DevBot prompts.
- `core-2-evaluate-assert.md`: baseline rebuild (expected output now shows
  Windows `\` paths), first transcript and score, findings.
- `core-3-generate-policy.md`: generate (Windows `\` paths in expected output),
  read Rego and report, validate, "Try to break the gate" (verified 3/5 and exit
  1, then restored).
- `core-4-guard-verify.md`: guard demo, verify.
- `more-2-viewer.md`: `$PWD` paths.
- `more-3-custom-rego.md`: OPA probes, copy, and the `Add-Content` here-string
  hint. Verified `transform` and `allow`; before the edit `allow`; after it
  `deny`, `transform`, `allow`.
- `more-4-red-teaming.md`: probes, widen, restore. Verified `deny`, `allow`, then
  `deny`, `deny` after widening, and `5/5`.
- `more-5-intervention-points.md`: tool-call demo, `Select-String` for both
  greps, OPA probe (`deny`).
- `more-6-ci-gate.md`: gate with `$LASTEXITCODE` (verified exit 0, then 1, then
  0), drop rule, restore, read workflow.

`skillable-copy.md` regenerated with Git Bash:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' -c "cd '/c/Users/LabUser/Desktop/LAB661' && ./instructions/skillable/generate-skillable-copy.sh"
```

Result: `Wrote skillable-copy.md with 12 page files (mode: full).`, LF endings.

### VM: remove the build tools and clean up for the image

The toolchains were only needed to build the ACS wheel.

- Rust: `& "$env:USERPROFILE\.cargo\bin\rustup.exe" self uninstall -y`
- Build Tools 2022 and the Visual Studio Installer: removed by the owner in
  **Settings > Apps > Installed apps**, Build Tools first, then the installer.
  A silent `setup.exe uninstall ... --quiet` from a non-elevated terminal does
  nothing and leaves no log, so use **Installed apps** or an elevated
  `InstallCleanup.exe -f`.
- Windows SDK: removed by the owner in **Installed apps**. A small "Windows SDK
  AddOn" entry remains, harmless.
- Kept: the Visual C++ 2015-2022 redistributables, and the wheel in
  `%USERPROFILE%\lab661-wheelhouse`.

Then:

```powershell
Remove-Item "$env:TEMP\vs_BuildTools.exe", "$env:TEMP\rustup-init.exe", "$env:TEMP\acs-sdist", "$env:TEMP\opa.sha256" -Recurse -Force -ErrorAction SilentlyContinue
.\.venv\Scripts\python.exe -m pip cache purge
Remove-Item -Recurse -Force artifacts -ErrorAction SilentlyContinue
```

Verified after removal: `check-setup.ps1` all `ok`, `run-offline-loop.ps1` exit 0
with 100% to 0%, baseline hashes unchanged, no `artifacts/`, no `.env`, wheel
kept, 44.7 GB free on C:. `%TEMP%\lab663-ref` (the extracted LAB663 reference)
is kept for Phases B and C.
