#!/usr/bin/env python3
"""Draws the Annals' art as SVG: profile busts and full-body figures of the ten paths, and the items
of the house. Illuminated-manuscript colour (gold leaf, madder, woad, verdigris) on a tapestry field.
No text is drawn in the art; names are set in the game's UI font.

python3 tools/art/make_art.py   (writes assets/art/*.svg)
"""
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "art")
INK = "#2a1d14"
GOLD = "#c9a14a"
PARCH = "#e9dcbf"
SKIN = "#e6bd93"
SKIN_SH = "#c99a70"
BLUSH = "#d98f74"
STEEL = "#8a8f96"
WOOD = "#7a4f2a"


def mix(hex_a, hex_b, t):
    a = [int(hex_a[i:i + 2], 16) for i in (1, 3, 5)]
    b = [int(hex_b[i:i + 2], 16) for i in (1, 3, 5)]
    return "#%02x%02x%02x" % tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def lighter(hex_c, t=0.35):
    return mix(hex_c, "#ffffff", t)


def darker(hex_c, t=0.35):
    return mix(hex_c, "#000000", t)


def defs_common():
    """Gradients shared by every piece: gold leaf, steel, skin and parchment."""
    return ('<defs>'
            f'<linearGradient id="gold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f3dc92"/>'
            f'<stop offset="0.55" stop-color="{GOLD}"/><stop offset="1" stop-color="#8a6320"/></linearGradient>'
            f'<linearGradient id="steel" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#eef1f4"/>'
            f'<stop offset="0.5" stop-color="{STEEL}"/><stop offset="1" stop-color="#4b5058"/></linearGradient>'
            f'<linearGradient id="skin" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f4d8b6"/>'
            f'<stop offset="1" stop-color="{SKIN}"/></linearGradient>'
            f'<linearGradient id="parch" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f4ead2"/>'
            f'<stop offset="1" stop-color="{PARCH}"/></linearGradient>'
            '</defs>')


def robe_grad(gid, c):
    return (f'<linearGradient id="{gid}" x1="0" y1="0" x2="1" y2="0">'
            f'<stop offset="0" stop-color="{lighter(c, 0.18)}"/><stop offset="0.45" stop-color="{c}"/>'
            f'<stop offset="1" stop-color="{darker(c, 0.35)}"/></linearGradient>')


def emb_pattern():
    return ('<pattern id="emb" width="12" height="12" patternUnits="userSpaceOnUse">'
            f'<rect width="12" height="12" fill="{darker(GOLD, 0.2)}"/>'
            '<path d="M6 1 L11 6 L6 11 L1 6 Z" fill="url(#gold)"/>'
            f'<circle cx="6" cy="6" r="1.3" fill="{INK}"/></pattern>')


def field_shapes(w, h, step, bg, accent):
    """The tapestry field drawn as plain shapes: diamonds on a grid with a gold seed at each crossing.
    Patterns are not used, because Godot's SVG renderer does not draw pattern fills."""
    r = step / 2 - 1
    out = [f'<rect width="{w}" height="{h}" fill="{bg}"/>']
    dark = darker(accent, 0.15)
    light = lighter(accent, 0.12)
    for j in range(0, h + step, step):
        for i in range(0, w + step, step):
            out.append(f'<path d="M{i} {j-r} L{i+r} {j} L{i} {j+r} L{i-r} {j} Z" fill="{dark}" opacity="0.6"/>')
            out.append(f'<path d="M{i} {j-r/2} L{i+r/2} {j} L{i} {j+r/2} L{i-r/2} {j} Z" fill="{light}" opacity="0.4"/>')
            out.append(f'<circle cx="{i}" cy="{j}" r="2.4" fill="url(#gold)"/>')
    return "".join(out)


def frame(w, h, bg, accent):
    """A tapestry field of diamonds, a knotwork band, and gold roundels at the corners."""
    s = [field_shapes(w, h, 32, bg, accent)]
    s.append(f'<rect x="0" y="0" width="{w}" height="{h}" fill="#000" opacity="0.12"/>')
    s.append(f'<rect x="5" y="5" width="{w-10}" height="{h-10}" fill="none" stroke="url(#gold)" stroke-width="7"/>')
    s.append(f'<rect x="14" y="14" width="{w-28}" height="{h-28}" fill="none" stroke="{INK}" stroke-width="2"/>')
    # Knotwork: a twisted band of S-curves along each side.
    band = []
    step = 12
    for x in range(22, w - 21, step):
        band.append(f'M{x} 22 q6 -5 12 0 t12 0')
        band.append(f'M{x} {h-22} q6 5 12 0 t12 0')
    for y in range(22, h - 21, step):
        band.append(f'M22 {y} q-5 6 0 12 t0 12')
        band.append(f'M{w-22} {y} q5 6 0 12 t0 12')
    s.append(f'<path d="{" ".join(band)}" fill="none" stroke="{GOLD}" stroke-width="2" opacity="0.8"/>')
    for x, y in ((12, 12), (w - 12, 12), (12, h - 12), (w - 12, h - 12)):
        s.append(f'<circle cx="{x}" cy="{y}" r="10" fill="url(#gold)" stroke="{INK}" stroke-width="2"/>')
        s.append(f'<circle cx="{x}" cy="{y}" r="4" fill="{accent}" stroke="{INK}" stroke-width="1.5"/>')
    return "".join(s)


def svg(w, h, body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}">'
            f'{body}</svg>')


