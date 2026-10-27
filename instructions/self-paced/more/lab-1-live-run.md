![MORE 1 · Go live with a real model, optional lab that needs Azure](../media/banner-more-1.svg)

# MORE 1: Go live with a real model

## Objective

Run the loop for real, by hand. Replace the deterministic offline pieces with a
live model, so ASSERT generates and judges real conversations and the ACS
generator designs the policy with an LLM. The ACS half of the loop is unchanged.
If you did MORE 0, this is what the skill did for you, one command at a time.

## What you will need

- The Foundry project and `.env` from [MORE 0](lab-0-assert-skill.md), Steps 1
  and 2. If you skipped MORE 0, do those two steps now, then come back.
- The core labs completed once, so you know the shape of the result.

> This lab calls a real model, so it costs money. No API key is used: DevBot and
> ASSERT sign in with your Azure identity. `.env` is gitignored.

---

## Step 1: Run a real ASSERT eval against DevBot

The live eval config is `src/eval/eval_config.yaml`. It describes DevBot's behavior
spec, points the target at `devbot.agent:chat`, and defines the judge dimensions.

```bash
set -a; source .env; set +a
PYTHONPATH=src assert-ai run --config src/eval/eval_config.yaml
```

The first line loads `.env` into your shell, so DevBot sees `DEVBOT_MODE=live`.

ASSERT will generate adversarial and benign prompts from the spec, send each to
DevBot, and judge the transcripts. It writes a real run to
`artifacts/results/contoso-devbot-shell-abuse-live/baseline/`.

Because a real model is non-deterministic and samples are small, your exact
numbers will differ from the offline fixture. Focus on the shape, DevBot should
still fail the unsafe classes, because its instructions are still weak.

## Step 2: Generate the policy with a live LLM

Now let a model design the guardrail rules from the real findings.

```bash
assert-ai acs generate \
  --suite contoso-devbot-shell-abuse-live \
  --run baseline \
  --out artifacts/acs/contoso-devbot-shell-abuse-live \
  --model azure/gpt-5.4 \
  --require-block
```

The generator sends only structured findings signal and redacted representative
snippets to the model, never raw transcripts wholesale, so a secret captured in a
transcript is not shipped to the policy model. Read
[Securing agents with ACS](https://github.com/responsibleai/ASSERT/blob/main/docs/guides/securing-agents-with-acs.md)
for the exact data-handling contract. Still, review the generated Rego. A live
policy often uses richer conditions than the offline keyword rules, which is
better for coverage and exactly why review matters.

`--require-block` makes generation itself fail if the freshly generated policy
does not strongly block every known-bad example, so you never write out a policy
that fails its own validation.

## Step 3: Validate and guard, exactly as before

From here the commands are identical to the core, only the suite and run names
change.

```bash
assert-ai acs validate \
  --manifest artifacts/acs/contoso-devbot-shell-abuse-live/manifest.yaml \
  --suite contoso-devbot-shell-abuse-live \
  --run baseline \
  --require-block
```

Point `guard_target` at the new manifest to enforce the live-generated policy at
runtime, the same way `src/policy/guard_demo.py` does for the offline one.

## Step 4: Keep sensitive evals off third-party models

If your real agent handles sensitive data, do not send its evaluation artifacts
to a third-party generation model. Two options.

- Generate with a local or self-hosted model: `--lm-kind openai-compatible`
  pointed at your own endpoint.
- Or design the plan yourself and generate offline with a fake language model,
  the way `src/policy/generate_offline.py` does.

Either way the compiled policy is real and enforceable.

When you finish the MORE labs, delete the resource group so it stops costing
money.

```bash
az group delete --name rg-lab661-foundry --yes --no-wait
```

---

## Takeaways

- The live track changes only the model, not the loop.
- `assert-ai run` produces real findings; `acs generate --model` designs a real
  policy; validate and guard are unchanged.
- Mind the data-handling contract, and prefer a local generation model for
  sensitive evaluations.
