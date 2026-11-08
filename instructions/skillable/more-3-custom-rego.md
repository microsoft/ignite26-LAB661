# More 3: Author custom Rego

Write and test an ACS rule by hand. Generated policy is a starting point, not a ceiling.

1. [] Open the generated policy again.

   ++Get-Content artifacts/acs/contoso-devbot-shell-abuse-v1/policy/devbot_shell_guardrails.rego++

>[!Knowledge] Every output rule has three parts: a **guard** on the intervention point (`input.intervention_point == "output"`), a **condition** on the value, and a **verdict** with `decision`, `reason`, and `message`. The first matching rule wins, and anything unmatched is allowed.

## Redact instead of block

A flat deny throws away the whole answer. A `transform` verdict keeps the useful part and removes the dangerous part.

1. [] Read the hand-written example that redacts a live secret.

   ++Get-Content src/policy/examples/redact.rego++

1. [] Test it with OPA directly. No agent is needed.

   ++'{"intervention_point":"output","policy_target":{"value":"your key is sk-live-51H8XYZ and it is live"}}' | opa eval -I -d src/policy/examples 'data.workshop.custom.output_verdict' -f pretty++

1. [] Confirm the decision is `transform` and the secret is replaced with `sk-live-REDACTED`.
1. [] Confirm a benign output is left alone. This prints `allow`.

   ++'{"intervention_point":"output","policy_target":{"value":"run git log"}}' | opa eval -I -d src/policy/examples 'data.workshop.custom.output_verdict.decision' -f raw++

1. [] Check the Rego compiles. A clean exit means no errors.

   ++opa check src/policy/examples++

## Write your own

1. [] Work on a copy, so the example stays as shipped.

   ```powershell
   New-Item -ItemType Directory -Force artifacts/custom-rego | Out-Null
   Copy-Item src/policy/examples/redact.rego artifacts/custom-rego/
   ```

1. [] In `artifacts/custom-rego/redact.rego`, add a rule that denies an output containing `DROP TABLE`.

   >[!Alert] **Edit the copy before you test.** If you skip the edit, the test prints `allow` instead of `deny`, because the copied file has no `DROP TABLE` rule yet. Stuck? Open the hint below.

1. [] Check it compiles.

   ++opa check artifacts/custom-rego++

1. [] Test it. This prints `deny`.

   ++'{"intervention_point":"output","policy_target":{"value":"then run DROP TABLE users;"}}' | opa eval -I -d artifacts/custom-rego 'data.workshop.custom.output_verdict.decision' -f raw++

1. [] Confirm the redaction still applies. This prints `transform`.

   ++'{"intervention_point":"output","policy_target":{"value":"your key is sk-live-51H8XYZ and it is live"}}' | opa eval -I -d artifacts/custom-rego 'data.workshop.custom.output_verdict.decision' -f raw++

1. [] Confirm a benign output is still allowed. This prints `allow`.

   ++'{"intervention_point":"output","policy_target":{"value":"run git log"}}' | opa eval -I -d artifacts/custom-rego 'data.workshop.custom.output_verdict.decision' -f raw++

>[+Hint] One solution
>
> Copy the ready-made solution over your copy. It is the example plus one rule at the end of the `else` chain, and copying it again is safe. `upper` makes the match case-insensitive. The redaction rule comes first, so an output with both a secret and `DROP TABLE` is redacted, not denied.
>
> ++Copy-Item -Force src/policy/lab-variants/redact.drop-table.rego.txt artifacts/custom-rego/redact.rego++
>
> The rule it adds:
>
> ```text-nocopy
> else := {
>     "decision": "deny",
>     "reason": "sql_destruction",
>     "message": "Blocks endorsing a DROP TABLE statement.",
> } if {
>     input.intervention_point == "output"
>     contains(upper(input.policy_target.value), "DROP TABLE")
> }
> ```

>[!Note] **Success:** you can read, write, and test an ACS rule in isolation, so you can review anything the generator produces.
