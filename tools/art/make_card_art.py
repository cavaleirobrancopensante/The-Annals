"""One picture per event card: the card's scene, with up to two house items drawn from the words of the card.

Run from the project root:  python3 tools/art/make_card_art.py
Writes assets/art/cards/<card id>.svg. Each card's English text is read from data/events/*.json.
"""
import glob
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
import make_art  # noqa: E402

# Words in a card -> the item drawn for it. Checked in order; a card takes at most two items.
KEYWORDS = [
    ("bell", "bell"), ("mass", "bell"), ("office", "bell"), ("compline", "bell"), ("vigil", "candle"),
    ("candle", "candle"), ("lamp", "candle"), ("light", "candle"),
    ("ledger", "book"), ("book", "book"), ("letter", "book"), ("psalter", "book"), ("chronicle", "book"),
    ("bread", "bread"), ("loaf", "bread"), ("bake", "bread"), ("flour", "bread"),
    ("fish", "fish"), ("net", "fish"), ("boat", "fish"), ("tide", "shell"), ("shore", "shell"),
    ("shell", "shell"), ("coast", "shell"), ("harbour", "shell"),
    ("herb", "herb"), ("medicine", "herb"), ("fever", "herb"), ("sick", "herb"), ("sickness", "herb"),
    ("grain", "grain"), ("barley", "grain"), ("harvest", "grain"), ("field", "grain"), ("sheaf", "grain"),
    ("firewood", "log"), ("log", "log"), ("wood", "log"), ("fire", "log"), ("hearth", "log"),
    ("hammer", "hammer"), ("roof", "hammer"), ("wall", "hammer"), ("stone", "hammer"), ("build", "hammer"),
    ("bow", "bow"), ("arrow", "bow"), ("hunt", "bow"), ("deer", "bow"),
    ("sword", "sword"), ("blade", "sword"), ("rider", "sword"), ("soldier", "sword"), ("fight", "sword"),
    ("gate", "shield"), ("shield", "shield"), ("toll", "shield"), ("guard", "shield"),
    ("quill", "quill"), ("scribe", "quill"), ("copy", "quill"), ("write", "quill"), ("ink", "quill"),
    ("ladle", "ladle"), ("soup", "ladle"), ("broth", "ladle"), ("pot", "ladle"), ("kitchen", "ladle"),
    ("cross", "cross"), ("prayer", "cross"), ("pray", "cross"), ("grave", "cross"), ("confess", "cross"),
    ("dead", "cross"), ("death", "cross"), ("abbot", "cross"), ("bishop", "cross"),
]
SCENE_OF_NONE = "hall"


def words_of(card: dict) -> str:
    parts = [str(card.get("title", "")), str(card.get("text", ""))]
    for c in card.get("choices", []):
        parts.append(str(c.get("label", "")))
    return " ".join(parts).lower()


def items_for(card: dict) -> list:
    text = words_of(card)
    found = []
    for word, item in KEYWORDS:
        if item not in found and re.search(r"\b" + word, text):
            found.append(item)
        if len(found) == 2:
            break
    return found


def card_svg(scene_svg: str, items: list) -> str:
    if not items:
        return scene_svg
    glyphs = []
    for i, kind in enumerate(items):
        x = 400 - i * 150
        glyphs.append(f'<g transform="translate({x} 26) scale(1.2)">'
                      f'<circle cx="64" cy="64" r="58" fill="#2a2119" fill-opacity="0.85" stroke="url(#gold)" stroke-width="4"/>'
                      f'{make_art.item(kind)}</g>')
    return scene_svg.replace("</svg>", "".join(glyphs) + "</svg>")


def main() -> None:
    scenes = json.load(open(os.path.join(ROOT, "data/scenes/events.json"), encoding="utf-8"))
    out_dir = os.path.join(ROOT, "assets/art/cards")
    os.makedirs(out_dir, exist_ok=True)
    count = 0
    seen = set()
    for path in sorted(glob.glob(os.path.join(ROOT, "data/events/*.json"))):
        for card in json.load(open(path, encoding="utf-8")):
            cid = card["id"]
            seen.add(cid)
            scene = scenes.get(cid, SCENE_OF_NONE)
            base = make_art.scene(scene)
            with open(os.path.join(out_dir, cid + ".svg"), "w", encoding="utf-8") as f:
                f.write(card_svg(base, items_for(card)))
            count += 1
    print("wrote", count, "card pictures to", os.path.normpath(out_dir))


if __name__ == "__main__":
    main()