def face(hair, hair_color, beard=None):
    """A face in three-quarter view, centred on (0,0), about 90 units tall."""
    g = []
    # Head shape with a shaded side.
    g.append(f'<ellipse cx="0" cy="0" rx="34" ry="42" fill="url(#skin)" stroke="{INK}" stroke-width="3.5"/>')
    g.append(f'<path d="M14 -30 Q34 -8 30 18 Q26 36 8 40 Q22 22 20 0 Q20 -20 14 -30 Z" fill="{SKIN_SH}" opacity="0.45"/>')
    # Cheeks and jaw.
    g.append(f'<ellipse cx="-19" cy="12" rx="8" ry="6" fill="{BLUSH}" opacity="0.4"/>')
    g.append(f'<ellipse cx="19" cy="12" rx="8" ry="6" fill="{BLUSH}" opacity="0.4"/>')
    g.append(f'<path d="M-8 37 Q0 41 8 37" fill="none" stroke="{SKIN_SH}" stroke-width="2" opacity="0.7"/>')
    # Eyes: white, iris, pupil, highlight and a lid line.
    for cx in (-13, 13):
        g.append(f'<ellipse cx="{cx}" cy="-4" rx="6" ry="3.6" fill="#fbf4e4" stroke="{INK}" stroke-width="1.2"/>')
        g.append(f'<circle cx="{cx}" cy="-4" r="2.6" fill="#4a3320"/>')
        g.append(f'<circle cx="{cx}" cy="-4" r="1.1" fill="{INK}"/>')
        g.append(f'<circle cx="{cx + 0.9}" cy="-5" r="0.6" fill="#ffffff"/>')
        g.append(f'<path d="M{cx-6.5} -4.5 Q{cx} -9 {cx+6.5} -4.5" fill="none" stroke="{INK}" stroke-width="1.8" stroke-linecap="round"/>')
    # Brows, tapered by two strokes.
    g.append(f'<path d="M-20 -13 Q-13 -18 -5 -13" fill="none" stroke="{INK}" stroke-width="2.6" stroke-linecap="round"/>')
    g.append(f'<path d="M5 -13 Q13 -18 20 -13" fill="none" stroke="{INK}" stroke-width="2.6" stroke-linecap="round"/>')
    # Nose: a bridge line, a shaded side, and nostrils.
    g.append(f'<path d="M1 -2 Q5 7 1 13 Q-2 15 -5 13" fill="none" stroke="{INK}" stroke-width="2" stroke-linecap="round"/>')
    g.append(f'<path d="M3 0 Q7 8 3 13 Q6 10 5 2 Z" fill="{SKIN_SH}" opacity="0.55"/>')
    # Mouth: a single simple smile line, no fill.
    g.append('<path d="M-8 25 Q0 30 8 25" fill="none" stroke="#2a1d14" stroke-width="2.2" stroke-linecap="round"/>')
    if beard:
        g.append(f'<path d="M-30 12 Q-27 48 0 50 Q27 48 30 12 Q24 30 0 33 Q-24 30 -30 12 Z" fill="{beard}" stroke="{darker(beard, 0.4)}" stroke-width="1.5"/>')
        g.append(f'<path d="M-14 36 Q0 40 14 36" fill="none" stroke="{lighter(beard, 0.2)}" stroke-width="1.5" opacity="0.7"/>')
    if hair:
        g.append(f'<path d="M-37 -10 Q-42 -50 0 -52 Q42 -50 37 -10 Q31 -28 18 -32 Q0 -22 -18 -32 Q-31 -28 -37 -10 Z" fill="{hair_color}" stroke="{INK}" stroke-width="3"/>')
        for x in (-24, -12, 0, 12, 24):
            g.append(f'<path d="M{x} -34 Q{x*0.6} -26 {x*0.8} -18" fill="none" stroke="{darker(hair_color, 0.3)}" stroke-width="1.2" opacity="0.7"/>')
    return "".join(g)


def headgear(kind, color, accent):
    """Headwear drawn over the top of the face, centred on (0,0)."""
    if kind == "cowl":
        return (f'<path d="M-46 14 Q-52 -62 0 -66 Q52 -62 46 14 L40 30 Q34 -22 0 -26 Q-34 -22 -40 30 Z" '
                f'fill="{color}" stroke="{INK}" stroke-width="4"/>')
    if kind == "tonsure":
        return (f'<path d="M-40 -6 Q-42 -46 0 -48 Q42 -46 40 -6 Q34 -22 0 -24 Q-34 -22 -40 -6 Z" fill="{color}" stroke="{INK}" stroke-width="3"/>'
                f'<circle cx="0" cy="-40" r="9" fill="url(#skin)" stroke="{INK}" stroke-width="2"/>')
    if kind == "helm":
        return (f'<path d="M-44 6 Q-46 -60 0 -62 Q46 -60 44 6 L38 6 L38 -4 Q0 -20 -38 -4 L-38 6 Z" fill="{color}" stroke="{INK}" stroke-width="4"/>'
                f'<path d="M-6 -18 L-6 14 L6 14 L6 -18 Z" fill="{accent}" stroke="{INK}" stroke-width="2"/>')
    if kind == "cap":
        return (f'<path d="M-40 -6 Q-42 -50 0 -52 Q42 -50 40 -6 Q30 -18 0 -18 Q-30 -18 -40 -6 Z" fill="{color}" stroke="{INK}" stroke-width="4"/>'
                f'<path d="M-40 -8 Q0 -2 40 -8" fill="none" stroke="{accent}" stroke-width="4"/>')
    if kind == "coif":
        # A linen coif: a band over the crown and the sides, leaving the face open.
        return (f'<path d="M-42 -2 Q-46 -56 0 -58 Q46 -56 42 -2 Q34 -24 0 -26 Q-34 -24 -42 -2 Z" fill="{color}" stroke="{INK}" stroke-width="4"/>'
                f'<path d="M-40 -2 Q-44 16 -36 30 M40 -2 Q44 16 36 30" fill="none" stroke="{color}" stroke-width="10" stroke-linecap="round"/>')
    if kind == "biretta":
        return (f'<path d="M-36 -18 L-30 -48 Q0 -60 30 -48 L36 -18 Z" fill="{color}" stroke="{INK}" stroke-width="3"/>'
                f'<path d="M-40 -16 Q0 -8 40 -16" fill="none" stroke="{INK}" stroke-width="5"/>')
    if kind == "brim":
        return (f'<ellipse cx="0" cy="-22" rx="78" ry="16" fill="{color}" stroke="{INK}" stroke-width="4"/>'
                f'<path d="M-36 -22 Q-36 -66 0 -66 Q36 -66 36 -22 Z" fill="{accent}" stroke="{INK}" stroke-width="4"/>')
    if kind == "feather":
        return (f'<path d="M-40 -6 Q-42 -50 0 -52 Q42 -50 40 -6 Q30 -18 0 -18 Q-30 -18 -40 -6 Z" fill="{color}" stroke="{INK}" stroke-width="4"/>'
                f'<path d="M22 -40 Q48 -56 60 -28 Q42 -36 22 -40 Z" fill="{accent}" stroke="{INK}" stroke-width="2"/>')
    if kind == "cap_tall":
        return (f'<path d="M-30 -12 Q-30 -62 0 -62 Q30 -62 30 -12 Z" fill="{color}" stroke="{INK}" stroke-width="4"/>'
                f'<path d="M-40 -12 Q0 -4 40 -12 Q40 -2 0 2 Q-40 -2 -40 -12 Z" fill="{accent}" stroke="{INK}" stroke-width="2"/>')
    return ""


