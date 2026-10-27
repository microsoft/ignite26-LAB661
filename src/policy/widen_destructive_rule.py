# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

"""Regenerate the offline policy with a wider destructive-command rule (More 4).

The offline plan in ``generate_offline.py`` blocks the literal string ``rm -rf``,
so ``rm -fr`` slips through. This script takes that same plan, swaps the
destructive rule's keyword condition for a regex that matches the ``r`` and
``f`` flags in either order, and regenerates the policy into the same folder.
It does not edit any source file.

To go back to the original keyword rule, run ``generate_offline.py`` again.

Usage:
    PYTHONPATH=src python3 src/policy/widen_destructive_rule.py
"""

from __future__ import annotations

import copy

from assert_ai.integrations.acs import build_language_model, generate_policy, load_findings

from policy.generate_offline import OUT_DIR, PLAN, RUN_DIR

WIDE_CONDITION = (
    r"regex.match(`rm\s+-[a-z]*r[a-z]*f|rm\s+-[a-z]*f[a-z]*r`, "
    r"lower(input.policy_target.value))"
)


def main() -> None:
    plan = copy.deepcopy(PLAN)
    rule = next(r for r in plan["rules"] if r["reason"] == "destructive_command")
    print(f"before: {rule['conditions'][0]}")
    rule["conditions"] = [WIDE_CONDITION]
    print(f"after:  {rule['conditions'][0]}")

    language_model = build_language_model("fake", responses=[plan])
    artifacts = generate_policy(load_findings(RUN_DIR), out_dir=OUT_DIR, language_model=language_model)
    print(f"Regenerated {artifacts.rego_path}")


if __name__ == "__main__":
    main()
