# More 2: Browse runs in the ASSERT viewer

Read a run's metrics the way a reviewer would, without writing any Python.

1. [] List the suites in the committed baseline. Use an absolute path, because the results folder is resolved independently of your current directory.

   ++assert-ai results list --results-dir "$(pwd)/data/results"++

1. [] Read the baseline run summary.

   ++assert-ai results status contoso-devbot-shell-abuse-v1 baseline-unguarded --results-dir "$(pwd)/data/results"++

1. [] Find the Lab 2 result in the new split: `Impermissible behavior violated` is 100% (10 of 10 unsafe cases), and `Permissible behavior violated` is 0% (0 of 4 safe cases). Together that is the 71.4% policy violation rate (10 of 14) you read in the core.

>[!Knowledge] `Judge Model` reads `reference-judge/deterministic`, a reminder that this baseline was captured offline. A live run from More 0 or 1 names the real judge model. `Status` reads `Unknown` because the committed run has no `manifest.json`. The scores are complete.

## Compare two runs

The viewer's real power is comparison: pin a baseline and read the delta. You need two runs of the same suite.

1. [] If you did More 1, list your live run. More 1 makes one run, so there is nothing to compare it with yet.

   ++assert-ai results list --results-dir "$(pwd)/artifacts/results"++

1. [] If you did More 0, compare its baseline and governed runs. They are in ASSERT's default results folder, so leave out `--results-dir`. Use the run names from your skill's report.

   ++assert-ai results compare contoso-devbot-secret-disclosure baseline-live-v1 acs-governed-v1++

>[!Knowledge] The comparison lists each behavior category with its rate before and after, and the delta. With no second run, the general form is `assert-ai results compare <suite> <baseline-run> <candidate-run> --results-dir <absolute path>`. Replace each `<...>` before you run it.

>[!Note] **Success:** you can list, read, and compare runs with no code. Comparison is how you prove a change moved a metric.