# The ten paths: colours, headgear, hair, beard, background field, accent and the house symbol.
PATHS = {
    "monk":       dict(robe="#5a3f2a", trim=GOLD, head="tonsure", head_col="#4a3322", hair=False, beard=None,
                       bg="#2f5d50", accent="#4f8a74", symbol="rosary"),
    "priest":     dict(robe="#2e4a7a", trim=PARCH, head="biretta", head_col="#1e2a40", hair=True, hair_col="#7a7a7a", beard=None,
                       bg="#6e2a26", accent="#a04a3e", symbol="cross"),
    "householder": dict(robe="#6b7a3a", trim=GOLD, head="cap", head_col="#8a3a2a", hair=True, hair_col="#6a4a2a", beard="#6a4a2a",
                       bg="#7a5f22", accent="#a7862e", symbol="bread"),
    "soldier":    dict(robe="#b0503c", trim=GOLD, head="helm", head_col=STEEL, hair=False, beard=None,
                       bg="#3a3f4a", accent="#5b6270", symbol="shield"),
    "hunter":     dict(robe="#3f5a3a", trim=GOLD, head="feather", head_col="#5a6a3a", hair=True, hair_col="#5a3a22", beard=None,
                       bg="#263a26", accent="#4a6a46", symbol="bow"),
    "healer":     dict(robe="#3a6f6a", trim=PARCH, head="coif", head_col=PARCH, hair=False, beard=None,
                       bg="#24474a", accent="#3f7a78", symbol="herb"),
    "scribe":     dict(robe="#2a2119", trim=GOLD, head="cap", head_col="#15110d", hair=True, hair_col="#9a9a9a", beard=None,
                       bg="#24304a", accent="#3d4f78", symbol="quill"),
    "builder":    dict(robe="#8a5a3a", trim=GOLD, head="brim", head_col="#6a4a2a", hair=True, hair_col="#5a3a22", beard=None,
                       bg="#6a2a22", accent="#8a3e32", symbol="hammer"),
    "cook":       dict(robe="#d8cfb8", trim=GOLD, head="cap_tall", head_col="#f2ead6", hair=False, beard=None,
                       bg="#5a4020", accent="#7a5a30", symbol="ladle"),
    "pilgrim":    dict(robe="#7a6a4a", trim=GOLD, head="brim", head_col="#8a6a3a", hair=True, hair_col="#8a7a5a", beard="#8a7a5a",
                       bg="#2f4f5f", accent="#4a6f7f", symbol="shell"),
}


def head_group(p, spec, scale):
    """The head: a face under its headgear, drawn at a given scale around (0,0)."""
    hair_col = spec.get("hair_col", "#000")
    f = face(spec["hair"], hair_col, spec["beard"])
    if spec["head"] == "tonsure":
        f = face(False, hair_col, None) + headgear("tonsure", spec["head_col"], spec["trim"])
        return f'<g transform="scale({scale})">{f}</g>'
    hg = headgear(spec["head"], spec["head_col"], spec["trim"])
    if spec["head"] == "cowl":
        f = face(False, hair_col, None) + hg
    elif spec["head"] in ("helm", "coif"):
        f = face(False, hair_col, None) + hg
    else:
        f = face(spec["hair"], hair_col, spec["beard"]) + hg
    return f'<g transform="scale({scale})">{f}</g>'


def symbol(kind, x, y, s=1.0):
    """A small house symbol for the chest or the hand."""
    if kind == "rosary":
        beads = "".join(f'<circle cx="{round(math_cos(t)*34, 1)}" cy="{round(math_sin(t)*34 + 10, 1)}" r="3.5" fill="url(#gold)" stroke="{INK}" stroke-width="1"/>'
                        for t in [i * 6.2832 / 14 for i in range(14)])
        return f'<g transform="translate({x} {y}) scale({s})">{beads}<circle cx="0" cy="44" r="5" fill="url(#gold)" stroke="{INK}" stroke-width="2"/></g>'
    if kind == "cross":
        return (f'<g transform="translate({x} {y}) scale({s})"><rect x="-6" y="-26" width="12" height="52" fill="url(#gold)" stroke="{INK}" stroke-width="2"/>'
                f'<rect x="-22" y="-12" width="44" height="10" fill="url(#gold)" stroke="{INK}" stroke-width="2"/></g>')
    return f'<g transform="translate({x} {y}) scale({s})">{item(kind)}</g>'


