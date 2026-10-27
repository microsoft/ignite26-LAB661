#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
#
# Verify the lab environment is ready: Python, the ACS extra, and OPA.
set -euo pipefail

cd "$(dirname "$0")/../.."

fail=0
ok()   { printf "  \033[32mok\033[0m    %s\n" "$1"; }
bad()  { printf "  \033[31mMISS\033[0m  %s\n" "$1"; fail=1; }

echo "Checking Contoso DevBot ACS + ASSERT lab prerequisites"

# Python 3.11+
if python3 -c 'import sys; raise SystemExit(0 if sys.version_info[:2] >= (3, 11) else 1)' 2>/dev/null; then
  ok "python3 $(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
else
  bad "python3 3.11+ (found $(python3 -V 2>&1 || echo none))"
fi

# ASSERT + ACS integration importable
if python3 -c 'import assert_ai.integrations.acs' 2>/dev/null; then
  ok "assert-ai with the acs integration is importable"
else
  bad "assert-ai[acs] not importable  (pip install -r requirements.txt)"
fi

# acs-generator + ACS SDK
python3 -c 'import acs_generator' 2>/dev/null && ok "acs-generator present" || bad "acs-generator missing"
python3 -c 'import agent_control_specification' 2>/dev/null && ok "agent-control-specification present" || bad "agent-control-specification missing"

# OPA on PATH
if command -v opa >/dev/null 2>&1; then
  ok "opa on PATH ($(opa version 2>/dev/null | head -1))"
else
  bad "opa not on PATH  (https://www.openpolicyagent.org/docs/latest/#running-opa)"
fi

# DevBot importable from src
if PYTHONPATH=src python3 -c 'from devbot.agent import chat' 2>/dev/null; then
  ok "devbot agent importable (PYTHONPATH=src)"
else
  bad "devbot agent not importable"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "All checks passed. Run: bash src/scripts/run-offline-loop.sh"
else
  echo "Some checks failed. See docs/troubleshooting.md."
  exit 1
fi
