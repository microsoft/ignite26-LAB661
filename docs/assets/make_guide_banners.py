#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
"""Render the part banners for docs/developer-guide.ipynb.

Same look as the self-paced lab banners. Part banners show a strip of the
guide's parts with the current one highlighted; question banners headline each
developer question. Run from the repository root:

    python3 docs/assets/make_guide_banners.py

Writes guide-<n>.svg and q-<part>-<n>.svg beside this file. Standard library only.
"""

from __future__ import annotations

import importlib.util
from pathlib import Path
from xml.sax.saxutils import escape

OUT_DIR = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location(
    "make_banners", OUT_DIR.parents[1] / "instructions/self-paced/assets/make_banners.py"
)
lab = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(lab)

EYEBROW = "MICROSOFT IGNITE 2026  ·  LAB661  ·  DEVELOPER GUIDE"

# (number, title, subtitle). Part 0 is the introduction and highlights no step.
PARTS = [
    ("0", "How to read this guide", "A recorded walkthrough · real commands, real output, and the nuances behind them"),
    ("1", "Environment check", "Confirm every tool the lab needs is installed"),
    ("2", "Core labs, offline", "Lab 0 to Lab 4 · baseline, policy, gate, guard, and measure"),
    ("3", "Live setup", "Provision Foundry, write .env, and make a first live call"),
    ("4", "More 0 · the run-assert-eval skill", "Gates, research, rate limits, results, and governing the failure"),
    ("5", "More 1 · the loop by hand", "A live evaluation and a model-designed policy that cannot fire"),
    ("6", "More 2 to 6 · offline bonus labs", "Browse runs, custom Rego, red-teaming, intervention points, CI gate"),
    ("7", "Troubleshooting index", "Every symptom seen in the walkthrough, with its cause and fix"),
    ("8", "Open issues for upstream", "Gaps to report to ASSERT and the ACS generator"),
]

# (id, question). The id's first number is the part it belongs to.
QUESTIONS = [
    ("0.1", "What is this lab about?"),
    ("0.2", "Why is governing an agent hard?"),
    ("0.3", "What do the key terms mean?"),
    ("0.4", "How do the pieces fit together?"),
    ("0.5", "How should I read this guide?"),
    ("1.1", "Is my environment ready?"),
    ("2.1", "Does the whole loop work end to end?"),
    ("2.2", "What does an ungoverned agent actually do?"),
    ("2.3", "How do I turn a hunch into a measurement?"),
    ("2.4", "How do I turn findings into a policy?"),
    ("2.5", "How do I prove the policy blocks the bad outputs?"),
    ("2.6", "What happens when the policy regresses?"),
    ("2.7", "Does the policy work at runtime, and by how much?"),
    ("3.1", "How do I connect the lab to a real model?"),
    ("3.2", "How do I know DevBot is really live?"),
    ("4.1", "What will the skill ask me?"),
    ("4.2", "How does the skill design the evaluation?"),
    ("4.3", "Why did the first run fail on a missing module?"),
    ("4.4", "What commands does the skill actually run?"),
    ("4.5", "Why is it so slow, and how do I speed it up?"),
    ("4.6", "Where did my results go?"),
    ("4.7", "How unsafe is the live DevBot?"),
    ("4.8", "How does the skill fix it, and did the fix work?"),
    ("4.9", "When should I stop the skill?"),
    ("5.1", "How do I run the evaluation by hand?"),
    ("5.2", "Why do my numbers change between runs?"),
    ("5.3", "Can I trust a policy a model designed?"),
    ("6.1", "How do I browse and compare runs?"),
    ("6.2", "Can I write my own rule?"),
    ("6.3", "How easy is it to slip past a keyword rule?"),
    ("6.4", "Which intervention points does my runtime enforce?"),
    ("6.5", "How do I stop a regression from shipping?"),
    ("7.1", "Something broke. Where do I look?"),
    ("8.1", "What should we report upstream?"),
]

QH = 96


