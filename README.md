# The Annals

A monastery at the end of the world, and the chronicle it leaves behind.

You found a small abbey in the ruins of a fallen Ireland, an island with the sea on every side, and keep it alive across generations. Every week brings hunger, riders, sick children at the gate, brothers who doubt, and boxes that hum in the night. While you play, the game writes the house's annals in a scribe's voice. The chronicle is the reward.

Built in **Godot 4.7** (GDScript, GL Compatibility renderer), portrait, mobile first.

## Status: Phase 5, skirmishes

A text-only prototype. Phase 1 asked whether the chronicle reads like a story; Phase 2 asked whether winter feels tense enough to plan for; Phase 3 asked whether the road gives the house a reason to leave its walls; Phase 4 asks whether a 50-year house stays varied.

What works now:

- Weekly turns across four seasons, 48 weeks a year
- Jobs for every brother: fields, woodcutting, kitchen, infirmary, scriptorium, rest. Sick brothers don't work.
- Four buildings, raised by a builder at home: granary (food stores 120 to 320), woodshed (firewood 40 to 120), infirmary (medicine, and a place for healers to work), scriptorium (books)
- The Estate tab shows each brother's job and the buildings. The header shows the winter forecast: what winter needs against what is stored
- Hunger and cold when stores run out
- Brothers with names, vocations, a virtue and a flaw, ages, health and memories (tags)
- 47 event cards with choices, oracle rolls and callbacks
- Journeys on the road and homecoming events
- Skirmishes: rare fights played a round at a time. Each round the house orders its line to hold the gate, press the attack, pray and close ranks, or withdraw. Brothers who are struck leave the line and may die. Three encounters so far: the Tollmaster's riders at the gate, road men on the road, and the machines of the turbine field
- The Rule: four axes (prayer, labour, hospitality, learning), each with options that change the house's economy and the events it meets. Changing the Rule costs a little goodwill and is written into the annals
- Generations: about fifteen years each. The first novice after that span starts the next generation
- Novices join at the gate, more often under an open gate and less often when the house is large
- Saints: a devout brother who dies old may be acclaimed a saint. Pilgrims then come to his grave
- Daughter houses: three brothers can be sent to found a house at a place on the road. It pays a yearly tithe in grain for as long as its people welcome it, and is lost if they close their doors
- The road: a map of 11 places held by five factions (the Tollmaster, the glen lords, the holy places, the coast folk, the bog folk). Send up to three brothers at home to a place. Arrivals meet the place in a `node` card; homecomings are `return` cards. Standing with each faction moves with what the house does, and a faction at -3 or below closes its places
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
  road/map.json     places on the road, factions, the house's position
  rule/rule.json    the Rule: its axes and options
  skirmish/encounters.json  the fights: enemies, strength, outcomes
scripts/
  autoload/         the engine
    event_bus.gd      global signals
    oracle.gd         seeded random rolls and yes/no questions
    world_state.gd    calendar, resources, brothers, tags
    chronicle.gd      formatting, entries, export
    event_engine.gd   loads cards, checks conditions, applies effects
    game.gd           the weekly turn: economy, health, travel, ageing, succession
    road.gd           places, factions and standing, parties on the road
    rule.gd           the Rule: the house's chosen customs
    skirmish.gd       fights played a round at a time
    save_system.gd    save and load to user://
  ui/main.gd        the phone interface
  ui/road_map.gd    the map of the road, drawn and tappable
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

Add `--no-build` to leave out building, or `--no-road` to keep every brother at home. The simulated house sends a party every sixteen weeks, sends three brothers to found a daughter house every sixty, and changes the Rule at random. The summary reports parties, colonies, rule changes, the generation and the saints.

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
| 2 | Abbey loop: jobs, buildings, storage | Winter feels tense even without events (not yet playtested) |
| 3 | The road: map, parties, factions | Public text prototype and first feedback (built, not yet playtested) |
| 4 | The Rule, generations, saints, daughter houses | A 50-year game stays varied (built, not yet playtested) |
| 5 | **Skirmish combat (this)** | Fights are rare and memorable |
| 6 | Art, 200+ events, Portuguese, release | |
