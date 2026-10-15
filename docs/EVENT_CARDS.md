# Writing event cards

Event cards live in `data/events/*.json`. Each file is a JSON array of cards. Any new `.json` file in that folder is loaded automatically, so you can organise cards however you like (by theme, by season, by story arc).

Every week the game rolls for an event. It collects every card whose conditions fit the world right now, and picks one by weight. **Cards that read tags the world remembers are more likely to fire**, which is how callbacks and story arcs emerge.

## A complete card

```json
{
  "id": "proud_return",
  "title": "Empty-Handed",
  "deck": "abbey",
  "weight": 10,
  "cooldown": 30,
  "once": false,
  "when": {"season": ["autumn"], "monk": {"has": ["proud"]}},
  "text": "{monk} returns from the road with nothing, and will not meet your eyes.",
  "choices": [
    {
      "label": "Let him go back alone",
      "effects": {"monk_away": {"weeks": 3, "tag": "on_alms"}},
      "chronicle": "{When}, {monk} came home empty-handed and asked to go out again alone."
    },
    {
      "label": "Assign him penance",
      "requires": {"food": 5},
      "effects": {"food": -5, "monk_add_tag": "bitter"},
      "chronicle": ""
    }
  ]
}
```

## Fields

| Field | Meaning | Default |
| --- | --- | --- |
| `id` | Unique name. Never reuse one. | required |
| `title` | Heading shown above the text. | none |
| `deck` | `abbey` for weekly events, `return` for brothers coming home from the road. | `abbey` |
| `weight` | How likely it is, compared with other eligible cards. | 10 |
| `cooldown` | Weeks before it can fire again. | 30 |
| `once` | If true, fires only once per house. | false |
| `when` | Conditions (below). | always eligible |
| `text` | What the player reads. | |
| `choices` | Buttons. **Leave this out** to make an automatic event that just happens. | |
| `effects` | For automatic events only: what happens. | |
| `chronicle` | Default chronicle line if a choice has none. | |

A choice has `label`, `effects`, optional `requires` (resources needed to pick it), and optional `chronicle`. A choice with `"chronicle": ""` writes nothing to the annals. Use that for small decisions that aren't worth recording.

**Always give every card at least one choice with no `requires`**, so the player is never stuck.

## Conditions (`when`)

| Key | Example | Meaning |
| --- | --- | --- |
| `season` | `["winter"]` | Only in these seasons: `spring`, `summer`, `autumn`, `winter`. |
| `not_season` | `["winter"]` | Never in these seasons. |
| `min` / `max` | `{"food": 40}` | Resource at least / at most this. |
| `has_tag` | `["village_friend"]` | The world remembers all of these tags. |
| `not_tag` | `["gate_barred"]` | The world remembers none of these. |
| `min_monks` | `6` | At least this many living brothers. |
| `year_min` | `2` | Not before this year of the house. |
| `monk` | `{...}` | Picks a brother to be `{monk}` in the text. |
| `monk2` | `{...}` | Picks a second, different brother as `{monk2}`. |

Brother conditions, inside `monk` or `monk2`:

| Key | Example | Meaning |
| --- | --- | --- |
| `vocation` | `["scribe", "healer"]` | One of: `scribe`, `farmer`, `healer`, `builder`, `cook`, `soldier`. |
| `has` | `["devout"]` | Has all these traits or tags. |
| `has_any` | `["proud", "wrathful"]` | Has at least one. |
| `not` | `["pilgrim"]` | Has none of these. |
| `min_age` / `max_age` | `50` | Age limits. |
| `min_health` | `3` | 3 = well, 2 = unwell, 1 = gravely ill. |
| `status` | `"home"` | `home` (default) or `away`. |
| `abbot` | `true` | Pick the abbot himself. By default the abbot is never picked. |

Traits are `devout`, `patient`, `gentle`, `learned`, `brave`, `generous`, `cheerful` (virtues) and `proud`, `wrathful`, `doubting`, `gluttonous`, `stubborn`, `restless`, `melancholy` (flaws). Tags are anything you invent.

## Effects

| Key | Example | Meaning |
| --- | --- | --- |
| `food`, `firewood`, `medicine`, `books`, `goodwill` | `-10` | Change a resource. |
| `add_tag` | `"bandits_on_road"` or a list | The world remembers this. |
| `tag_weeks` | `24` | Tags added here expire after this many weeks. Leave out for permanent. |
| `remove_tag` | `"village_slighted"` | The world forgets this. |
| `monk_add_tag` / `monk_remove_tag` | `"bitter"` | Mark or unmark the brother. Removing also works on traits. |
| `monk_health` | `-1` | Change his health (never below 1). |
| `monk_away` | `{"weeks": 4, "tag": "on_alms"}` | Send him on the road. When he returns, a `return` card with that tag fires. |
| `monk_departs` | `true` | He leaves the house for good. |
| `monk_dies` | `"fever"` | He dies. Write the death in the chronicle line. |
| `monk2_...` | | The same, for the second brother. |
| `new_monk` | `{"vocation": "soldier", "traits": ["wrathful"], "age": [20, 30]}` | A new brother joins; he becomes `{newcomer}`. |
| `chronicle` | `"..."` | Add a line to the annals (useful inside oracle branches). |
| `oracle` | see below | Ask the oracle a yes/no question. |

The oracle:

```json
"oracle": {
  "odds": "likely",
  "yes": {"food": 30, "chronicle": "{monk} came home with a cart of grain."},
  "no": {"add_tag": "bandits_on_road", "tag_weeks": 24, "chronicle": "{monk} came home with nothing."}
}
```

Odds: `impossible`, `very_unlikely`, `unlikely`, `even`, `likely`, `very_likely`, `certain`. Oracles can be nested inside other oracles.

## Words you can use in text

| Token | Becomes |
| --- | --- |
| `{When}` / `{when}` | "In the third winter of Abbot Ciarán". If the previous entry was the same season, a lighter phrase such as "Soon after" or "That winter". |
| `{monk}` / `{monk_name}` | "Brother Tomás" / "Tomás" |
| `{monk2}` / `{monk2_name}` | The second brother |
| `{newcomer}` / `{newcomer_name}` | A brother added by `new_monk` |
| `{abbot}` / `{abbot_name}` | "Abbot Ciarán" / "Ciarán" |
| `{patron}`, `{house}`, `{place}` | "Saint Columba", "Saint Columba's", "the Dry Ford" |
| `{season}`, `{year_ordinal}` | "winter", "third" |

## Journeys: the road and the return

Sending a brother out is a two-card pattern:

1. An `abbey` card uses `monk_away` with a journey tag that starts with `on_` (`on_alms`, `on_salvage`, `on_mission`).
2. One or more `return` cards require `"monk": {"has": ["on_alms"]}`. When he comes home, the game picks one of them, weighted, so several return cards for the same journey act like an oracle table.

Journey tags are removed automatically once the return card resolves.

## Tips

- Every card should either **write a tag or read one**. Cards that do neither are dead ends.
- Keep chronicle lines in the past tense and the scribe's voice. Start with `{When}` for the first line of an entry; return cards usually read better without it.
- Test with the simulation (see the README) and read the chronicle. If a card fires too often, lower its `weight` or raise its `cooldown`.
