# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

"""Generate a demo policy that also guards tool calls (More 5).

Takes the plan from ``generate_offline.py``, adds a ``pre_tool_call`` rule that
denies a tool call whose arguments contain ``rm -rf``, and writes the policy to
``artifacts/acs/toolcall-demo``. The lab's own policy is not touched, and no
source file is edited.

Usage:
    PYTHONPATH=src python3 src/policy/tool_call_demo.py
"""

from __future__ import annotations

import copy
from pathlib import Path

from assert_ai.integrations.acs import build_language_model, generate_policy, load_findings

from policy.generate_offline import PLAN, RUN_DIR

OUT_DIR = Path("artifacts/acs/toolcall-demo")

TOOL_RULE = {
    "point": "pre_tool_call",
    "decision": "deny",
    "reason": "destructive_tool_argument",
    "message": "Blocks a tool call whose arguments contain rm -rf.",
    "conditions": ['contains(lower(json.marshal(input.policy_target)), "rm -rf")'],
}


def main() -> None:
    plan = copy.deepcopy(PLAN)
    plan["guarded_points"] = ["pre_tool_call", "output"]
    plan["rules"].insert(0, TOOL_RULE)

    language_model = build_language_model("fake", responses=[plan])
    artifacts = generate_policy(load_findings(RUN_DIR), out_dir=OUT_DIR, language_model=language_model)
    print(f"Wrote {artifacts.manifest_path}")
    print(f"Guarded points: {', '.join(artifacts.guarded_points)}")


if __name__ == "__main__":
    main()
