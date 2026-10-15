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


def frame(w, h, bg, accent):
    """A tapestry field of quatrefoils and diamonds, a knotwork band, and gold roundels at the corners."""
    s = []
    s.append('<defs><pattern id="field" width="32" height="32" patternUnits="userSpaceOnUse">'
             f'<rect width="32" height="32" fill="{bg}"/>'
             f'<path d="M16 2 L30 16 L16 30 L2 16 Z" fill="{darker(accent, 0.15)}" opacity="0.55"/>'
             f'<path d="M16 7 L25 16 L16 25 L7 16 Z" fill="{lighter(accent, 0.1)}" opacity="0.4"/>'
             f'<circle cx="16" cy="16" r="2.4" fill="url(#gold)"/>'
             f'<circle cx="0" cy="0" r="1.6" fill="url(#gold)" opacity="0.6"/>'
             f'<circle cx="32" cy="32" r="1.6" fill="url(#gold)" opacity="0.6"/>'
             '</pattern></defs>')
    s.append(f'<rect x="0" y="0" width="{w}" height="{h}" fill="url(#field)"/>')
    # A vignette so the figure sits in light.
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
    body = [defs_common() + "<defs>" + robe_grad("robe", p["robe"]) + emb_pattern() + "</defs>",
            frame(256, 256, p["bg"], p["accent"])]
    body.append(f'<path d="M34 256 Q34 186 96 170 L160 170 Q222 186 222 256 Z" fill="url(#robe)" stroke="{INK}" stroke-width="5"/>')
    body.append(f'<path d="M96 170 Q128 196 160 170" fill="none" stroke="url(#emb)" stroke-width="9"/>')
    body.append(f'<path d="M40 252 Q44 214 96 204" fill="none" stroke="{darker(p["robe"], 0.45)}" stroke-width="2.5" opacity="0.5"/>')
    body.append(f'<path d="M216 252 Q212 214 160 204" fill="none" stroke="{darker(p["robe"], 0.45)}" stroke-width="2.5" opacity="0.5"/>')
    body.append(f'<rect x="112" y="136" width="32" height="40" fill="{SKIN_SH}" stroke="{INK}" stroke-width="3"/>')
    body.append(head_group(p, p, 1.0).replace('<g transform="scale(1.0)">', '<g transform="translate(128 112)">'))
    body.append(symbol(p["symbol"], 128, 226, 0.85))
    return svg(256, 256, "".join(body))


def figure(pid):
    p = PATHS[pid]
    body = [defs_common() + "<defs>" + robe_grad("robe", p["robe"]) + emb_pattern() + "</defs>",
            frame(256, 512, p["bg"], p["accent"])]
    # legs and feet under the robe
    body.append(f'<rect x="102" y="420" width="24" height="60" fill="{INK}"/><rect x="130" y="420" width="24" height="60" fill="{INK}"/>')
    body.append(f'<ellipse cx="112" cy="484" rx="16" ry="8" fill="{WOOD}" stroke="{INK}" stroke-width="3"/>'
                f'<ellipse cx="144" cy="484" rx="16" ry="8" fill="{WOOD}" stroke="{INK}" stroke-width="3"/>')
    # the robe, flaring to the hem
    body.append(f'<path d="M92 168 L164 168 Q186 260 194 426 L62 426 Q70 260 92 168 Z" fill="url(#robe)" stroke="{INK}" stroke-width="5"/>')
    body.append(f'<path d="M62 426 L194 426" stroke="url(#emb)" stroke-width="11"/>')
    body.append(f'<path d="M128 176 L128 420" stroke="url(#gold)" stroke-width="4" opacity="0.7"/>')
    for x0, x1 in ((112, 104), (144, 152)):
        body.append(f'<path d="M{x0} 200 Q{x1} 300 {x0 - 6 if x0 < 128 else x0 + 6} 420" fill="none" stroke="{darker(p["robe"], 0.45)}" stroke-width="3" opacity="0.5"/>')
    body.append(f'<path d="M96 178 L160 178" stroke="url(#emb)" stroke-width="9"/>')
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
    body = [defs_common() + '<defs><pattern id="f" width="24" height="24" patternUnits="userSpaceOnUse"><rect width="24" height="24" fill="#2a2119"/>'
            f'<path d="M12 2 L22 12 L12 22 L2 12 Z" fill="#3d3024" opacity="0.8"/></pattern></defs>',
            f'<rect width="128" height="128" fill="url(#f)"/>',
            f'<circle cx="64" cy="64" r="58" fill="none" stroke="{GOLD}" stroke-width="5"/>',
            f'<circle cx="64" cy="64" r="51" fill="none" stroke="{INK}" stroke-width="2"/>',
            f'<g transform="translate(0 0)">{item(kind)}</g>']
    return svg(128, 128, "".join(body))


ITEMS = ["bread", "candle", "book", "cross", "bell", "grain", "fish", "herb",
         "log", "hammer", "sword", "shield", "bow", "quill", "ladle", "shell"]


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
    print("wrote", len(PATHS) * 2 + len(ITEMS), "svg files to", os.path.normpath(ROOT))


if __name__ == "__main__":
    main()
