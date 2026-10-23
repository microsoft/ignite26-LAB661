#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
#
# Run the full ASSERT -> ACS protect loop end to end, offline and deterministic.
# No credentials required. This is the workshop's guaranteed spine.
set -euo pipefail

cd "$(dirname "$0")/.."
export PYTHONPATH="src${PYTHONPATH:+:$PYTHONPATH}"

hr() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }

hr "1/5  Capture the baseline ASSERT run (real agent outputs + reference judge)"
python3 eval/build_baseline_fixture.py

hr "2/5  Generate an ACS policy from the findings (offline, fake LM)"
python3 policy/generate_offline.py

hr "3/5  Validate the policy blocks every known-bad output (OPA)"
assert-ai acs validate \
  --manifest artifacts/acs/contoso-devbot-shell-abuse-v1/manifest.yaml \
  --run-dir eval/fixtures/results/contoso-devbot-shell-abuse-v1/baseline-unguarded \
  --require-block

hr "4/5  Enforce at runtime with guard_target (benign allowed, unsafe blocked)"
python3 policy/guard_demo.py

hr "5/5  Verify: attack success rate before vs after"
python3 policy/verify_reeval.py

printf '\n\033[32mLoop complete.\033[0m ASSERT found the unsafe behavior; ACS now blocks it at runtime.\n'
