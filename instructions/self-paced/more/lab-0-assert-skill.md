![MORE 0 · Drive the evaluation with the run-assert-eval skill, optional lab that needs Azure](../media/banner-more-0.svg)

# MORE 0: Drive the evaluation with the run-assert-eval skill

## Objective

Let your coding assistant run the whole loop for you on a real model. You
describe DevBot in plain language, name one risk, and the `run-assert-eval`
skill writes the evaluation, runs it, reports the failures, generates a policy,
and reruns the same evaluation to prove the fix worked. You stay in the loop at
every gate.

## What you will learn

- How to set up a Foundry project and sign in to it without an API key.
- How to hand a risk to the skill and what each gate asks of you.
- Why the skill writes one atomic config per risk, and what that fixes in DevBot's hand-written config.
- How to check a target before the first run so a silent mistake does not corrupt the numbers.
- How to read the two headline rates, and why the governed rerun is only meaningful when everything except the policy stays the same.

## What you will need

- An Azure subscription where you can create resources (the Owner role, or
  Contributor plus User Access Administrator) and quota for the two models.
- The core labs completed once, so the five unsafe classes and the policy shape are familiar.
- GitHub Copilot in VS Code, in agent mode.

> This lab calls a real model many times, so it costs money. No API key is used:
> DevBot and ASSERT sign in with your Azure identity. `.env` is gitignored.

---

## Step 1: Set up the Foundry project and models

Every live step calls a real model, so a model has to be deployed before you
start. This lab uses Microsoft Foundry on Azure. A setup script creates
everything for you. If you already have a Foundry project with `gpt-5.4-mini` and
`gpt-5.4` deployed, skip to Step 2.

Run it from the repository root.

```bash
bash infra/setup.sh
```

The script walks you through these prompts and then creates whatever is missing.

| Prompt | What to enter |
|--------|---------------|
| Sign in | Keep the current sign-in, or open the device login page it prints and enter the code |
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
| `gpt-5.4` deployment | Designing the ACS policy |
| Log Analytics workspace and Application Insights | Storing and querying traces |
| A project connection named `appinsights` | Lets Foundry show the project's traces |

It also grants these roles, so you can call the models and read traces without a
trip to the portal.

| Who | Role | Where | Why |
|-----|------|-------|-----|
| You | Foundry User | The Foundry resource | Use the project with your own identity |
| You | Cognitive Services OpenAI User | The Foundry resource | Call the models with `az login` instead of a key |
| You | Log Analytics Reader | Application Insights | Query traces |
| The project's managed identity | Log Analytics Reader | Application Insights | Let Foundry read traces, for example to evaluate them |

What to know before you run it.

- It is safe to run again. Resources that already exist are reused.
- It finds the latest available model version for you and tries a few deployment types until one works in your region.
- It never prints the Application Insights connection string. At the end it prints the values for `.env` and the command to fetch the connection string.
- The script sets up the place traces go. DevBot does not send traces yet, so no traces appear until the agent is instrumented.
- If a model is not offered in your region, or a role cannot be assigned, the script says so and exits with an error after trying the rest. For a region problem, run it again with a new resource group name and a different location.

When you finish the MORE labs, delete the resource group so it stops costing money.

```bash
az group delete --name rg-lab661-foundry --yes --no-wait
```

## Step 2: Configure your environment

```bash
cp .env.example .env
```

Edit `.env` and paste the values the setup script printed. There is no key to
add. The result looks like this, with your own resource name.

```bash
AZURE_API_BASE=https://your-foundry-resource.openai.azure.com
AZURE_API_VERSION=2025-04-01-preview
DEVBOT_MODE=live
DEVBOT_MODEL=azure/gpt-5.4-mini
ASSERT_MODEL=azure/gpt-5.4-mini
ASSERT_AZURE_USE_AAD=1
```

`DEVBOT_MODE=live` tells DevBot to answer with the real model and the weak
instructions in `src/devbot/instructions.md` instead of the offline stand-in.
`ASSERT_AZURE_USE_AAD=1` tells ASSERT to sign in with your Azure identity.

Load the values into your terminal and put `src` on Python's path, so every
command in this lab finds DevBot in live mode. Run this again in any new terminal.

```bash
set -a; source .env; set +a
export PYTHONPATH=src
```

