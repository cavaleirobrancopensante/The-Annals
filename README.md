# The Annals

A monastery at the end of the world, and the chronicle it leaves behind.

You found a small abbey in the ruins of a fallen Ireland, an island with the sea on every side, and keep it alive across generations. Every week brings hunger, riders, sick children at the gate, brothers who doubt, and boxes that hum in the night. While you play, the game writes the house's annals in a scribe's voice. The chronicle is the reward.

Built in **Godot 4.7** (GDScript, GL Compatibility renderer), portrait, mobile first.

## Status: Phase 2, the abbey loop

A text-only prototype. Phase 1 asked whether the chronicle reads like a story; Phase 2 asks whether winter feels tense enough to plan for.

What works now:

- Weekly turns across four seasons, 48 weeks a year
- Jobs for every brother: fields, woodcutting, kitchen, infirmary, scriptorium, rest. Sick brothers don't work.
- Four buildings, raised by a builder at home: granary (food stores 120 to 320), woodshed (firewood 40 to 120), infirmary (medicine, and a place for healers to work), scriptorium (books)
- The Estate tab shows each brother's job and the buildings. The header shows the winter forecast: what winter needs against what is stored
- Hunger and cold when stores run out
- Brothers with names, vocations, a virtue and a flaw, ages, health and memories (tags)
- 47 event cards with choices, oracle rolls and callbacks
- Journeys on the road and homecoming events
- Ageing, natural death, illness, and the election of a new abbot
- The house can fall; then you can found a new one
- The chronicle, grouped by year, which you can copy or save as a text file
- Automatic save after every turn

## Running it

Open the folder in Godot 4.7 and press Play. On a phone, use the Godot editor app, or export for Android or Web.

**When exporting**, add `*.json` to *Resources → Filters to export non-resource files* in the export preset. Otherwise the event cards will not be packed and the game will have no events.

## Project layout

```
data/
  events/           event cards (JSON); any file here is loaded
  chronicle/        templates for system entries (deaths, harvests, elections)
  names.json        brothers' names, patron saints, place names
scripts/
  autoload/         the engine
    event_bus.gd      global signals
    oracle.gd         seeded random rolls and yes/no questions
    world_state.gd    calendar, resources, brothers, tags
    chronicle.gd      formatting, entries, export
    event_engine.gd   loads cards, checks conditions, applies effects
    game.gd           the weekly turn: economy, health, travel, ageing, succession
    save_system.gd    save and load to user://
  ui/main.gd        the phone interface
scenes/main.tscn
tests/              headless simulation and UI smoke test
docs/EVENT_CARDS.md how to write event cards
```

## Writing content

Read [docs/EVENT_CARDS.md](docs/EVENT_CARDS.md). You never need to touch code to add events: write a card in JSON, play, and read the chronicle.

## Testing

Play a whole house automatically, with random choices, and print the chronicle:

```
godot --headless --path . res://tests/simulate.tscn -- --seed=42 --years=3
```

The summary at the end lists which cards fired and which never did. A different seed gives a different house; the same seed always gives the same one.

Check that the interface runs without errors:

```
godot --headless --path . res://tests/ui_smoke.tscn
```

## Roadmap

| Phase | What | Gate before moving on |
| --- | --- | --- |
| 0 | Paper prototype | The paper chronicle is worth reading |
| 1 | Chronicle engine | Three generated years read like a story |
| 2 | **Abbey loop (this)**: jobs, buildings, storage | Winter feels tense even without events |
| 3 | The road: map, parties, factions | Public text prototype and first feedback |
| 4 | The Rule, generations, saints, new houses | A 50-year game stays varied |
| 5 | Skirmish combat | Fights are rare and memorable |
| 6 | Art, 200+ events, Portuguese, release | |
