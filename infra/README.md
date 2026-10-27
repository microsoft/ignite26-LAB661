# Infrastructure

Azure setup for the live More labs. The core labs run offline and need none of
this.

[`setup.sh`](setup.sh) provisions everything More 0 and More 1 need in your own
Azure subscription:

- A Microsoft Foundry resource and a project named `lab661-project`.
- Two model deployments: `gpt-5.4-mini` for DevBot, test generation, and judging, and `gpt-5.4` for designing the ACS policy.
- A Log Analytics workspace and Application Insights, connected to the project for traces.
- The roles to use them without an API key: **Foundry User**, **Cognitive Services OpenAI User**, and **Log Analytics Reader** for you, plus **Log Analytics Reader** for the project's managed identity.

Run it from the repository root. It asks for a subscription, resource group,
and region, shows a plan, and creates only what is missing, so it is safe to run
again.

```bash
bash infra/setup.sh
```

It needs the Owner role, or Contributor plus User Access Administrator, on the
resource group, and quota for both models in the region you pick. At the end it
prints the values for `.env`. [More 0](../instructions/self-paced/more/lab-0-assert-skill.md)
walks through every prompt.

When you finish, delete the resource group so it stops costing money.

```bash
az group delete --name rg-lab661-foundry --yes --no-wait
```
