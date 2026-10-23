# AGENTS.md

Guidance for AI coding agents working in this workshop repository.

## What this repo is

A self-contained, hands-on workshop that teaches runtime agent governance by
securing a deliberately under-governed agent (Contoso DevBot) with a policy
generated from evidence of its own misbehavior. It uses two libraries: ASSERT
for evaluation and the Agent Governance Toolkit's ACS for policy enforcement.

The workshop is modeled structurally on Microsoft Build's LAB540, but points at
a different problem (governance) and keeps everything local.

## Layout

| Path | Purpose |
|------|---------|
| `src/devbot/` | The DevBot agent and its simulated tools |
| `eval/` | Fixture builder, findings viewer, live eval config, committed baseline run |
| `policy/` | Offline generator, guard demo, verify script, example Rego |
| `scripts/` | `check-setup.sh`, `run-offline-loop.sh` |
| `workshop/core/` | Labs 0 through 4 |
| `workshop/more/` | Deeper topics |
| `.agents/skills/` | Copilot skills that guide learners |

## Hard rules

- **Nothing dangerous executes.** DevBot's tools are simulated. Never make a tool
  actually run a shell command, touch the real filesystem, or open a network
  connection. The whole point is to govern intent safely.
- **No real secrets.** The `sk-live-...` string in the agent is a fake matching a
  format. Never replace it with a real credential. `.env` is gitignored.
- **The offline core must stay credential-free.** Any command in `workshop/core`
  must run with no API key. Live-only steps belong in `workshop/more/lab-live-run.md`.
- **Every command in a lab must be tested.** If you change a command, run it and
  paste the real output. Do not write expected output you have not observed.
- **Keep the offline pieces deterministic.** The agent, the fixture builder, and
  the offline generator must produce the same result every run.

## When you change something

- Changing the agent's outputs? Rebuild the baseline fixture
  (`PYTHONPATH=src python3 eval/build_baseline_fixture.py`) and re-run the whole
  loop, because the fixture, the policy conditions, and the labs' expected output
  all depend on those exact strings.
- Changing the policy conditions? Re-run `assert-ai acs validate --require-block`
  and `policy/verify_reeval.py`, and update any lab output that shows a decision.
- Changing a lab command? Run it and update the shown output to match.

## Validation

The single source of truth that the workshop still works:

```bash
./scripts/check-setup.sh
./scripts/run-offline-loop.sh
```

The second must end with the `PASS` line and a 100% to 0% attack-success drop.

## Prose style

Authored prose (README, labs, skills) avoids em-dashes and gratuitous colons.
Colons are fine in headings, tables, code, and YAML. Keep it concise and
concrete.