def math_cos(t):
    import math
    return math.cos(t)


def math_sin(t):
    import math
    return math.sin(t)


def portrait(pid):
    p = PATHS[pid]
    body = [defs_common() + "<defs>" + robe_grad("robe", p["robe"]) + "</defs>",
            frame(256, 256, p["bg"], p["accent"])]
    body.append(f'<path d="M34 256 Q34 186 96 170 L160 170 Q222 186 222 256 Z" fill="url(#robe)" stroke="{INK}" stroke-width="5"/>')
    body.append(f'<path d="M96 170 Q128 196 160 170" fill="none" stroke="url(#gold)" stroke-dasharray="7 3" stroke-width="9"/>')
    body.append(f'<path d="M40 252 Q44 214 96 204" fill="none" stroke="{darker(p["robe"], 0.45)}" stroke-width="2.5" opacity="0.5"/>')
    body.append(f'<path d="M216 252 Q212 214 160 204" fill="none" stroke="{darker(p["robe"], 0.45)}" stroke-width="2.5" opacity="0.5"/>')
    body.append(f'<rect x="112" y="136" width="32" height="40" fill="{SKIN_SH}" stroke="{INK}" stroke-width="3"/>')
    body.append(head_group(p, p, 1.0).replace('<g transform="scale(1.0)">', '<g transform="translate(128 112)">'))
    body.append(symbol(p["symbol"], 128, 226, 0.85))
    return svg(256, 256, "".join(body))


def figure(pid):
    p = PATHS[pid]
    body = [defs_common() + "<defs>" + robe_grad("robe", p["robe"]) + "</defs>",
            frame(256, 512, p["bg"], p["accent"])]
    # legs and feet under the robe
    body.append(f'<rect x="102" y="420" width="24" height="60" fill="{INK}"/><rect x="130" y="420" width="24" height="60" fill="{INK}"/>')
    body.append(f'<ellipse cx="112" cy="484" rx="16" ry="8" fill="{WOOD}" stroke="{INK}" stroke-width="3"/>'
                f'<ellipse cx="144" cy="484" rx="16" ry="8" fill="{WOOD}" stroke="{INK}" stroke-width="3"/>')
    # the robe, flaring to the hem
    body.append(f'<path d="M92 168 L164 168 Q186 260 194 426 L62 426 Q70 260 92 168 Z" fill="url(#robe)" stroke="{INK}" stroke-width="5"/>')
    body.append(f'<path d="M62 426 L194 426" stroke="url(#gold)" stroke-dasharray="7 3" stroke-width="11"/>')
    body.append(f'<path d="M128 176 L128 420" stroke="url(#gold)" stroke-width="4" opacity="0.7"/>')
    for x0, x1 in ((112, 104), (144, 152)):
        body.append(f'<path d="M{x0} 200 Q{x1} 300 {x0 - 6 if x0 < 128 else x0 + 6} 420" fill="none" stroke="{darker(p["robe"], 0.45)}" stroke-width="3" opacity="0.5"/>')
    body.append(f'<path d="M96 178 L160 178" stroke="url(#gold)" stroke-dasharray="7 3" stroke-width="9"/>')
    # arms
    body.append(f'<path d="M92 180 Q66 260 80 332 L98 326 Q90 264 110 196 Z" fill="url(#robe)" stroke="{INK}" stroke-width="4"/>')
    body.append(f'<path d="M164 180 Q190 260 178 330 L160 326 Q168 264 146 196 Z" fill="url(#robe)" stroke="{INK}" stroke-width="4"/>')
    body.append(f'<circle cx="89" cy="334" r="9" fill="url(#skin)" stroke="{INK}" stroke-width="3"/>')
    body.append(f'<circle cx="169" cy="332" r="9" fill="url(#skin)" stroke="{INK}" stroke-width="3"/>')
    # head at the top
    body.append(f'<g transform="translate(128 112)">{head_group(p, p, 0.82).replace(chr(60)+"g transform=\"scale(0.82)\">", "")}</g>'
                .replace('</g></g>', '</g>'))
    # the house item in the right hand
    body.append(f'<g transform="translate(160 292) scale(0.85)">{item(p["symbol"])}</g>' if p["symbol"] not in ("rosary", "cross") else symbol(p["symbol"], 128, 260, 1.0))
    return svg(256, 512, "".join(body))


