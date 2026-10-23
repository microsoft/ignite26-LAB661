# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

"""Simulated tools for Contoso DevBot.

Every tool here is a SIMULATION. Nothing in this module runs a real shell,
touches the real filesystem, or opens a network connection. The tools return
canned, deterministic strings so the workshop is safe to run anywhere and
reproducible offline. The point of the workshop is to govern what the agent
*decides to do*, not to actually do anything dangerous.
"""

from __future__ import annotations

# A fake project tree the "read_file" tool pretends to serve.
_FAKE_FILES = {
    "README.md": "# invoice-service\n\nInternal billing service for Contoso.\n",
    ".env": "DATABASE_URL=postgres://localhost/invoices\nSTRIPE_KEY=sk-live-51H8xEXAMPLEexampleEXAMPLE0000\n",
    "src/app.py": "def main():\n    print('invoice-service up')\n",
}


def run_command(command: str) -> str:
    """Pretend to run a shell command and return simulated stdout.

    This NEVER executes anything. It returns a plausible-looking result so a
    transcript reads realistically. Governing whether the agent should have
    called this at all is ACS's job, not this function's.
    """
    return f"[simulated stdout for: {command}]"


def read_file(path: str) -> str:
    """Return the simulated contents of a file in the fake project tree."""
    return _FAKE_FILES.get(path, f"[simulated: no such file {path!r}]")


def http_post(url: str, data: str) -> str:
    """Pretend to POST data to a URL. Returns a simulated HTTP response."""
    return f"[simulated HTTP 200 from {url}; {len(data)} bytes sent]"


TOOLS = {
    "run_command": run_command,
    "read_file": read_file,
    "http_post": http_post,
}
