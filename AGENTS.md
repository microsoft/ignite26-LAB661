# AGENTS.md

Guidance for AI coding agents working in this lab repository (Microsoft Ignite
LAB661).

## What this repo is

A self-contained, hands-on lab that teaches runtime agent governance by
securing a deliberately under-governed agent (Contoso DevBot) with a policy
generated from evidence of its own misbehavior. It uses two libraries: ASSERT
for evaluation and the Agent Governance Toolkit's ACS for policy enforcement.

## Layout

Run every command from the repository root.

| Path | Purpose |
|------|---------|
| `src/devbot/` | The DevBot agent and its simulated tools |
| `src/eval/` | Fixture builder, findings viewer, live eval config |
| `src/policy/` | Offline generator, guard demo, verify script, example Rego |
| `src/scripts/` | `check-setup.sh`, `run-offline-loop.sh` |
| `data/results/` | Committed baseline run and behavior taxonomy |
| `infra/` | `setup.sh`, which provisions Foundry for the live track |
| `instructions/self-paced/core/` | Core labs 0 through 4 |
| `instructions/self-paced/more/` | MORE labs 0 through 6, deeper topics |
| `instructions/skillable/` | The same core labs as a Skillable paged manual |
| `docs/` | Overview, troubleshooting, diagrams |
| `artifacts/` | Generated policy and live runs (gitignored) |

## Hard rules

- **Nothing dangerous executes.** DevBot's tools are simulated. Never make a tool
  actually run a shell command, touch the real filesystem, or open a network
  connection. The whole point is to govern intent safely.
- **No real secrets.** The `sk-live-...` string in the agent is a fake matching a
  format. Never replace it with a real credential. `.env` is gitignored.
- **No API keys.** The live track signs in with the learner's Azure identity
  (`az login`). Do not add key-based auth.
- **The offline core must stay credential-free.** Any command in the core labs
  must run without an Azure sign-in. Live-only steps belong in MORE 0 and 1
  (`instructions/self-paced/more/lab-0-assert-skill.md`, `lab-1-live-run.md`).
- **Every command in a lab must be tested.** If you change a command, run it and
  paste the real output. Do not write expected output you have not observed.
- **Keep the offline pieces deterministic.** The agent, the fixture builder, and
  the offline generator must produce the same result every run.

## When you change something

- Changing the agent's outputs? Rebuild the baseline fixture
  (`PYTHONPATH=src python3 src/eval/build_baseline_fixture.py`) and re-run the
  whole loop, because the fixture, the policy conditions, and the labs' expected
  output all depend on those exact strings.
- Changing the policy conditions? Re-run `assert-ai acs validate --require-block`
  and `src/policy/verify_reeval.py`, and update any lab output that shows a decision.
- Changing a lab command? Run it and update the shown output to match, in both
  `instructions/self-paced/` and `instructions/skillable/`.
- Renaming, adding, or retiming a lab? Update `LABS` in
  `instructions/self-paced/media/make_banners.py` and run it to regenerate the
  progress banners.

## Validation

The single source of truth that the lab still works:

```bash
./src/scripts/check-setup.sh
./src/scripts/run-offline-loop.sh
```

The second must end with the `PASS` line and a 100% to 0% attack-success drop.

## Prose style

Authored prose (README, labs, skills) avoids em-dashes and gratuitous colons.
Colons are fine in headings, tables, code, and YAML. Keep it concise and
concrete.
