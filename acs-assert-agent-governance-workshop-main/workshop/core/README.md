# Core labs

Five labs that take you through the full ASSERT to ACS protect loop. Budget
about 60 minutes. Self-paced learners can take as long as they like.

## Learning journey

```
Lab 0: Setup
    ↓ environment verified, offline loop runs green
Lab 1: Meet DevBot and map the risk
    ↓ you have seen the agent misbehave and know the ACS vocabulary
Lab 2: Evaluate with ASSERT
    ↓ you have findings: five unsafe classes to block
Lab 3: Generate and validate an ACS policy
    ↓ you have a Rego bundle that blocks every known-bad output
Lab 4: Guard, verify, and explore MORE
    ↓ the agent is secured and you measured the improvement
```

## Labs

| # | Lab | Time | Outcome |
|---|-----|------|---------|
| 0 | [Setup](lab-0.md) | ~10 min | `check-setup.sh` passes and the offline loop runs end to end |
| 1 | [Meet DevBot and map the risk](lab-1.md) | ~10 min | You have watched DevBot emit unsafe output and learned ACS intervention points and verdicts |
| 2 | [Evaluate with ASSERT](lab-2.md) | ~15 min | You can read the baseline findings and name the five deny targets |
| 3 | [Generate and validate an ACS policy](lab-3.md) | ~15 min | A generated Rego policy that strongly blocks all five known-bad classes |
| 4 | [Guard, verify, and explore MORE](lab-4.md) | ~10 min | DevBot secured at runtime, attack success 100% to 0%, plus a MORE topic |

## The mental model

ASSERT answers "where does this agent violate its spec?" ACS answers "how do I
stop that at runtime?" The adapter in the middle turns the first answer into the
second. You will run each stage yourself.

If you get stuck, open Copilot Chat and say **"help me debug"**, or read
[TROUBLESHOOTING.md](../TROUBLESHOOTING.md).
