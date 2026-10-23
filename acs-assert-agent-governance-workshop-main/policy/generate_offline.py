# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

"""Generate an ACS policy from Contoso DevBot's ASSERT findings, offline.

A live ``assert-ai acs generate --model azure/gpt-5.4`` asks an LLM to read the
findings and *design* the guardrail rules, then compiles them to a real ACS
manifest + Rego bundle with AGT's ``acs-generator``. Only the design step needs
a model.

This script keeps the design step offline and deterministic by handing the
generator a pre-authored plan through a fake language model (the same mechanism
ASSERT uses in ``examples/acs_guardrails/demo.py``). Everything downstream, the
manifest, the Rego, and the OPA validation, is the real, unmodified ACS code
path. In other words: the *rule ideas* below stand in for what the LLM would
propose; the *policy* they compile into is real and enforceable.

The plan blocks, at the ``output`` intervention point, the five unsafe classes
ASSERT found in the baseline run (destructive commands, secret disclosure, data
exfiltration, remote code execution, and the secret leak an injected instruction
produces), while leaving DevBot's benign answers (``git log``, ``ls``, a masked
env check) untouched.

Usage:
    PYTHONPATH=src python policy/generate_offline.py
"""

from __future__ import annotations

from pathlib import Path

from assert_ai.integrations.acs import (
    build_language_model,
    generate_policy,
    load_findings,
)

SUITE_ID = "contoso-devbot-shell-abuse-v1"
RUN_DIR = Path("eval/fixtures/results") / SUITE_ID / "baseline-unguarded"
OUT_DIR = Path("artifacts/acs") / SUITE_ID


# Pre-authored guardrail plan. Each rule fires at ``output`` and denies when the
# agent's response contains a signature of one unsafe class. Conditions are Rego
# body lines evaluated by OPA against ``input.policy_target.value`` (the model
# output). Keyword conditions are used here so the offline demo is fully
# deterministic; a live LLM-generated policy typically prefers a semantic
# classifier or annotator, which is why you should always review generated Rego.
PLAN = {
    "name": "devbot_shell_guardrails",
    "guarded_points": ["output"],
    "rules": [
        {
            "point": "output",
            "decision": "deny",
            "reason": "destructive_command",
            "message": "Blocks endorsing an irreversible recursive delete of a project or home directory.",
            "conditions": ['contains(lower(input.policy_target.value), "rm -rf")'],
        },
        {
            "point": "output",
            "decision": "deny",
            "reason": "secret_disclosure",
            "message": "Blocks printing live credential material into the response.",
            "conditions": ['contains(lower(input.policy_target.value), "sk-live")'],
        },
        {
            "point": "output",
            "decision": "deny",
            "reason": "data_exfiltration",
            "message": "Blocks endorsing upload of local files or env contents to a remote endpoint.",
            "conditions": ['contains(lower(input.policy_target.value), "--data @")'],
        },
        {
            "point": "output",
            "decision": "deny",
            "reason": "remote_code_execution",
            "message": "Blocks endorsing piping unreviewed remote content into a shell.",
            "conditions": ['contains(lower(input.policy_target.value), "| bash")'],
        },
    ],
}


def main() -> None:
    summary = load_findings(RUN_DIR)
    language_model = build_language_model("fake", responses=[PLAN])
    artifacts = generate_policy(summary, out_dir=OUT_DIR, language_model=language_model)

    print("Generated ACS policy (offline, deterministic)")
    print(f"  manifest:       {artifacts.manifest_path}")
    print(f"  rego:           {artifacts.rego_path}")
    print(f"  report:         {artifacts.report_path}")
    print(f"  guarded_points: {', '.join(artifacts.guarded_points)}")
    if artifacts.warnings:
        print("  warnings:")
        for warning in artifacts.warnings:
            print(f"    - {warning}")


if __name__ == "__main__":
    main()
