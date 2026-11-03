# Sign in to your lab

Sign in to the virtual machine, then to GitHub, so GitHub Copilot works in VS Code.

1. [] Sign in to the virtual machine with this password.

   +++@lab.VirtualMachine(Win11-Pro-Base).Password+++

1. [] In the browser on the virtual machine, open the GitHub Enterprise sign-in page and sign in with your **Azure** credentials.

   +++https://github.com/enterprises/skillable-events/sso+++

1. [] Note your Azure credentials. You use them to sign in to GitHub and, in More 0, to Azure.

   | Credential | Value |
   |:-----------|:------|
   | Username | +++@lab.CloudPortalCredential(User1).Username+++ |
   | Password | +++@lab.CloudPortalCredential(User1).Password+++ |
   | Temporary Access Pass | +++@lab.CloudPortalCredential(User1).AccessToken+++ |

1. [] Keep that browser page open, then open VS Code.
1. [] In VS Code, select **Continue with GitHub** and finish the sign-in through the same SSO page.

   !IMAGE[VS Code sign-in with the Continue with GitHub option](media/vscode-continue-with-github.png)

>[!Alert] Sign in to GitHub with your **Azure** credentials, not a personal GitHub account. GitHub Copilot works only through this enterprise sign-in.

>[!Note] **Success:** you are signed in to the virtual machine and to GitHub in VS Code.

===

# Get started with LAB661

Welcome to **LAB661**. You will take **Contoso DevBot**, a coding agent with no guardrails, and make it safe without editing a single line of the agent.

>[!Knowledge] **Meet the agent.** Contoso DevBot is an internal DevOps helpdesk assistant. Engineers ask it to inspect repositories, explain build failures, and suggest shell commands. It answers fast, and it will also suggest `rm -rf`, print a secret, or obey an instruction hidden in a file.

## What you'll do

The core lab is one full turn of a measure, change, and re-measure loop.

1. **Setup.** Check your environment and run the whole loop once.
1. **Meet DevBot.** Watch it misbehave and learn the vocabulary for stopping it.
1. **Evaluate.** Use ASSERT to turn "it feels unsafe" into five named, measured failures.
1. **Generate and validate.** Compile those findings into an Agent Control Specification (ACS) policy and prove it blocks every known-bad output.
1. **Guard and verify.** Put the policy in front of DevBot and watch attack success drop from 100% to 0%.

>[!Note] **Duration:** about 60 minutes for the core labs. The More labs at the end are optional.

## How these instructions work

>[!Knowledge] Text shown ++like this++ is **copy text**. Select it to copy it to your clipboard, then paste it into the terminal.

>[!Knowledge] Each step has a **checkbox**. Tick it as you go so you can see how far you have come.

Nothing in this lab runs a real dangerous command. DevBot's tools are simulated, and the secret it leaks is a fake.

>[!Note] **Success:** you know what you will build and how to use these instructions.

===

# Check your lab environment

Confirm every tool the lab needs is installed.

1. [] In VS Code, open a terminal with **Terminal > New Terminal**.
1. [] In the terminal toolbar, open the dropdown beside **+** and select **Git Bash**.
1. [] Use this Git Bash terminal at the repository root for every command in the lab.
1. [] Run the setup check.

   ++bash src/scripts/check-setup.sh++

1. [] Confirm every line starts with `ok`.

   ```text-nocopy
       ok    python3 3.13
     ok    assert-ai with the acs integration is importable
     ok    acs-generator present
     ok    agent-control-specification present
     ok    opa on PATH (Version: 0.70.0)
     ok    node on PATH
     ok    devbot agent importable (PYTHONPATH=src)

   All checks passed. Run: bash src/scripts/run-offline-loop.sh
   ```

>[+Hint] A line says `MISS`.
>
> Confirm you are using **Git Bash**, not PowerShell, then run the check again. If it still fails, raise your hand and ask a proctor.

>[!Note] **Success:** your environment has everything the lab needs.

===

# Run the whole loop once

Run all five stages back to back. This is your smoke test.

1. [] Run the offline loop.

   ++bash src/scripts/run-offline-loop.sh++

1. [] Confirm the last lines read as follows.

   ```text-nocopy
   Attack success rate (unsafe responses reaching the user)
     unguarded: 10/10  (100%)
     guarded:   0/10  (0%)
   Benign requests still served under the guard: 3/3

   PASS: guarding drove attack success from 100% to 0% with no benign over-block.
   Loop complete. ASSERT found the unsafe behavior; ACS now blocks it at runtime.
   ```

>[!Knowledge] The script ran five stages. **Capture** a baseline ASSERT run, **generate** an ACS policy, **validate** that it blocks every known-bad output, **guard** DevBot with it, and **verify** the before-and-after attack success rate. The next labs slow each stage down so you can do it on your own agent.

>[!Note] **Success:** you ran the entire lab in one command, with no Azure sign-in and no API key.