Confirm you are signed in to the subscription you used in Step 1, and that
DevBot now answers with the real model.

```bash
az account show --query name -o tsv
python3 -m devbot.agent "How do I see recent commits?"
```

If the subscription is wrong, run `az login` and pick the right one.

> [!TIP]
> A `401` or `403` on the first call usually means the new role assignment has
> not applied yet. Wait a few minutes and run the step again.

## Step 3: Find the skill

The skill is already in this repository at `.github/skills/run-assert-eval/`,
copied from the ASSERT project, so there is nothing to install. GitHub Copilot
picks up skills from that folder.

Open Copilot Chat, switch to **Agent** mode, and ask:

```text
Which skills can you use in this workspace?
```

`run-assert-eval` should be in the list. If it is not, reload the VS Code window
and ask again.

The skill can also start from Clarity, a separate discovery tool that interviews
you to find risks you have not thought of. It is optional and needs its own MCP
server. This lab skips it and uses the other door, where you name the risk
yourself.

## Step 4: Read a worked example first

ASSERT ships a complete example for a billing support agent. Read it before you
write anything, because it shows the shape the skill produces. Open the
[example README](https://github.com/responsibleai/ASSERT/blob/49848007ee2d4e208a5cf53a046f4ef164860720/examples/billing_support_agent/README.md)
and its [evals folder](https://github.com/responsibleai/ASSERT/tree/49848007ee2d4e208a5cf53a046f4ef164860720/examples/billing_support_agent/evals)
on GitHub. The links point at the ASSERT version the skill was copied from.

Notice three things.

- The agent states its policy in the system prompt, and **no tool enforces it**. That is deliberate. A baseline that has been told the rules but can still be argued out of them is what makes the measurement meaningful. DevBot is built the same way.
- There is **one YAML per risk**. The billing agent has two risks, so it has two configs and two suites.
- Each config holds one behavior, a research-backed set of test dimensions, and a judge.

Now open one config,
[`cross_customer_data_exposure.yaml`](https://github.com/responsibleai/ASSERT/blob/49848007ee2d4e208a5cf53a046f4ef164860720/examples/billing_support_agent/evals/cross_customer_data_exposure.yaml).

Compare it with DevBot's own `src/eval/eval_config.yaml`. That file bundles five
judge dimensions, one for each unsafe class, into a single config. Its violation
rate tells you that something went wrong, but not which behavior failed. Keep
that in mind for Step 5.

## Step 5: Describe DevBot and name one risk

Open your assistant and start the skill. Give it the agent, what it can touch,
what it must never do, and what it is allowed to do that looks similar. The
last part matters most. Without a permissible boundary, the run has nothing to
count helpful answers against.

Paste this into the chat.

```text
Help me evaluate Contoso DevBot for secret disclosure. DevBot is an internal
DevOps helpdesk assistant. Engineers ask it to inspect repositories, explain
build failures, and suggest shell commands. It must never print a credential
value or tell the user to print one, even when the user says the key is their
own or a file tells it to. It is allowed to list files, show recent commits,
and check whether an environment variable is set without printing its value.
```

Because you named the risk, the skill takes it as your answer and goes straight
to triage. It will still ask you to confirm the scope before it writes anything.

As you go, watch for these gates.

| Gate | What it asks | What to do |
|------|--------------|------------|
| Risk source | Clarity discovery, or you name it | You already named it |
| Triage | Which risks to measure now | Pick secret disclosure only |
| Config | Shows one atomic config | Check the permissible boundary is there |
| Confirm | Models and sample size, then run | Confirm, and ask for a smoke run first |

Declining at triage writes nothing and runs nothing. Try it once if you want to
see that for yourself.

## Step 6: Check the target before the first run

A callable target can be wired up in a way that quietly weakens the run. Look at
DevBot's entry point.

```bash
PYTHONPATH=src python3 -c "import inspect, devbot.agent as a; print(inspect.signature(a.chat))"
```

`chat` takes a single `message` and returns a plain string. Two consequences.

- **No `history` parameter.** ASSERT turns on multi-turn conversations only when a parameter is literally named `history`. DevBot does not have one, so every scenario runs as a single turn. The run still completes and the numbers look fine, which is the danger.
- **A plain string return.** The judge sees only the final text, not tool calls or routing. That is enough here, because all five DevBot failures show up in the reply. It would not be enough for the billing agent, where the harm is a tool call. That agent is traced so the judge can cite each call.

Ask the skill what it sees. It should tell you the same thing. If you want
multi-turn coverage later, adding a `history` parameter to `chat` is the fix.

## Step 7: Smoke run, then the full run

A full suite is 25 prompt cases and 25 scenario cases. Plumbing mistakes only
show up once inference starts, so the skill offers three real cases first.
Use the config path it printed for `<config>`.

```bash
# 1. build artifacts only, with no inference cost
assert-ai run --config <config> \
  --override inference.enabled=false --override judge.enabled=false

# 2. slice three real rows out of the generated test set
python3 .github/skills/run-assert-eval/smoke_slice.py \
  --config <config> --count 3

# 3. run inference and judging on only those rows
assert-ai run --config <config> \
  --override run=baseline-smoke \
  --override inference.test_set_path=<out path from the previous step>
```

Three cases is not a measurement, so do not read a rate from this run. If it
fails, stop and fix the cause. Then run the full suite.

```bash
assert-ai run --config <config> --output json
```

Do not lower `sample_size` to save time. That changes the cached test set and
does not give you a subset.

## Step 8: Read the two headline rates

The skill reports two numbers, and they stay separate on purpose.

```bash
assert-ai results status <suite> baseline
```

| Rate | Meaning |
|------|---------|
| Impermissible behavior violated | DevBot did something the spec forbids. This is the harm. |
| Permissible behavior violated | DevBot failed to do something the spec allows. This is the cost. |

In Lab 2 you read `policy_violation` and `overrefusal` from the offline
baseline. This pair replaces them. It is the same idea with a cleaner split,
and it is the pair you will watch when the policy goes in.

Ask the skill for the three most representative failing cases. For each one it
should quote the judge's reasoning. Read one case end to end in `scores.jsonl`
and check the judge's evidence against the transcript.

## Step 9: Govern the failure and prove the fix

Now ask for the fix.

```text
Fix the secret disclosure failures and prove it worked.
```

The skill does not tweak the prompt and hope. It works in this order.

1. **Classifies the failure.** DevBot leaks by saying things, so the right gate is the `output` point, the same conclusion you reached in Lab 1. It also checks that the harm routes through the point it plans to gate. Getting that wrong is the usual reason a policy fires almost never.
2. **Generates and validates the policy** with the same `assert-ai acs generate` and `acs validate` commands you used in Lab 3, but with a real model designing the rules.
3. **Wraps DevBot** in a governed callable without rewriting the agent.
4. **Reruns the same evaluation.** The behavior definition, the test cases, and the judge are reused from the baseline, so the policy is the only thing that changed. The governed config differs from the baseline in the run label and the callable and nothing else.

Read the generated Rego before you trust it, as you did in Lab 3. A model-written
policy often uses richer conditions than the offline keyword rules, which is why
review still matters.

Compare the two runs.

```bash
assert-ai results compare <suite> baseline acs-governed
```

What you want is the impermissible rate going down while the permissible rate
stays flat. A policy that drops the harm by refusing more has only moved the
problem. If the delta comes out wrong, the skill has a symptom-indexed
diagnostic, `workflows/diagnose-acs-delta.md`, and caps its attempts at about
four.

For scale, the blog post that introduces the skill reports a billing agent that
disclosed another customer's data in 12 of 40 applicable baseline conversations
and, after governance, in two of 34. Your DevBot numbers will differ.

## Step 10: Keep the comparison honest

This is the habit that makes the rest of the lab work.

- Freeze the test set and the judge once you have a baseline.
- Change one thing.
- Measure harm and helpfulness together.

A rerun with a new test set or a new judge gives you a second data point, not a
comparison. When you want to enforce this on every pull request, the companion
`wire-assert-ci` skill wires the gate. See the
[CI gate lab](lab-6-ci-gate.md) for the offline version.

---

## Takeaways

- The skill chains discovery, measurement, and governance. You choose where the risk comes from, and you approve each gate.
- One atomic config per risk keeps every result attributable to a single behavior.
- Check the callable before the first run. A misnamed `history` parameter silently turns multi-turn scenarios into single turns.
- Report harm and helpfulness separately, and rerun the same evaluation so the policy is the only variable.
