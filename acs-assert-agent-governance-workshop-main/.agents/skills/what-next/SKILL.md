# Skill: what-next

## Description

Tells a learner where they are in the workshop and what to do next, based on
their progress. Good for resuming after a break or deciding which MORE lab to
take.

## When to invoke

The learner says something like:

- "What's next?"
- "Where am I?"
- "What should I do now?"
- "I finished, what else is there?"

## Behavior

1. **Read progress.** Load `workshop/progress.json`. If it does not exist, the
   learner has not started, so point them at Lab 0 and the run-workshop skill.

2. **Locate them.** Report their track and current step in one line, then give
   the single next action.

   | If they are at | Next action |
   |----------------|-------------|
   | not started | `./scripts/check-setup.sh`, then Lab 0 |
   | Lab 0 done | Lab 1, meet DevBot |
   | Lab 1 done | Lab 2, evaluate with ASSERT |
   | Lab 2 done | Lab 3, generate and validate |
   | Lab 3 done | Lab 4, guard and verify |
   | Lab 4 done | pick a MORE lab |
   | all core done | live track or a MORE lab they have not done |

3. **Recommend a MORE lab by fit.** When the core is done, suggest based on what
   the learner cares about.

   | If the learner wants to | Suggest |
   |-------------------------|---------|
   | write policy by hand | `more/lab-custom-rego.md` |
   | understand tool-call enforcement | `more/lab-intervention-points.md` |
   | use a real model | `more/lab-live-run.md` |
   | protect a repo | `more/lab-ci-gate.md` |
   | inspect runs visually | `more/lab-viewer.md` |
   | stress-test the policy | `more/lab-red-teaming.md` |

4. **One thing at a time.** Give exactly one recommended next step, not a list of
   everything. Offer the full menu only if the learner asks.

## Guardrails

- Base the answer on `workshop/progress.json`, not on assumptions.
- If progress and the learner's memory disagree, ask one clarifying question
  before advising.
