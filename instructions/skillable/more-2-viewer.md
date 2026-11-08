# More 2: Browse runs in the ASSERT viewer

Read a run's metrics the way a reviewer would, without writing any Python.

1. [] List the suites in the committed baseline. Use an absolute path, because the results folder is resolved independently of your current directory.

   ++assert-ai results list --results-dir "$PWD\data\results"++

1. [] Read the baseline run summary.

   ++assert-ai results status contoso-devbot-shell-abuse-v1 baseline-unguarded --results-dir "$PWD\data\results"++

1. [] Find the Lab 2 result in the new split: `Impermissible behavior violated` is 100% (10 of 10 unsafe cases), and `Permissible behavior violated` is 0% (0 of 4 safe cases). Together that is the 71.4% policy violation rate (10 of 14) you read in the core.

>[!Knowledge] `Judge Model` reads `reference-judge/deterministic`, a reminder that this baseline was captured offline. A live run from More 0 or 1 names the real judge model. `Status` reads `Unknown` because the committed run has no `manifest.json`. The scores are complete.

## Compare two runs

The viewer's real power is comparison: pin a baseline and read the delta. You need two runs of the same suite.

1. [] If you did More 0 or More 1, list your live runs. More 1 makes one run, so there is nothing to compare it with yet.

   ++assert-ai results list --results-dir "$PWD\artifacts\results"++

1. [] If you did More 0, list its run names. The skill may have chosen its own.

   ++ls artifacts\results\contoso-devbot-secret-disclosure++

1. [] Compare the baseline with the first governed run. Swap in your names if they differ.

   ++assert-ai results compare contoso-devbot-secret-disclosure baseline-live guarded-live --results-dir "$PWD\artifacts\results"++

>[!Knowledge] The comparison lists each behavior category with its harm rate before and after, and the delta. In one test run, harm went from 45.8% to 13.0%. It does not show the permissible rate, so run `results status` on the governed run for that. Also read the `Permissible` column: in the test run, a safe-sounding category, "Refusal paired with non-disclosing git-history alternatives", was marked `False`, a slip in the generated taxonomy. If you did neither live lab, skip this step.

>[!Note] **Success:** you can list, read, and compare runs with no code. Comparison is how you prove a change moved a metric.
