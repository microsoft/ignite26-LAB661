#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
#
# Renders the README hero banner (img/banner.png). Not part of the workshop;
# kept so the banner can be regenerated. Run: python img/make_banner.py

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

SCALE = 2  # supersample then downscale for crisp text
W, H = 1200 * SCALE, 300 * SCALE
OUT = Path(__file__).with_name("banner.png")

SANS = "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"
SANS_B = "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"
MONO = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
MONO_B = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"

# Palette (GitHub-dark friendly)
BG_TOP = (13, 17, 23)      # #0d1117
BG_BOT = (18, 24, 38)      # #121826
INK = (240, 243, 248)      # near-white
MUTED = (139, 152, 170)    # slate
VIOLET = (167, 139, 250)   # accent for ACS
TEAL = (45, 212, 191)      # accent for ASSERT
RED = (248, 113, 113)      # danger
GREEN = (63, 185, 80)      # allow
CARD = (22, 27, 34)        # terminal card
CARD_BORDER = (48, 54, 61)


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size * SCALE)


def vgradient(w: int, h: int, top, bot) -> Image.Image:
    base = Image.new("RGB", (1, h))
    px = base.load()
    for y in range(h):
        t = y / max(1, h - 1)
        px[0, y] = tuple(round(top[i] + (bot[i] - top[i]) * t) for i in range(3))
    return base.resize((w, h))


def main() -> None:
    img = vgradient(W, H, BG_TOP, BG_BOT).convert("RGB")
    d = ImageDraw.Draw(img)

    pad = 64 * SCALE
    x = pad
    y = 60 * SCALE

    # eyebrow
    f_eye = font(SANS_B, 15)
    eyebrow = "HANDS-ON WORKSHOP"
    d.text((x, y), " ".join(eyebrow), font=f_eye, fill=TEAL)
    y += 38 * SCALE

    # title, two lines
    f_title = font(SANS_B, 52)
    d.text((x, y), "Secure a coding agent", font=f_title, fill=INK)
    y += 62 * SCALE
    line2a = "with "
    line2b = "ACS"
    line2c = " + "
    line2d = "ASSERT"
    cx = x
    d.text((cx, y), line2a, font=f_title, fill=INK); cx += d.textlength(line2a, font=f_title)
    d.text((cx, y), line2b, font=f_title, fill=VIOLET); cx += d.textlength(line2b, font=f_title)
    d.text((cx, y), line2c, font=f_title, fill=INK); cx += d.textlength(line2c, font=f_title)
    d.text((cx, y), line2d, font=f_title, fill=TEAL)
    y += 74 * SCALE

    # subtitle
    f_sub = font(SANS, 21)
    d.text((x, y), "Red-team it with ASSERT. Block what it does wrong with ACS.",
           font=f_sub, fill=MUTED)

    # terminal card on the right
    card_w = 470 * SCALE
    card_h = 188 * SCALE
    card_x = W - card_w - pad
    card_y = (H - card_h) // 2
    d.rounded_rectangle([card_x, card_y, card_x + card_w, card_y + card_h],
                        radius=14 * SCALE, fill=CARD, outline=CARD_BORDER, width=1 * SCALE)
    # window dots
    dot_y = card_y + 22 * SCALE
    for i, c in enumerate([(237, 106, 94), (245, 191, 79), (91, 194, 106)]):
        dx = card_x + 24 * SCALE + i * 26 * SCALE
        r = 6 * SCALE
        d.ellipse([dx - r, dot_y - r, dx + r, dot_y + r], fill=c)

    f_mono = font(MONO, 17)
    f_mono_b = font(MONO_B, 17)
    tx = card_x + 26 * SCALE
    ty = card_y + 52 * SCALE
    lh = 30 * SCALE

    def line(segments, yy):
        cx = tx
        for text, color, bold in segments:
            fnt = f_mono_b if bold else f_mono
            d.text((cx, yy), text, font=fnt, fill=color)
            cx += d.textlength(text, font=fnt)

    line([("$ ", MUTED, False), ('devbot "wipe my checkout"', INK, False)], ty)
    line([("  rm -rf ~/work/invoice-service", RED, False)], ty + lh)
    line([("  ", INK, False), ("x", RED, True), (" blocked by ACS", INK, False)], ty + lh * 2)
    line([("  ", INK, False), ("policy_target", MUTED, False), (" = ", MUTED, False),
          ("destructive_command", VIOLET, False)], ty + lh * 3)

    # thin accent rule under the title block, left column
    rule_y = card_y + card_h
    d.rectangle([pad, H - 26 * SCALE, pad + 210 * SCALE, H - 22 * SCALE], fill=VIOLET)

    img = img.resize((W // SCALE, H // SCALE), Image.LANCZOS)
    img.save(OUT)
    print("wrote", OUT, img.size)


if __name__ == "__main__":
    main()
