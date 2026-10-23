# Lab 0: Setup

## Objective

Get the workshop environment working and prove it by running the whole offline
loop once. When this lab is done, every later command will already be known to
work on your machine.

## Time estimate

About 10 minutes.

---

## Step 0.1: Install the prerequisites

You need three things. Two are software, one is a binary.

**1. Python 3.11 or newer.**

```bash
python3 --version
```

**2. The Open Policy Agent (`opa`) binary on your `PATH`.**

ACS evaluates the generated Rego by shelling out to OPA, so the binary must be
installed separately. It is a single static binary.

```bash
opa version
```

If that fails, install it from the [OPA docs](https://www.openpolicyagent.org/docs/latest/#running-opa).
On Linux this is often just a download of the `opa` binary into a directory on
your `PATH`.

**3. ASSERT installed with the `acs` extra.**

ASSERT is the evaluation framework. Its `acs` extra pulls in `acs-generator` and
`agent-control-specification`, which are the ACS pieces. ASSERT is not on PyPI,
so install it from a local clone.

```bash
git clone https://github.com/responsibleai/ASSERT.git
pip install -e "./ASSERT[acs]"
```

> Already have an ASSERT checkout? Just run the `pip install -e ".[acs]"` inside
> it. Any recent ASSERT with the `assert_ai.integrations.acs` module works.

## Step 0.2: Verify the environment

From the workshop root:

```bash
./scripts/check-setup.sh
```

You want all green:

```text
  ok    python3 3.12
  ok    assert-ai with the acs integration is importable
  ok    acs-generator present
  ok    agent-control-specification present
  ok    opa on PATH (Version: 0.70.0)
  ok    devbot agent importable (PYTHONPATH=src)
```

If any line says `MISS`, fix that one thing and re-run. The script tells you
what is missing and how to get it.

## Step 0.3: Run the whole loop once

This is your smoke test. It runs all five stages of the workshop back to back.

```bash
./scripts/run-offline-loop.sh
```

The last lines should read:

```text
Attack success rate (unsafe responses reaching the user)
  unguarded: 10/10  (100%)
  guarded:   0/10  (0%)
Benign requests still served under the guard: 3/3

PASS: guarding drove attack success from 100% to 0% with no benign over-block.
Loop complete. ASSERT found the unsafe behavior; ACS now blocks it at runtime.
```

You just ran the entire workshop in one command. The rest of the labs slow that
down and explain each stage so you understand what happened and can do it on
your own agent.

---

## What just happened

The script ran five stages. You will do each one by hand in Labs 2 through 4.

| Stage | Command it ran | What it produced |
|-------|----------------|------------------|
| Capture | `eval/build_baseline_fixture.py` | A baseline ASSERT run for DevBot |
| Generate | `policy/generate_offline.py` | An ACS manifest and Rego bundle |
| Validate | `assert-ai acs validate` | Proof the policy blocks all known-bad output |
| Guard | `policy/guard_demo.py` | DevBot running behind the policy |
| Verify | `policy/verify_reeval.py` | The before and after attack success rate |

## Checkpoint

Before moving on, confirm:

- [ ] `./scripts/check-setup.sh` prints all `ok`
- [ ] `./scripts/run-offline-loop.sh` ends with the `PASS` line
- [ ] You did not need an API key to get here

**Next**: [Lab 1, Meet DevBot and map the risk](lab-1.md)
