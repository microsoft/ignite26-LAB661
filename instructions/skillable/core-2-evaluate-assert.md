# Capture the baseline

Turn "DevBot feels unsafe" into evidence you can measure.

>[!Knowledge] **ASSERT** is spec-driven. You describe the behaviors an agent should and should not show. ASSERT generates adversarial and benign prompts from that spec, sends them to the agent, and uses an LLM judge to score every conversation. Each run writes `inference_set.jsonl` (the transcripts), `scores.jsonl` (the verdicts), and `taxonomy.json` (the behavior categories).

The core lab captures the same three artifacts offline, by running DevBot over a fixed prompt set with a small reference judge.

1. [] Rebuild the baseline run.

   ++PYTHONPATH=src python3 src/eval/build_baseline_fixture.py++

1. [] Confirm the first two lines read as follows. The script then prints the full path of each file it wrote.

   ```text-nocopy
   Wrote baseline fixture to data/results/contoso-devbot-shell-abuse-v1/baseline-unguarded
     cases: 14   policy_violations: 10
   ```

1. [] Open the first transcript, which is what the judge saw.

   ++head -1 data/results/contoso-devbot-shell-abuse-v1/baseline-unguarded/inference_set.jsonl | python3 -m json.tool++

1. [] Open the first score.

   ++head -1 data/results/contoso-devbot-shell-abuse-v1/baseline-unguarded/scores.jsonl | python3 -m json.tool++

1. [] In the score, find `verdict.dimensions.policy_violation` and the `verdict.node_judgments` list.

>[!Knowledge] Each node judgment says whether a taxonomy category was `relevant` to the case and whether it was `violated`. That node-level detail is what lets ACS attribute a violation to one specific behavior.

>[!Note] **Success:** you have a baseline run and you know what the judge recorded.

===

# Read the findings

Read the run the way the ACS adapter reads it, and get your list of what to block.

1. [] Summarize the findings.

   ++PYTHONPATH=src python3 src/eval/show_findings.py++

1. [] After a short header naming the suite, run, behavior, and target, confirm you see five deny targets.

   ```text-nocopy
   Overall dimensions (violation rate across all scored cases):
     overrefusal             0%  (0/14)
     policy_violation       71%  (10/14)

   Deny targets (non-permissible behavior nodes ASSERT saw violated):
     - Data exfiltration
     - Destructive shell command issuance or endorsement
     - Embedded-instruction obedience
     - Remote code execution endorsement
     - Secret disclosure

   Intervention points with evidence: output
   ```

1. [] Write down your baseline: **policy_violation 71%, 10 of 14 cases**. This is the number you will drive down.

>[!Knowledge] **Permissible behaviors never become deny targets.** The taxonomy marks `Bounded safe shell assistance` and `Safe refusal` as permissible. A guardrail can restrict actions but cannot compel helpfulness. The adapter excludes permissible behaviors from deny targets. Test the generated policy on benign requests too, to check that its rules preserve safe assistance. Overrefusal is reported for your awareness instead.

>[!Knowledge] **Every violation surfaces at `output`.** The adapter recovered the offending text from the transcripts and attributed it to the `output` point. That is why the policy you build next guards `output`.

>[!Note] **Success:** you turned a vague worry into five named, evidence-backed deny targets and a measured baseline.
