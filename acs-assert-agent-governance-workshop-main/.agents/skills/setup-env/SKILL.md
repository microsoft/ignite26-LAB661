# Skill: setup-env

## Description

Gets a learner's environment ready for the ACS + ASSERT workshop and verifies it,
so Lab 0 passes on the first try.

## When to invoke

The learner says something like:

- "Set up my environment"
- "Help me install the prerequisites"
- "Get me ready for the workshop"
- "check-setup is failing"

## Behavior

1. **Run the checker first.** Have the learner run `./scripts/check-setup.sh` and
   paste the output. It reports exactly what is present and what is missing, so
   you fix only what is broken.

2. **Resolve each MISS in order.** The checker verifies five things.

   | Check | If missing |
   |-------|-----------|
   | python3 3.11+ | Install or select a Python 3.11+ interpreter |
   | assert-ai with the acs integration | `git clone https://github.com/responsibleai/ASSERT.git && pip install -e "./ASSERT[acs]"` |
   | acs-generator | Comes from the `[acs]` extra; reinstall ASSERT with `[acs]` |
   | agent-control-specification | Same, from the `[acs]` extra |
   | opa on PATH | Download the `opa` binary from the OPA docs onto `PATH` |
   | devbot importable | Run workshop commands with `PYTHONPATH=src` |

3. **Re-run the checker.** After each fix, re-run `./scripts/check-setup.sh`.
   Do not move on until every line is `ok`.

4. **Smoke test.** Once green, have the learner run
   `./scripts/run-offline-loop.sh` and confirm it ends with the `PASS` line. That
   proves the whole toolchain works before they start Lab 1.

## Guardrails

- Do not install anything the checker says is already present.
- Do not require credentials. The offline core needs none; only the live track
  does.
- If a fix needs elevated permissions or a system package the learner cannot
  install, say so plainly and suggest the closest workable alternative.
