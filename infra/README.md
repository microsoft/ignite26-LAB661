# Infrastructure

Azure setup for the live More labs. The core labs run offline and need none of
this.

[`setup.sh`](setup.sh) provisions everything More 0 and More 1 need in your own
Azure subscription:

- A Microsoft Foundry resource and a project named `lab661-project`.
- Two model deployments: `gpt-5.4-mini` for DevBot, plus test generation and judging in More 1, and `gpt-5.4` for research and judging in More 0 and for policy generation.
- A Log Analytics workspace and Application Insights, connected to the project and reserved for tracing. The current labs do not send traces.
- The roles to use them without an API key: **Foundry User**, **Cognitive Services OpenAI User**, and **Log Analytics Reader** for you, plus **Log Analytics Reader** for the project's managed identity.

Run it from the repository root. It asks for a subscription, resource group,
and region, shows a plan, and creates only what is missing, so it is safe to run
again.

```bash
bash infra/setup.sh
```

It needs the Owner role, or Contributor plus User Access Administrator, on the
resource group, and quota for both models in the region you pick. After successful
provisioning it creates a private `.env` with the live settings and the
Application Insights connection string, without printing the credential. An existing `.env` is kept
unless you confirm replacement; replacement discards custom settings.
[More 0](../instructions/self-paced/more/lab-0-assert-skill.md) walks through every
prompt and validates the generated environment.

When the resources already exist, for example in a pre-provisioned Skillable lab,
`bash infra/setup.sh --env-only` creates nothing. It finds the Foundry resource
and Application Insights in the resource group and only writes `.env`.

When you finish, delete the resource group so it stops costing money. Use the
name you gave setup; the default is shown here.

```bash
az group delete --name rg-lab661-foundry --yes --no-wait
```