def item(kind):
    """The house items, drawn in a 128 box. Used alone and in the figures' hands."""
    if kind == "bread":
        return (f'<ellipse cx="64" cy="72" rx="40" ry="24" fill="#c58a4a" stroke="{INK}" stroke-width="4"/>'
                f'<path d="M44 66 Q64 52 84 66" fill="none" stroke="{INK}" stroke-width="3"/>')
    if kind == "candle":
        return (f'<rect x="56" y="50" width="16" height="56" fill="url(#parch)" stroke="{INK}" stroke-width="3"/>'
                f'<path d="M64 24 Q76 42 64 52 Q52 42 64 24 Z" fill="url(#gold)" stroke="{INK}" stroke-width="2"/>')
    if kind == "book":
        return (f'<rect x="30" y="38" width="68" height="52" rx="3" fill="#7a2e2a" stroke="{INK}" stroke-width="4"/>'
                f'<rect x="36" y="44" width="56" height="40" fill="url(#parch)"/>'
                f'<rect x="60" y="38" width="8" height="52" fill="url(#gold)" stroke="{INK}" stroke-width="2"/>')
    if kind == "cross":
        return (f'<rect x="56" y="22" width="16" height="84" fill="url(#gold)" stroke="{INK}" stroke-width="3"/>'
                f'<rect x="34" y="42" width="60" height="16" fill="url(#gold)" stroke="{INK}" stroke-width="3"/>')
    if kind == "bell":
        return (f'<path d="M38 88 Q38 38 64 34 Q90 38 90 88 L98 100 L30 100 Z" fill="url(#gold)" stroke="{INK}" stroke-width="4"/>'
                f'<circle cx="64" cy="106" r="7" fill="{INK}"/>')
    if kind == "grain":
        out = [f'<path d="M64 118 L64 26" stroke="#b8862e" stroke-width="4" fill="none"/>']
        for i, y in enumerate((36, 52, 68, 84)):
            out.append(f'<ellipse cx="54" cy="{y}" rx="8" ry="5" fill="#d9a84a" stroke="{INK}" stroke-width="2" transform="rotate(-30 54 {y})"/>')
            out.append(f'<ellipse cx="74" cy="{y}" rx="8" ry="5" fill="#d9a84a" stroke="{INK}" stroke-width="2" transform="rotate(30 74 {y})"/>')
        out.append(f'<ellipse cx="64" cy="22" rx="6" ry="9" fill="#d9a84a" stroke="{INK}" stroke-width="2"/>')
        return "".join(out)
    if kind == "fish":
        return (f'<ellipse cx="60" cy="64" rx="34" ry="18" fill="#5d7f8a" stroke="{INK}" stroke-width="4"/>'
                f'<path d="M90 64 L116 46 L116 82 Z" fill="#5d7f8a" stroke="{INK}" stroke-width="4"/>'
                f'<circle cx="42" cy="60" r="3.5" fill="{INK}"/>')
    if kind == "herb":
        return (f'<path d="M64 116 L64 36" stroke="#3f6b3a" stroke-width="4" fill="none"/>'
                f'<ellipse cx="50" cy="56" rx="13" ry="7" fill="#5f9a52" stroke="{INK}" stroke-width="2" transform="rotate(-35 50 56)"/>'
                f'<ellipse cx="78" cy="56" rx="13" ry="7" fill="#5f9a52" stroke="{INK}" stroke-width="2" transform="rotate(35 78 56)"/>'
                f'<ellipse cx="50" cy="84" rx="13" ry="7" fill="#5f9a52" stroke="{INK}" stroke-width="2" transform="rotate(-35 50 84)"/>'
                f'<ellipse cx="78" cy="84" rx="13" ry="7" fill="#5f9a52" stroke="{INK}" stroke-width="2" transform="rotate(35 78 84)"/>'
                f'<ellipse cx="64" cy="30" rx="6" ry="9" fill="#7fb36c" stroke="{INK}" stroke-width="2"/>')
    if kind == "log":
        return (f'<rect x="22" y="56" width="84" height="26" rx="10" fill="{WOOD}" stroke="{INK}" stroke-width="4"/>'
                f'<circle cx="28" cy="69" r="9" fill="#c9a06a" stroke="{INK}" stroke-width="2"/>'
                f'<circle cx="28" cy="69" r="3.5" fill="{WOOD}"/>')
    if kind == "hammer":
        return (f'<rect x="60" y="40" width="8" height="78" fill="{WOOD}" stroke="{INK}" stroke-width="2"/>'
                f'<rect x="36" y="26" width="52" height="20" fill="url(#steel)" stroke="{INK}" stroke-width="3"/>')
    if kind == "sword":
        return (f'<path d="M64 14 L72 84 L64 94 L56 84 Z" fill="#c8ccd2" stroke="{INK}" stroke-width="3"/>'
                f'<rect x="40" y="84" width="48" height="8" fill="url(#gold)" stroke="{INK}" stroke-width="2"/>'
                f'<rect x="60" y="92" width="8" height="22" fill="#5a3a22" stroke="{INK}" stroke-width="2"/>')
    if kind == "shield":
        return (f'<path d="M34 28 L94 28 L94 74 Q94 102 64 112 Q34 102 34 74 Z" fill="#b0503c" stroke="{INK}" stroke-width="4"/>'
                f'<path d="M64 40 L64 96 M46 62 L82 62" stroke="{GOLD}" stroke-width="7"/>')
    if kind == "bow":
        return (f'<path d="M50 18 Q98 64 50 110" fill="none" stroke="{WOOD}" stroke-width="6"/>'
                f'<path d="M50 18 L50 110" stroke="{PARCH}" stroke-width="1.6"/>')
    if kind == "quill":
        return (f'<path d="M98 14 Q62 58 46 112" fill="none" stroke="{PARCH}" stroke-width="6"/>'
                f'<path d="M98 14 Q76 36 58 60" fill="none" stroke="{INK}" stroke-width="2" opacity="0.4"/>'
                f'<path d="M46 112 L40 120" stroke="{INK}" stroke-width="3"/>')
    if kind == "ladle":
        return (f'<circle cx="58" cy="50" r="20" fill="url(#steel)" stroke="{INK}" stroke-width="4"/>'
                f'<rect x="72" y="62" width="9" height="56" fill="{WOOD}" stroke="{INK}" stroke-width="2" transform="rotate(30 76 62)"/>')
    if kind == "shell":
        ribs = "".join(f'<path d="M64 110 L{x} {y}" stroke="{INK}" stroke-width="2"/>'
                       for x, y in ((30, 60), (42, 42), (56, 32), (72, 32), (86, 42), (98, 60)))
        return (f'<path d="M64 110 L28 58 Q64 18 100 58 Z" fill="#d9c8a0" stroke="{INK}" stroke-width="4"/>{ribs}')
    return ""


