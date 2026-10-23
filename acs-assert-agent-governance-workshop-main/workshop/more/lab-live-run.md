# MORE: Go live with a real model

## Objective

Run the loop for real. Replace the deterministic offline pieces with a live
model, so ASSERT generates and judges real conversations and the ACS generator
designs the policy with an LLM. The ACS half of the loop is unchanged.

## What you will need

- A model provider key. The examples use Azure OpenAI, but ASSERT speaks to
  100-plus endpoints through LiteLLM, so any supported provider works.
- To use the setup script in Step 0, an Azure subscription where you can create
  resources (the Contributor or Owner role) and quota for the two models.
- The offline core completed at least once, so you know the shape of the result.

> This is the one track that costs money and needs credentials. Everything in
> the core runs without it. Never commit a key. `.env` is gitignored.

---

## Step 0: Set up the Foundry project and models

Every live step calls a real model, so a model has to be deployed before you
start. This lab uses Microsoft Foundry on Azure. A setup script creates
everything for you. If you already have a Foundry project with `gpt-5.4-mini` and
`gpt-5.4` deployed, skip to Step 1.

Run it from the workshop root.

```bash
./workshop/scripts/setup.sh
```

The script walks you through these prompts and then creates whatever is missing.

| Prompt | What to enter |
|--------|---------------|
| Sign in | Open the device login page it prints and enter the code |
| Subscription | Pick the subscription to create resources in |
| Resource group name | Press Enter for `rg-lab661-foundry`, or type your own |
| Azure location | Press Enter for `eastus2`, or type a region that offers the models |
| Foundry resource name | Press Enter for the suggested unique name |

It then shows a plan and asks you to confirm. On confirmation it creates, in
order, the resource group, a Foundry resource, a project named `lab661-project`,
two model deployments, and the monitoring and access that tracing needs.

| Created | Used for |
|---------|----------|
| `gpt-5.4-mini` deployment | DevBot, ASSERT test generation, and judging |
| `gpt-5.4` deployment | Designing the ACS policy in Step 3 |
| Log Analytics workspace and Application Insights | Storing and querying traces |
| A project connection named `appinsights` | Lets Foundry show the project's traces |

It also grants three roles, so tracing works without a trip to the portal.

| Who | Role | Where | Why |
|-----|------|-------|-----|
| You | Foundry User | The Foundry resource | Call the models and use the project with your own identity |
| You | Log Analytics Reader | Application Insights | Query traces |
| The project's managed identity | Log Analytics Reader | Application Insights | Let Foundry read traces, for example to evaluate them |

The script needs the Owner role on the resource group, or Contributor plus User
Access Administrator, because it creates role assignments.

What to know before you run it.

- It is safe to run again. Resources that already exist are reused.
- It finds the latest available model version for you and tries a few deployment types until one works in your region.
- It never prints or writes your key or the Application Insights connection string. At the end it prints the values for `.env` and the commands to fetch both.
- The script sets up the place traces go. DevBot does not send traces yet, so no traces appear until the agent is instrumented.
- If a model is not offered in your region, the script says so, skips it, and exits with an error after trying the rest. Run it again with a new resource group name and a different location.

When you finish the lab, delete the resource group so it stops costing money.

```bash
az group delete --name rg-lab661-foundry --yes --no-wait
```

## Step 1: Configure credentials

```bash
cp .env.example .env
```

Edit `.env` and set your provider variables. If you ran the setup script, use the
values it printed and get the key with the command it showed. For Azure OpenAI:

```bash
AZURE_API_KEY=your-key
AZURE_API_BASE=https://your-resource.openai.azure.com
AZURE_API_VERSION=2025-04-01-preview
DEVBOT_MODE=live
DEVBOT_MODEL=azure/gpt-5.4-mini
```

`DEVBOT_MODE=live` tells DevBot to answer with the real model and the weak
instructions in `src/devbot/instructions.md` instead of the offline stand-in.

## Step 2: Run a real ASSERT eval against DevBot

The live eval config is `eval/eval_config.yaml`. It describes DevBot's behavior
spec, points the target at `devbot.agent:chat`, and defines the judge dimensions.

```bash
export DEVBOT_MODE=live
PYTHONPATH=src assert-ai run --config eval/eval_config.yaml
```

ASSERT will generate adversarial and benign prompts from the spec, send each to
DevBot, and judge the transcripts. It writes a real run to
`artifacts/results/contoso-devbot-shell-abuse-live/baseline/`.

Because a real model is non-deterministic and samples are small, your exact
numbers will differ from the offline fixture. Focus on the shape, DevBot should
still fail the unsafe classes, because its instructions are still weak.

## Step 3: Generate the policy with a live LLM

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

## Step 4: Validate and guard, exactly as before

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
runtime, the same way `policy/guard_demo.py` does for the offline one.

## Step 5: Keep sensitive evals off third-party models

If your real agent handles sensitive data, do not send its evaluation artifacts
to a third-party generation model. Two options.

- Generate with a local or self-hosted model: `--lm-kind openai-compatible`
  pointed at your own endpoint.
- Or design the plan yourself and generate offline with a fake language model,
  the way `policy/generate_offline.py` does.

Either way the compiled policy is real and enforceable.

---

## Takeaways

- The live track changes only the model, not the loop.
- `assert-ai run` produces real findings; `acs generate --model` designs a real
  policy; validate and guard are unchanged.
- Mind the data-handling contract, and prefer a local generation model for
  sensitive evaluations.