def step_strip(current: int) -> str:
    parts, x, y, r, gap = [], 24, 116, 11, 30
    parts.append(
        f'<text x="{x}" y="{y + 4}" font-family="{lab.FONT}" font-size="10" font-weight="700" '
        f'letter-spacing="2" fill="{lab.SOFT}" fill-opacity="0.7">Part</text>'
    )
    x += 46
    for index, (number, *_rest) in enumerate(PARTS[1:], start=1):
        cx = x + r
        if index == current:
            circle = f'<circle cx="{cx}" cy="{y}" r="{r + 2}" fill="{lab.CYAN}"/>'
            text_fill, weight = "#0b0a2e", "800"
        elif index < current:
            circle = f'<circle cx="{cx}" cy="{y}" r="{r}" fill="{lab.INK}" fill-opacity="0.16" stroke="{lab.RING}" stroke-width="1.2"/>'
            text_fill, weight = lab.INK, "700"
        else:
            circle = f'<circle cx="{cx}" cy="{y}" r="{r}" fill="none" stroke="{lab.RING}" stroke-width="1.2"/>'
            text_fill, weight = lab.SOFT, "600"
        parts.append(circle)
        parts.append(
            f'<text x="{cx}" y="{y + 4}" text-anchor="middle" font-family="{lab.FONT}" '
            f'font-size="11" font-weight="{weight}" fill="{text_fill}">{number}</text>'
        )
        x += gap
    return "\n  ".join(parts)


def render(current: int) -> str:
    number, title, subtitle = PARTS[current]
    stops = "".join(
        f'<stop offset="{i / (len(lab.RAINBOW) - 1):.3f}" stop-color="{c}"/>' for i, c in enumerate(lab.RAINBOW)
    )
    heading = escape(title if current == 0 else f"Part {number} · {title}")
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{lab.W}" height="{lab.H}" viewBox="0 0 {lab.W} {lab.H}" role="img" aria-label="{heading}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="0.4">
      <stop offset="0" stop-color="#0a0a2a"/><stop offset="0.55" stop-color="#140f5c"/><stop offset="1" stop-color="#2a1b9e"/>
    </linearGradient>
    <linearGradient id="bar" x1="0" y1="0" x2="1" y2="0">{stops}</linearGradient>
  </defs>
  <rect width="{lab.W}" height="{lab.H}" rx="12" fill="url(#bg)"/>
  <text x="24" y="32" font-family="{lab.FONT}" font-size="11" font-weight="700" letter-spacing="2.6" fill="{lab.CYAN}">{escape(EYEBROW)}</text>
  <text x="24" y="66" font-family="{lab.FONT}" font-size="26" font-weight="700" fill="{lab.INK}">{heading}</text>
  <text x="24" y="90" font-family="{lab.FONT}" font-size="13.5" fill="{lab.SOFT}">{escape(subtitle)}</text>
  {step_strip(current)}
  <rect x="24" y="137" width="{lab.W - 48}" height="4" rx="2" fill="url(#bar)"/>
</svg>
"""


def render_question(qid: str, question: str) -> str:
    part = PARTS[int(qid.split(".")[0])]
    eyebrow = escape(f"QUESTION {qid}  ·  PART {part[0]}  ·  {part[1].upper()}")
    color = lab.RAINBOW[int(qid.split(".")[0]) % len(lab.RAINBOW)]
    stops = "".join(
        f'<stop offset="{i / (len(lab.RAINBOW) - 1):.3f}" stop-color="{c}"/>' for i, c in enumerate(lab.RAINBOW)
    )
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{lab.W}" height="{QH}" viewBox="0 0 {lab.W} {QH}" role="img" aria-label="Question {qid}: {escape(question)}">
  <defs>
    <linearGradient id="qbg" x1="0" y1="0" x2="1" y2="0.4">
      <stop offset="0" stop-color="#0a0a2a"/><stop offset="1" stop-color="#140f5c"/>
    </linearGradient>
    <linearGradient id="qbar" x1="0" y1="0" x2="1" y2="0">{stops}</linearGradient>
  </defs>
  <rect width="{lab.W}" height="{QH}" rx="12" fill="url(#qbg)"/>
  <rect x="0" y="0" width="8" height="{QH}" rx="4" fill="{color}"/>
  <text x="28" y="30" font-family="{lab.FONT}" font-size="11" font-weight="700" letter-spacing="2.4" fill="{color}">{eyebrow}</text>
  <text x="28" y="64" font-family="{lab.FONT}" font-size="24" font-weight="700" fill="{lab.INK}">{escape(question)}</text>
  <rect x="28" y="{QH - 12}" width="{lab.W - 56}" height="3" rx="1.5" fill="url(#qbar)" fill-opacity="0.85"/>
</svg>
"""


def main() -> None:
    for index, (number, *_rest) in enumerate(PARTS):
        path = OUT_DIR / f"guide-{number}.svg"
        path.write_text(render(index), encoding="utf-8")
    for qid, question in QUESTIONS:
        (OUT_DIR / f"q-{qid.replace('.', '-')}.svg").write_text(render_question(qid, question), encoding="utf-8")
    print(f"wrote {len(PARTS)} part banners and {len(QUESTIONS)} question banners to {OUT_DIR.name}/")


if __name__ == "__main__":
    main()