def item_icon(kind):
    """An item on its own: a roundel of tapestry with the item centred."""
    body = [defs_common() + field_shapes(128, 128, 24, "#2a2119", "#3d3024"),
            f'<circle cx="64" cy="64" r="58" fill="none" stroke="{GOLD}" stroke-width="5"/>',
            f'<circle cx="64" cy="64" r="51" fill="none" stroke="{INK}" stroke-width="2"/>',
            f'<g transform="translate(0 0)">{item(kind)}</g>']
    return svg(128, 128, "".join(body))


ITEMS = ["bread", "candle", "book", "cross", "bell", "grain", "fish", "herb",
         "log", "hammer", "sword", "shield", "bow", "quill", "ladle", "shell"]


# --- Backgrounds, frames, banners, icons, map and event scenes -----------------------------

def tapestry_bg(w, h, bg, accent):
    """A full tapestry field for a screen: the same field as the figures, with a wide gold border."""
    return svg(w, h, defs_common() + field_shapes(w, h, 40, bg, accent) +
               f'<rect x="10" y="10" width="{w-20}" height="{h-20}" fill="none" stroke="url(#gold)" stroke-width="10"/>'
               f'<rect x="24" y="24" width="{w-48}" height="{h-48}" fill="none" stroke="{INK}" stroke-width="2"/>'
               + "".join(f'<circle cx="{x}" cy="{y}" r="6" fill="url(#gold)" stroke="{INK}" stroke-width="2"/>'
                         for x, y in ((10, 10), (w-10, 10), (10, h-10), (w-10, h-10))))


def panel_nine():
    """A 96 by 96 panel frame for nine-slice drawing: a gold border, ink line and corner roundels."""
    return svg(96, 96, defs_common() +
               '<rect x="1" y="1" width="94" height="94" fill="#2a2119"/>'
               '<rect x="5" y="5" width="86" height="86" fill="none" stroke="url(#gold)" stroke-width="5"/>'
               f'<rect x="12" y="12" width="72" height="72" fill="none" stroke="{INK}" stroke-width="2"/>'
               + "".join(f'<circle cx="{x}" cy="{y}" r="6" fill="url(#gold)" stroke="{INK}" stroke-width="2"/>'
                         for x, y in ((12, 12), (84, 12), (12, 84), (84, 84))))


def title_banner():
    """A ribbon with scrolled ends, for the title to be set over in the UI font."""
    return svg(720, 180, defs_common() +
               f'<path d="M80 40 L640 40 L700 90 L640 140 L80 140 L20 90 Z" fill="#2a2119" stroke="url(#gold)" stroke-width="6"/>'
               f'<path d="M92 56 L628 56 L672 90 L628 124 L92 124 L48 90 Z" fill="none" stroke="{INK}" stroke-width="2"/>'
               '<path d="M20 90 Q0 60 14 40 M700 90 Q720 60 706 40 M20 90 Q0 120 14 140 M700 90 Q720 120 706 140" fill="none" stroke="url(#gold)" stroke-width="5" stroke-linecap="round"/>'
               '<circle cx="14" cy="40" r="7" fill="url(#gold)"/><circle cx="706" cy="40" r="7" fill="url(#gold)"/>'
               '<circle cx="14" cy="140" r="7" fill="url(#gold)"/><circle cx="706" cy="140" r="7" fill="url(#gold)"/>')


def heart_icon():
    return ('<path d="M64 104 Q18 74 22 46 Q26 26 46 28 Q58 30 64 42 Q70 30 82 28 Q102 26 106 46 Q110 74 64 104 Z" '
            f'fill="#b0503c" stroke="{INK}" stroke-width="4"/>'
            '<path d="M36 44 Q40 36 48 36" fill="none" stroke="#f2c4b0" stroke-width="4" stroke-linecap="round"/>')


def menu_icon():
    return ''.join(f'<rect x="30" y="{y}" width="68" height="12" rx="4" fill="url(#gold)" stroke="{INK}" stroke-width="2"/>'
                   for y in (34, 58, 82))


def house_icon():
    return (f'<path d="M24 60 L64 24 L104 60 Z" fill="#b0503c" stroke="{INK}" stroke-width="4"/>'
            f'<rect x="34" y="60" width="60" height="44" fill="url(#parch)" stroke="{INK}" stroke-width="4"/>'
            f'<rect x="56" y="78" width="16" height="26" fill="{WOOD}" stroke="{INK}" stroke-width="2"/>')


def road_icon():
    return (f'<path d="M24 104 Q48 40 64 64 Q80 88 104 24" fill="none" stroke="{INK}" stroke-width="10" stroke-linecap="round"/>'
            '<path d="M24 104 Q48 40 64 64 Q80 88 104 24" fill="none" stroke="url(#parch)" stroke-width="4" stroke-linecap="round"/>'
            f'<circle cx="104" cy="24" r="8" fill="url(#gold)" stroke="{INK}" stroke-width="2"/>')


def stance_icon(kind):
    if kind == "advance":
        return (f'<path d="M64 20 L92 64 L74 64 L74 108 L54 108 L54 64 L36 64 Z" fill="url(#steel)" stroke="{INK}" stroke-width="4"/>')
    if kind == "hold":
        return (f'<path d="M36 28 L92 28 L92 74 Q92 102 64 112 Q36 102 36 74 Z" fill="#b0503c" stroke="{INK}" stroke-width="4"/>'
                '<path d="M64 40 L64 96 M46 62 L82 62" stroke="url(#gold)" stroke-width="7"/>')
    return (f'<path d="M36 64 L64 20 L64 40 L92 40 L92 88 L64 88 L64 108 Z" fill="url(#parch)" stroke="{INK}" stroke-width="4"/>')


