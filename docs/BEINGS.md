# Beings: allies and enemies beyond the road

Status: first slice built. Four beings, each with an attitude from -5 to 5. The road's factions (`docs/SKILLS.md`, the standing on the map) are separate: they are people the house trades with. Beings are the other things in the world that can be friends or enemies.

## The four beings

| Being | Kind | How the house controls it |
|---|---|---|
| The Marred (`marred`) | Rational | Talk: Presence with Persuasion, or Command when they are weak. Also gifts and trades. |
| The chimera nest (`chimera`) | Not rational | Hand with Hunting or Ranged to drive it off; Lore with Tracking to learn its paths; food left out to win it over. |
| The engine (`engine`) | Not rational | Lore with Ruins and machines to read its workings. Once allied it turns the woodshed wheel: one firewood a week. |
| The Hollow (`hollow`) | Not rational | Faith with Warding or Devotion to hold it back. It draws its own deck, only while hostile. |

Every being starts at 0 (neutral). Allied from 3 upward, hostile from -3 downward. Crossing into or out of either state is written in the annals.

## How it works

- **Attitude** lives in `scripts/autoload/beings.gd`. Effects move it: `"attitude": {"chimera": 2}`. Conditions read it: `"attitude_min": {"engine": 3}` and `"attitude_max": {"hollow": -3}`.
- **Control is a check.** A card choice with a `check` decides the change in its success and failure branches, the same as the other checks. The stat and skill are the ones that fit the being.
- **The Hollow's deck** (`deck: "hollow"`) is drawn one week in twenty-five while the Hollow is hostile. Its cards only fire while it is hostile. The cards that turn it hostile are in the abbey deck, such as the lamp in the crypt.
- **The engine** adds one firewood a week while allied.
- Cards: `data/events/beings.json` (translated in `data/i18n/`).

## Not yet built

- Beings on the road map (a nest at a place, the Marred as a faction on the road, an engine at a ruin).
- Several nests, several engines, or several Hollows.
- Engine effects beyond firewood.
- The Hollow's threat to the brothers' health and the house's graves.
- The Marred closing a road node when hostile.
- Showing attitudes on the estate screen.
