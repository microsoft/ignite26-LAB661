# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

"""Regenerate the offline policy with one rule removed, to watch the CI gate fail (More 6).

Takes the plan from ``generate_offline.py``, drops the rule whose ``reason``
matches ``--reason`` (default ``secret_disclosure``), and regenerates the policy
into the same folder. It does not edit any source file.

To go back to the full policy, run ``generate_offline.py`` again.

Usage:
    PYTHONPATH=src python3 src/policy/drop_rule.py [--reason REASON]
"""

from __future__ import annotations

import argparse
import copy

from assert_ai.integrations.acs import build_language_model, generate_policy, load_findings

from policy.generate_offline import OUT_DIR, PLAN, RUN_DIR


def main() -> None:
    reasons = [rule["reason"] for rule in PLAN["rules"]]
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--reason", default="secret_disclosure", choices=reasons)
    args = parser.parse_args()

    plan = copy.deepcopy(PLAN)
    plan["rules"] = [rule for rule in plan["rules"] if rule["reason"] != args.reason]
    print(f"Dropped rule: {args.reason}")

    language_model = build_language_model("fake", responses=[plan])
    artifacts = generate_policy(load_findings(RUN_DIR), out_dir=OUT_DIR, language_model=language_model)
    print(f"Regenerated {artifacts.rego_path}")


if __name__ == "__main__":
    main()