def _hull(points):
    """Convex hull by the monotone chain method, counter-clockwise."""
    pts = sorted(set(points))
    if len(pts) < 3:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    lower, upper = [], []
    for q in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], q) <= 0:
            lower.pop()
        lower.append(q)
    for q in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], q) <= 0:
            upper.pop()
        upper.append(q)
    return lower[:-1] + upper[:-1]


def island_outline(w, h):
    """An island that holds every place on the road map, with a jagged coast. Coordinates follow the
    map's own layout: the places sit at PAD plus their 0 to 1 position, as in road_map.gd."""
    import json
    import math
    pad = 26
    data = json.load(open(os.path.join(ROOT, "..", "..", "data", "road", "map.json"), encoding="utf-8"))
    pts = [(pad + n["x"] * (w - 2 * pad), pad + n["y"] * (h - 2 * pad)) for n in data["nodes"]]
    house = data.get("house", {})
    if house:
        pts.append((pad + house["x"] * (w - 2 * pad), pad + house["y"] * (h - 2 * pad)))
    hull = _hull(pts)
    cx = sum(x for x, _ in hull) / len(hull)
    cy = sum(y for _, y in hull) / len(hull)
    grown = [(cx + (x - cx) * 1.0 + (x - cx) * 0.0, cy + (y - cy) * 1.0) for x, y in hull]
    # Push every hull point outward so the places sit well inside the coast.
    outer = []
    for x, y in grown:
        d = math.hypot(x - cx, y - cy) or 1.0
        outer.append((x + (x - cx) / d * 46, y + (y - cy) / d * 46))
    # Subdivide the coast and wobble it, so it reads as coastline and not a polygon.
    coast = []
    n = len(outer)
    for i in range(n):
        x0, y0 = outer[i]
        x1, y1 = outer[(i + 1) % n]
        for k in range(4):
            t = k / 4
            x = x0 + (x1 - x0) * t
            y = y0 + (y1 - y0) * t
            wob = 9 * math.sin(i * 2.3 + k * 1.7) + 5 * math.sin(i * 5.1 + k * 0.9)
            nx_, ny_ = -(y1 - y0), (x1 - x0)
            ln = math.hypot(nx_, ny_) or 1.0
            coast.append((min(w - 14, max(14, x + nx_ / ln * wob)), min(h - 14, max(14, y + ny_ / ln * wob))))
    return "M" + " L".join(f"{x:.1f} {y:.1f}" for x, y in coast) + " Z"


