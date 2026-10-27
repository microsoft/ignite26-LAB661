# MORE 3: Author custom Rego

Write and test an ACS rule by hand. Generated policy is a starting point, not a ceiling.

1. [] Open the generated policy again.

   ++cat artifacts/acs/contoso-devbot-shell-abuse-v1/policy/devbot_shell_guardrails.rego++

>[!Knowledge] Every output rule has three parts: a **guard** on the intervention point (`input.intervention_point == "output"`), a **condition** on the value, and a **verdict** with `decision`, `reason`, and `message`. The first matching rule wins, and anything unmatched is allowed.

## Redact instead of block

A flat deny throws away the whole answer. A `transform` verdict keeps the useful part and removes the dangerous part.

1. [] Read the hand-written example that redacts a live secret.

   ++cat src/policy/examples/redact.rego++

1. [] Test it with OPA directly. No agent is needed.

   ++echo '{"intervention_point":"output","policy_target":{"value":"your key is sk-live-51H8XYZ and it is live"}}' | opa eval -I -d src/policy/examples 'data.workshop.custom.output_verdict' -f pretty++

1. [] Confirm the decision is `transform` and the secret is replaced with `sk-live-REDACTED`.
1. [] Confirm a benign output is left alone. This prints `allow`.

   ++echo '{"intervention_point":"output","policy_target":{"value":"run git log"}}' | opa eval -I -d src/policy/examples 'data.workshop.custom.output_verdict.decision' -f raw++

1. [] Check the Rego compiles. A clean exit means no errors.

   ++opa check src/policy/examples++

## Write your own

1. [] In `src/policy/examples/redact.rego`, add a rule that denies an output containing `DROP TABLE`.
1. [] Run `opa check` again, then test your rule with `opa eval`.

>[+Hint] How should the new rule fit in?
>
> Add it to the same `else` chain, with the same guard on `output`, a condition such as `contains(upper(input.policy_target.value), "DROP TABLE")`, and a `deny` verdict.

>[!Note] **Success:** you can read, write, and test an ACS rule in isolation, so you can review anything the generator produces.
