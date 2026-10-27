#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
"""Render the progress banners at the top of each self-paced lab.

Each banner shows the lab title and a strip of core and MORE steps with the
current lab highlighted. Edit LABS, then run from the repository root:

    python3 instructions/self-paced/media/make_banners.py            # all labs
    python3 instructions/self-paced/media/make_banners.py core-2     # one lab

Writes banner-<id>.svg next to this script. Standard library only.
"""

from __future__ import annotations

import sys
from pathlib import Path
from xml.sax.saxutils import escape

OUT_DIR = Path(__file__).resolve().parent
EYEBROW = "MICROSOFT IGNITE 2026  ·  LAB661"

# (id, label, title, subtitle). Order sets the step strip.
LABS = [
    ("core-0", "Lab 0", "Setup", "Check your environment and run the whole loop once · about 10 minutes"),
    ("core-1", "Lab 1", "Meet DevBot and map the risk", "Watch DevBot misbehave and learn the ACS vocabulary · about 10 minutes"),
    ("core-2", "Lab 2", "Evaluate with ASSERT", "Capture a baseline and read five deny targets from it · about 15 minutes"),
    ("core-3", "Lab 3", "Generate and validate an ACS policy", "Prove the policy blocks every known-bad output · about 15 minutes"),
    ("core-4", "Lab 4", "Guard, verify, and explore MORE", "Watch attack success drop from 100% to 0% · about 10 minutes"),
    ("more-0", "MORE 0", "Drive the evaluation with the run-assert-eval skill", "Optional · needs Azure · let GitHub Copilot run the loop on a real model"),
    ("more-1", "MORE 1", "Go live with a real model", "Optional · needs Azure · run the same loop by hand"),
    ("more-2", "MORE 2", "Browse runs in the ASSERT viewer", "Optional · offline · read and compare runs without code"),
    ("more-3", "MORE 3", "Author custom Rego", "Optional · offline · write and test a rule that redacts instead of blocks"),
    ("more-4", "MORE 4", "Adaptive red-teaming", "Optional · offline · find a bypass and close the gap"),
    ("more-5", "MORE 5", "Intervention points and tool calls", "Optional · offline · learn what your runtime enforces"),
    ("more-6", "MORE 6", "Gate CI on the policy", "Optional · offline · fail the build when the policy regresses"),
]

W, H = 1200, 152
FONT = "Segoe UI, Helvetica Neue, Helvetica, Arial, sans-serif"
CYAN = "#4fd8ff"
INK = "#ffffff"
SOFT = "#d9d6ff"
RING = "#6d5cff"
RAINBOW = ["#3ee87a", "#4fd8ff", "#5b8cff", "#8b5cf6", "#ec4899", "#fb923c", "#facc15"]


def step_strip(current: int) -> str:
    parts, x, y, r, gap = [], 24, 116, 11, 30
    for group in ("core", "more"):
        label = "CORE" if group == "core" else "MORE"
        parts.append(
            f'<text x="{x}" y="{y + 4}" font-family="{FONT}" font-size="10" font-weight="700" '
            f'letter-spacing="2" fill="{SOFT}" fill-opacity="0.7">{label}</text>'
        )
        x += 46
        for index, (lab_id, *_rest) in enumerate(LABS):
            if not lab_id.startswith(group):
                continue
            number = lab_id.split("-")[1]
            cx = x + r
            if index == current:
                circle = f'<circle cx="{cx}" cy="{y}" r="{r + 2}" fill="{CYAN}"/>'
                text_fill, weight = "#0b0a2e", "800"
            elif index < current:
                circle = f'<circle cx="{cx}" cy="{y}" r="{r}" fill="{INK}" fill-opacity="0.16" stroke="{RING}" stroke-width="1.2"/>'
                text_fill, weight = INK, "700"
            else:
                circle = f'<circle cx="{cx}" cy="{y}" r="{r}" fill="none" stroke="{RING}" stroke-width="1.2"/>'
                text_fill, weight = SOFT, "600"
            parts.append(circle)
            parts.append(
                f'<text x="{cx}" y="{y + 4}" text-anchor="middle" font-family="{FONT}" '
                f'font-size="11" font-weight="{weight}" fill="{text_fill}">{number}</text>'
            )
            x += gap
        x += 26
    return "\n  ".join(parts)


def render(current: int) -> str:
    _lab_id, label, title, subtitle = LABS[current]
    stops = "".join(
        f'<stop offset="{i / (len(RAINBOW) - 1):.3f}" stop-color="{c}"/>' for i, c in enumerate(RAINBOW)
    )
    heading = escape(f"{label} · {title}")
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" role="img" aria-label="{heading}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="0.4">
      <stop offset="0" stop-color="#0a0a2a"/><stop offset="0.55" stop-color="#140f5c"/><stop offset="1" stop-color="#2a1b9e"/>
    </linearGradient>
    <linearGradient id="bar" x1="0" y1="0" x2="1" y2="0">{stops}</linearGradient>
  </defs>
  <rect width="{W}" height="{H}" rx="12" fill="url(#bg)"/>
  <text x="24" y="32" font-family="{FONT}" font-size="11" font-weight="700" letter-spacing="2.6" fill="{CYAN}">{escape(EYEBROW)}</text>
  <text x="24" y="66" font-family="{FONT}" font-size="26" font-weight="700" fill="{INK}">{heading}</text>
  <text x="24" y="90" font-family="{FONT}" font-size="13.5" fill="{SOFT}">{escape(subtitle)}</text>
  {step_strip(current)}
  <rect x="24" y="137" width="{W - 48}" height="4" rx="2" fill="url(#bar)"/>
</svg>
"""


def main(selected: list[str]) -> None:
    ids = [lab[0] for lab in LABS]
    unknown = [s for s in selected if s not in ids]
    if unknown:
        sys.exit(f"Unknown lab id(s): {', '.join(unknown)}. Choose from: {', '.join(ids)}")
    for index, lab_id in enumerate(ids):
        if selected and lab_id not in selected:
            continue
        path = OUT_DIR / f"banner-{lab_id}.svg"
        path.write_text(render(index), encoding="utf-8")
        print(f"wrote {path.relative_to(Path.cwd()) if path.is_relative_to(Path.cwd()) else path}")


if __name__ == "__main__":
    main(sys.argv[1:])