def map_parchment(w=720, h=520):
    """The island as a parchment chart: a coastline that holds every place, sea hatching and a compass rose."""
    coast = island_outline(w, h)
    hatch = "".join(f'<path d="M{x} {y} q14 -8 28 0" fill="none" stroke="{darker("#d8c49a", 0.45)}" stroke-width="1.5" opacity="0.6"/>'
                    for y in range(40, h - 20, 22) for x in range(20 + (y // 22 % 2) * 14, w - 20, 34))
    rose = (f'<g transform="translate(640 80)"><circle r="34" fill="none" stroke="{INK}" stroke-width="2"/>'
            f'<path d="M0 -40 L8 0 L0 40 L-8 0 Z" fill="url(#gold)" stroke="{INK}" stroke-width="2"/>'
            f'<path d="M-40 0 L0 8 L40 0 L0 -8 Z" fill="{darker(GOLD, 0.2)}" stroke="{INK}" stroke-width="1.5"/></g>')
    return svg(w, h, defs_common() +
               '<defs><radialGradient id="pg" cx="0.5" cy="0.5" r="0.75"><stop offset="0" stop-color="#f3e6c4"/>'
               '<stop offset="1" stop-color="#c9b07e"/></radialGradient></defs>'
               f'<rect width="{w}" height="{h}" fill="url(#pg)"/>'
               f'<rect x="6" y="6" width="{w-12}" height="{h-12}" fill="none" stroke="{INK}" stroke-width="3"/>'
               + hatch +
               f'<path d="{coast}" fill="#e9dcbf" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>'
               f'<path d="M120 300 Q200 250 260 290 Q330 330 420 300 Q500 270 560 300" fill="none" stroke="{darker("#b9a06a", 0.2)}" stroke-width="2" stroke-dasharray="6 6"/>'
               + rose)


def scene(kind):
    """A small scene for an event card: sky, land and a few silhouettes. 560 by 320."""
    w, h = 560, 320
    sky = {"road": "#3d5a6a", "village": "#6a5a7a", "chapel": "#3a2a40", "coast": "#2f5a6a",
           "fields": "#7a8a5a", "sickroom": "#2a3a3a", "storm": "#22303a", "hall": "#4a3320"}[kind]
    land = {"road": "#5a6a3a", "village": "#4a5a32", "chapel": "#2a2119", "coast": "#4a5a52",
            "fields": "#8a7a3a", "sickroom": "#3a3028", "storm": "#2a3a30", "hall": "#3a2a1a"}[kind]
    body = [defs_common() +
            f'<defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{darker(sky, 0.3)}"/>'
            f'<stop offset="1" stop-color="{sky}"/></linearGradient></defs>',
            f'<rect width="{w}" height="{h}" fill="url(#sky)"/>',
            f'<path d="M0 {h-90} Q140 {h-140} 280 {h-100} T560 {h-110} L560 {h} L0 {h} Z" fill="{land}"/>',
            f'<rect x="4" y="4" width="{w-8}" height="{h-8}" fill="none" stroke="url(#gold)" stroke-width="6"/>']
    if kind == "road":
        body.append(f'<path d="M180 {h} Q260 {h-120} 300 {h-70} Q340 {h-40} 400 {h-100}" fill="none" stroke="{PARCH}" stroke-width="16" opacity="0.5"/>')
        body.append('<circle cx="450" cy="90" r="26" fill="url(#gold)" opacity="0.8"/>')
    elif kind == "village":
        for x, hgt in ((110, 80), (200, 96), (300, 70), (400, 88)):
            body.append(f'<path d="M{x-40} {h-96} L{x} {h-96-hgt} L{x+40} {h-96} Z" fill="#8a6a4a" stroke="{INK}" stroke-width="3"/>')
            body.append(f'<rect x="{x-40}" y="{h-96}" width="80" height="60" fill="#d8c49a" stroke="{INK}" stroke-width="3"/>')
            body.append(f'<rect x="{x-8}" y="{h-70}" width="16" height="34" fill="{INK}"/>')
    elif kind == "chapel":
        body.append(f'<path d="M140 {h-40} L140 110 Q280 40 420 110 L420 {h-40} Z" fill="#4a3a55" stroke="{INK}" stroke-width="4"/>')
        body.append(f'<path d="M280 60 L280 130 M248 88 L312 88" stroke="url(#gold)" stroke-width="8"/>')
        body.append('<path d="M270 200 L290 200 L290 260 L270 260 Z" fill="url(#parch)"/>')
        body.append('<path d="M278 170 Q286 184 278 196 Q270 184 278 170 Z" fill="url(#gold)"/>')
    elif kind == "coast":
        body.append('<path d="M0 230 Q140 210 260 240 T560 220 L560 320 L0 320 Z" fill="#3a5a6a"/>')
        body.append(f'<path d="M180 240 L260 210 L340 240 Z" fill="#e9dcbf" stroke="{INK}" stroke-width="3"/>')
        body.append(f'<path d="M230 240 L230 190 L300 190" fill="none" stroke="{INK}" stroke-width="3"/>')
        body.append('<circle cx="460" cy="80" r="20" fill="url(#gold)" opacity="0.8"/>')
    elif kind == "fields":
        for x in range(60, 540, 60):
            body.append(f'<path d="M{x} {h-30} L{x} {h-80}" stroke="#c9a14a" stroke-width="3"/>')
            body.append(f'<ellipse cx="{x}" cy="{h-90}" rx="9" ry="14" fill="#d9a84a" stroke="{INK}" stroke-width="2"/>')
    elif kind == "sickroom":
        body.append(f'<rect x="150" y="{h-120}" width="260" height="46" rx="6" fill="#6a4a2a" stroke="{INK}" stroke-width="3"/>')
        body.append(f'<rect x="170" y="{h-146}" width="90" height="30" rx="8" fill="#e9dcbf" stroke="{INK}" stroke-width="3"/>')
        body.append('<path d="M360 60 L380 60 L380 130 L360 130 Z" fill="url(#parch)" stroke="#2a1d14" stroke-width="2"/>')
    elif kind == "storm":
        body.append('<path d="M300 40 L270 120 L300 120 L262 210 L330 100 L300 100 L340 40 Z" fill="url(#gold)" stroke="#2a1d14" stroke-width="3"/>')
        body.append('<path d="M0 240 Q120 220 240 250 T560 240 L560 320 L0 320 Z" fill="#26485a"/>')
    elif kind == "hall":
        body.append(f'<path d="M80 {h-60} L280 60 L480 {h-60} Z" fill="#6a4a2a" stroke="{INK}" stroke-width="4"/>')
        body.append(f'<path d="M280 60 L280 {h-60}" stroke="{INK}" stroke-width="3"/>')
        body.append('<rect x="250" y="150" width="60" height="50" fill="url(#parch)" stroke="#2a1d14" stroke-width="2"/>')
    return svg(w, h, "".join(body))


SCENES = ["road", "village", "chapel", "coast", "fields", "sickroom", "storm", "hall"]


def write_all_extra():
    out = {"backgrounds": {"menu": tapestry_bg(720, 1280, "#2a2119", "#4a3a28"),
                           "house": tapestry_bg(720, 1280, "#1f2a24", "#2f4a3e")},
           "frames": {"panel": panel_nine()},
           "banners": {"title": title_banner()},
           "icons": {"heart": svg(128, 128, defs_common() + heart_icon()),
                     "menu": svg(128, 128, defs_common() + menu_icon()),
                     "house": svg(128, 128, defs_common() + house_icon()),
                     "road": svg(128, 128, defs_common() + road_icon()),
                     "stance_advance": svg(128, 128, defs_common() + stance_icon("advance")),
                     "stance_hold": svg(128, 128, defs_common() + stance_icon("hold")),
                     "stance_withdraw": svg(128, 128, defs_common() + stance_icon("withdraw"))},
           "map": {"island": map_parchment()},
           "scenes": {k: scene(k) for k in SCENES}}
    for folder, files in out.items():
        os.makedirs(os.path.join(ROOT, folder), exist_ok=True)
        for name, text in files.items():
            with open(os.path.join(ROOT, folder, name + ".svg"), "w") as f:
                f.write(text)
    return sum(len(v) for v in out.values())


def main():
    os.makedirs(os.path.join(ROOT, "portraits"), exist_ok=True)
    os.makedirs(os.path.join(ROOT, "figures"), exist_ok=True)
    os.makedirs(os.path.join(ROOT, "items"), exist_ok=True)
    for pid in PATHS:
        with open(os.path.join(ROOT, "portraits", pid + ".svg"), "w") as f:
            f.write(portrait(pid))
        with open(os.path.join(ROOT, "figures", pid + ".svg"), "w") as f:
            f.write(figure(pid))
    for kind in ITEMS:
        with open(os.path.join(ROOT, "items", kind + ".svg"), "w") as f:
            f.write(item_icon(kind))
    n = write_all_extra()
    print("wrote", len(PATHS) * 2 + len(ITEMS) + n, "svg files to", os.path.normpath(ROOT))


if __name__ == "__main__":
    main()
