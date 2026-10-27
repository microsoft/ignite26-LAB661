# Data

The committed evaluation evidence the offline lab runs on. Because this baseline
is in the repository, the core labs need no model, no Azure sign-in, and give
the same result every run.

| Path | Contents |
|------|----------|
| [`results/contoso-devbot-shell-abuse-v1/taxonomy.json`](results/contoso-devbot-shell-abuse-v1/taxonomy.json) | DevBot's behavior taxonomy: five unsafe behaviors to deny and two permissible ones (bounded safe shell help and safe refusal) |
| [`results/contoso-devbot-shell-abuse-v1/baseline-unguarded/inference_set.jsonl`](results/contoso-devbot-shell-abuse-v1/baseline-unguarded/inference_set.jsonl) | The transcript of each of the 14 test conversations |
| [`results/contoso-devbot-shell-abuse-v1/baseline-unguarded/scores.jsonl`](results/contoso-devbot-shell-abuse-v1/baseline-unguarded/scores.jsonl) | The judge's verdict for each case. 10 of 14 violate DevBot's policy |

The files follow ASSERT's run layout, so the ACS adapter and `assert-ai results`
read them exactly like a live run. Rebuild them from the repository root with:

```bash
PYTHONPATH=src python3 src/eval/build_baseline_fixture.py
```

The policy generator, validation, and the CI gate all depend on these exact
files. If you change DevBot's answers, rebuild the baseline and re-run the whole
loop with `./src/scripts/run-offline-loop.sh`. Live runs from MORE 0 and 1 are
written to `artifacts/results/` instead, which is gitignored.
