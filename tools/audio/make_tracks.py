"""The 100 tracks of The Annals: one recipe each, with a moment and an element.

Run from the project root:  python3 tools/audio/make_tracks.py
Writes data/music/tracks.json. The game synthesises each track from its recipe when it plays
(scripts/audio/synth.gd), so the repository holds the recipes, not the sound.
"""
import json
import os

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))

# moment: mode, tempo (beats a minute), voice, and the seasons it suits
MOMENTS = [
    ("dawn", "lydian", 66, "harp"),
    ("matins", "dorian", 60, "chant"),
    ("work", "mixolydian", 96, "pluck"),
    ("harvest", "major", 104, "bells"),
    ("winter", "minor", 56, "organ"),
    ("feast", "major", 112, "bells"),
    ("sickness", "phrygian", 52, "organ"),
    ("death", "minor", 44, "bells"),
    ("storm", "phrygian", 80, "pluck"),
    ("arrival", "major", 84, "harp"),
    ("departure", "minor", 72, "pluck"),
    ("night", "dorian", 58, "organ"),
    ("prayer", "dorian", 50, "chant"),
    ("battle", "phrygian", 120, "pluck"),
    ("hunger", "minor", 48, "organ"),
    ("rest", "major", 70, "harp"),
]

# element: texture under the music, and the voice it prefers (None keeps the moment's voice)
ELEMENTS = [
    ("bell", "none", "bells"),
    ("wind", "wind", None),
    ("rain", "rain", None),
    ("fire", "fire", None),
    ("sea", "sea", None),
    ("stone", "none", "organ"),
    ("bog", "bog", None),
    ("candle", "none", "harp"),
    ("road", "wind", "pluck"),
    ("hollow", "hollow", "organ"),
    ("engine", "hum", None),
    ("chimera", "hollow", "pluck"),
    ("marred", "none", "chant"),
    ("earth", "rain", "organ"),
]

SEASON_MOMENT = {"spring": "dawn", "summer": "work", "autumn": "harvest", "winter": "winter"}


def build() -> list:
    tracks = []
    for i in range(100):
        moment, mode, tempo, voice = MOMENTS[i % len(MOMENTS)]
        element, texture, voice_over = ELEMENTS[(i + i // len(MOMENTS)) % len(ELEMENTS)]
        tracks.append({
            "id": "track_%03d" % (i + 1),
            "moment": moment,
            "element": element,
            "mode": mode,
            "root": 45 + (i * 5) % 12,
            "tempo": tempo + (i // len(MOMENTS)) % 3 * 4,
            "voice": voice_over or voice,
            "texture": texture,
            "seconds": 40,
            "seed": 1000 + i,
        })
    return tracks


def main() -> None:
    tracks = build()
    pairs = {(t["moment"], t["element"]) for t in tracks}
    assert len(pairs) == len(tracks), "two tracks share a moment and an element"
    out = {"_note": "The Annals' 100 tracks, one per moment and element. Synthesised at play time (scripts/audio/synth.gd).",
           "seasons": SEASON_MOMENT, "tracks": tracks}
    # The pt_BR and es copies in data/i18n/ carry the same tracks with a translated note.
    path = os.path.join(ROOT, "data/music/tracks.json")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(out, f, indent=1)
        f.write("\n")
    print("wrote", len(tracks), "tracks to", path)


if __name__ == "__main__":
    main()
