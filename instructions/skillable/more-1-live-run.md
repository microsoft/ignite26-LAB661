# MORE 1: Go live by hand

Run the same loop as the core, one command at a time, with a real model. If you did MORE 0, this is what the skill did for you.

>[!Alert] This lab needs the Foundry project and `.env` from MORE 0. If you skipped MORE 0, go back and complete its setup and configure pages first.

1. [] Load your environment.

   ++set -a; source .env; set +a; export PYTHONPATH=src++

1. [] Run a real ASSERT evaluation against DevBot.

   ++assert-ai run --config src/eval/eval_config.yaml++

>[!Knowledge] ASSERT generates adversarial and benign prompts from DevBot's spec, sends each one to DevBot, and judges the transcripts with a real model. It writes the run to `artifacts/results/contoso-devbot-shell-abuse-live/baseline/`. A real model varies between runs, so your numbers will differ from the offline baseline. DevBot should still fail the unsafe classes, because its instructions are still weak.

>[!Note] **Success:** you have a real evaluation run from a live model.

===

# MORE 1: Generate a live policy

Let a model design the guardrail rules from the real findings.

1. [] Generate the policy with `gpt-5.4`.

   ```bash
   assert-ai acs generate \
     --suite contoso-devbot-shell-abuse-live \
     --run baseline \
     --out artifacts/acs/contoso-devbot-shell-abuse-live \
     --model azure/gpt-5.4 \
     --require-block
   ```

1. [] Read the generated Rego in `artifacts/acs/contoso-devbot-shell-abuse-live/policy/`.
1. [] Validate it, exactly as in the core.

   ```bash
   assert-ai acs validate \
     --manifest artifacts/acs/contoso-devbot-shell-abuse-live/manifest.yaml \
     --suite contoso-devbot-shell-abuse-live \
     --run baseline \
     --require-block
   ```

>[!Knowledge] The generator sends only structured findings and redacted snippets to the model, never whole transcripts, so a secret captured in a transcript is not shipped to the policy model. For sensitive agents, generate with a self-hosted model or design the plan yourself, as `src/policy/generate_offline.py` does.

>[!Note] **Success:** a model-designed policy strongly blocks every known-bad example from your live run.

===

# MORE 1: Clean up Azure

Stop paying for the resources when you are done with MORE 0 and 1.

1. [] Delete the resource group.

   ++az group delete --name rg-lab661-foundry --yes --no-wait++

>[!Note] **Success:** the live track changed only the model, not the loop. Evaluate, generate, validate, and guard are the same commands you ran offline.
