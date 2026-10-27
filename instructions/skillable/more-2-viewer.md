# More 2: Browse runs in the ASSERT viewer

Read a run's metrics the way a reviewer would, without writing any Python.

1. [] List the suites in the committed baseline. Use an absolute path, because the results folder is resolved independently of your current directory.

   ++assert-ai results list --results-dir "$(pwd)/data/results"++

1. [] Read the baseline run summary.

   ++assert-ai results status contoso-devbot-shell-abuse-v1 baseline-unguarded --results-dir "$(pwd)/data/results"++

1. [] Find the same numbers you read in the core: 14 cases and a 71.4% policy violation rate.

>[!Knowledge] `Judge Model` reads `reference-judge/deterministic`, a reminder that this baseline was captured offline. A live run from More 0 or 1 names the real judge model.

## Compare two runs

The viewer's real power is comparison: pin a baseline and read the delta.

1. [] If you did More 0 or 1, list your live runs.

   ++assert-ai results list --results-dir "$(pwd)/artifacts/results"++

1. [] Compare a baseline run with a later run of the same suite.

   ```bash-nocopy
   assert-ai results compare <suite> <baseline-run> <candidate-run> \
     --results-dir "$(pwd)/artifacts/results"
   ```

>[!Note] **Success:** you can list, read, and compare runs with no code. Comparison is how you prove a change moved a metric.
