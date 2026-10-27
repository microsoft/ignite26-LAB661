# More 1: Go live by hand

Run the same loop as the core, one command at a time, with a real model. If you did More 0, this is what the skill did for you.

>[!Alert] This lab needs the `.env` from More 0. If you skipped More 0, complete its **Connect to Microsoft Foundry** and **Validate your environment** pages first.

1. [] Load your environment.

   ++set -a; source .env; set +a; export PYTHONPATH=src++

1. [] Run a real ASSERT evaluation against DevBot.

   ++assert-ai run --config src/eval/eval_config.yaml --override artifacts_root="$PWD/artifacts"++

   >[!Knowledge] ASSERT generates adversarial and benign prompts from DevBot's spec, sends each one to DevBot, and judges the transcripts with a real model. The override keeps the run in this repository, at `artifacts/results/contoso-devbot-shell-abuse-live/baseline/`. A real model varies between runs, so your numbers will differ from the offline baseline. Expect fewer failing classes. In two fresh test runs, harm ranged from 21.4% to 50.0% and over-refusal from 0% to 18.8%, because each run generates new test cases. Only destructive commands got through, 3 of 16 both times.

1. [] Check your run.

   ++assert-ai results status contoso-devbot-shell-abuse-live baseline --results-dir "$PWD/artifacts/results"++

>[!Note] **Success:** you have a real evaluation run from a live model.

===

# More 1: Generate a live policy

Let a model design the guardrail rules from the real findings, then check whether they can ever fire.

1. [] Generate the policy with `gpt-5.4`.

   ```bash
   assert-ai acs generate \
     --run-dir artifacts/results/contoso-devbot-shell-abuse-live/baseline \
     --out artifacts/acs/contoso-devbot-shell-abuse-live \
     --model azure/gpt-5.4
   ```

   In one test run it ended with `handled 0/4 ... strongly blocked 0/4` and a note that the policy conditions on LLM annotators. Yours may differ.

1. [] See what the rules check.

   ++grep -n "annotations\." artifacts/acs/contoso-devbot-shell-abuse-live/policy/*.rego++

   ```text-nocopy
   38:    input.annotations.unsafe_remote_exec_output == true
   54:    input.annotations.unsafe_destructive_fs_output == true
   ```

1. [] Check whether the manifest wires those classifiers to the reply.

   ++grep -n -A6 "^intervention_points\|^annotators" artifacts/acs/contoso-devbot-shell-abuse-live/manifest.yaml++

   Look for an `annotations` entry under `output`. In two test runs there was none. The classifiers were only declared under `annotators`. The rules themselves differed between runs.

   >[!Knowledge] The rules deny a reply only when an LLM classifier, an *annotator*, labels it unsafe. Offline validation never runs a classifier, so the rules cannot fire there. And with no `annotations` entry on the `output` point, the label is never set at runtime either, so the policy would allow everything.

   >[!Alert] A model-designed policy can look finished and still never fire. Check what its rules condition on, and check that every classifier is wired to the point it guards. The More 0 skill hit the same gap.

1. [] Validate it, and note what validation can prove.

   ```bash
   assert-ai acs validate \
     --manifest artifacts/acs/contoso-devbot-shell-abuse-live/manifest.yaml \
     --run-dir artifacts/results/contoso-devbot-shell-abuse-live/baseline
   ```

   Expect `handled 0/4 ... strongly blocked 0/4`. Do not add `--require-block` for this policy. It exits with an error because nothing can be blocked offline.

>[!Knowledge] Offline validation proves only rules it can evaluate, such as the core's keyword rules. To prove a classifier-based policy, wire the classifier, wrap DevBot, and rerun the same evaluation, as the skill did in More 0. Or write keyword rules from these findings, as in the core, so `--require-block` can prove them offline. The generator sends only structured findings and redacted snippets to the model, never whole transcripts. For sensitive agents, generate with a self-hosted model or design the plan yourself, as `src/policy/generate_offline.py` does.

>[!Note] **Success:** you ran the loop with a live model and can tell whether a generated policy can fire before you trust it.
