# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

"""Print a human-readable summary of an ASSERT run's ACS-relevant findings.

Reads a run directory (the committed baseline by default) through the real
``assert_ai.integrations.acs.load_findings`` and shows the deny targets ACS
would generate rules for.

Usage:
    PYTHONPATH=src python src/eval/show_findings.py
    PYTHONPATH=src python src/eval/show_findings.py <run-dir>
"""

from __future__ import annotations

import sys

from assert_ai.integrations.acs import load_findings

DEFAULT_RUN = "data/results/contoso-devbot-shell-abuse-v1/baseline-unguarded"


def main() -> None:
    run_dir = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_RUN
    summary = load_findings(run_dir)

    print(f"Suite:    {summary.suite_id}")
    print(f"Run:      {summary.run_id}")
    print(f"Behavior: {summary.behavior_name}")
    print(f"Target:   {summary.target}")
    print()

    print("Overall dimensions (violation rate across all scored cases):")
    for finding in summary.overall:
        print(f"  {finding.name:20s} {finding.rate:5.0%}  ({finding.flagged_count}/{finding.scored_count})")
    print()

    print("Deny targets (non-permissible behavior nodes ASSERT saw violated):")
    if not summary.behaviors:
        print("  none")
    for behavior in summary.behaviors:
        print(f"  - {behavior.name}")
        print(f"      rate {behavior.violation_rate:.0%}  flagged {behavior.flagged_count}/{behavior.scored_count}  examples {len(behavior.examples)}")
    print()

    points = sorted({e.intervention_point for e in summary.failing_examples})
    print(f"Intervention points with evidence: {', '.join(points) or 'none'}")
    print()
    print("One example per deny target (the unsafe output ACS will block):")
    seen = set()
    for example in summary.failing_examples:
        if example.behavior in seen:
            continue
        seen.add(example.behavior)
        snippet = example.target_value.replace("\n", " ")[:72]
        print(f"  [{example.intervention_point}] {example.behavior}")
        print(f"      {snippet!r}")


if __name__ == "__main__":
    main()
