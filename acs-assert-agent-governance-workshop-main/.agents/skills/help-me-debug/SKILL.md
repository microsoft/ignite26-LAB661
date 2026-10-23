# Skill: help-me-debug

## Description

Diagnoses and helps fix problems a learner hits during the ACS + ASSERT
workshop. Routes common symptoms to known fixes and, when needed, investigates
methodically.

## When to invoke

The learner says something like:

- "Help me debug"
- "This isn't working"
- "I got an error"
- "Why did this fail?"

## Behavior

1. **Get the exact symptom.** Ask for the command they ran and the full output or
   error, if not already visible.

2. **Check the known issues first.** Match the symptom against
   `workshop/TROUBLESHOOTING.md`. Most problems are there. The frequent ones:

   | Symptom | Likely cause | Fix |
   |---------|--------------|-----|
   | `opa: command not found` | OPA not installed | Install the `opa` binary onto `PATH` |
   | `No module named 'assert_ai'` / `'acs_generator'` | ASSERT not installed with `[acs]` | `pip install -e "./ASSERT[acs]"` |
   | `No module named 'devbot'` | Missing `PYTHONPATH=src` | Prefix the command with `PYTHONPATH=src` |
   | validate < 5/5 | A rule missing or not matching | Restore the rule in the `PLAN`, regenerate |
   | tool-call rule never fires | `guard_target` enforces input/output only | Use a full ACS host for tool-call points |
   | viewer shows no suites | relative `--results-dir` | Pass an absolute `"$(pwd)/eval/fixtures/results"` |
   | `AgentControlBlocked` on a benign prompt | output tripped a signature | Inspect the raw answer, narrow the rule |

3. **If it is not a known issue, investigate.**
   - Reproduce with the smallest command.
   - Read the actual error, not just the last line.
   - For policy issues, isolate with `opa eval` and `opa check` before blaming the
     agent or the adapter.
   - For findings issues, run `eval/show_findings.py` to see what the adapter
     actually parsed.

4. **Confirm the fix.** Have the learner re-run the failing command and verify it
   now behaves as the lab expects. Do not declare it fixed on theory.

5. **Record it.** If the learner is mid-run, note the blocker and its resolution
   in `workshop/progress.json`.

## Guardrails

- Fix the learner's actual problem. Do not send them down a rewrite they did not
  need.
- Prefer the smallest change that makes the expected output appear.
- If a fix requires editing a workshop file the learner did not mean to change,
  say so and offer to restore the original.
