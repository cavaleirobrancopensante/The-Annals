# Menus, screens and the first-play tutorial (study)

Status: steps 1 to 3 and the tutorial (section 7) built, with the language flags. Steps 4 to 7 (header, event sheet, road labels) are still to come. Tutorial hints are stored but not yet used by the event sheet.
Target: a 720 × 1280 portrait phone screen, as the project is set up now (`project.godot`).

## 1. What exists today (as built)

- **No main menu.** The game opens straight into the house. `main.gd` loads the one save file if it exists, otherwise starts a new house.
- **One save slot.** `SaveSystem` writes `user://annals_save.json` after every change. There is no slot choice and no way to keep two houses.
- **No settings.** Text size, hints and sound cannot be changed.
- **No quit.** The app is closed by the operating system.
- **No tutorial.** New players learn from the first events.
- **In-game menu** (a "Menu" dropdown at the bottom right): Copy chronicle, Save chronicle as a text file, Found a new house (with a confirmation).
- **Fallen house:** the screen shows the fall and a "Found a new house" button. The save file is not archived.

The screen has four zones, top to bottom: header (title, status, resources, forecast), tabs (Chronicle, Estate, Road), event panel (appears over the tabs when a choice is needed), and a bottom bar (Next day, Next week, Until something happens, Menu).

## 2. Screen flow

```
Boot
 └─ Main menu
     ├─ New house ──► Choose a slot (1–10, empty slots only) ──► Name check (house name shown) ──► Begin
     │                                                              └─ Tutorial offer: Begin / Skip
     ├─ Load house ─► Slot list (1–10) ──► tap a slot ──► House
     ├─ Settings ───► Settings list ──► Back
     └─ Quit ───────► confirm ──► exit

House (in-game)
 ├─ Header · Tabs: Chronicle | Estate | Road
 ├─ Event sheet (when a choice is waiting; it takes the tabs' place)
 ├─ Bottom bar: Next day | Next week | Until something happens | Menu
 └─ Menu sheet: Copy chronicle · Save chronicle · Settings · Back to main menu · Found a new house
     └─ Fallen house: the annals end; Found a new house in this slot, or Back to main menu
```

Every screen has a Back button in the same place (top left). Every destructive action asks first.

## 3. Main menu

Layout, top to bottom, centred:

| Element | Spec |
|---|---|
| Title | "The Annals", 40 px, gold, 96 px from the top |
| Subtitle | "A monastery at the end of the world", 20 px, dim, one line |
| Buttons | New house · Load house · Settings · Quit, stacked, 72 px tall, 16 px apart, full width less 16 px gutters |
| Footer | Version number, 16 px, dim, bottom centre |

Quit asks "Quit The Annals? Your houses are saved." (Houses save after every change, so nothing is lost.) On Android the hardware Back key opens the same dialog.

"Continue" is not one of the four. If you want it, it is the most useful addition: it appears above New house when a slot was used last.

## 4. Slots (New and Load)

Ten slots, numbered 1 to 10. Each slot is a card 16 px apart, two cards to a row in portrait, five rows:

- **Filled:** house name ("Saint Enda's at Knockmore"), date ("Wednesday 22 November 2502"), year and season, living brothers ("12 brothers"), last saved time.
- **Empty:** "Empty slot", dim, with a "New house here" action in New mode and nothing in Load mode.
- **Fallen:** the house name with "fallen in year 4", dim, its annals still readable.

Actions:
- **New house:** tap an empty slot. Filled slots show "Found a new house here? The house in this slot will be closed for good." (with confirm).
- **Load house:** tap a filled slot to open it. Long press (or a small Delete button at the card's right) to delete, with confirm.

Save files: `user://annals_slot_1.json` to `user://annals_slot_10.json`. Autosave writes to the slot the house was opened from. The chronicle text export goes beside it.

## 5. Settings

A single list. Each row is a label on the left and its control on the right, 64 px tall, 1 px divider between rows.

| Setting | Control | Default | Notes |
|---|---|---|---|
| Text size | Three buttons: A · A · A (small, normal, large) | Normal | Sets the theme's base font size (22 px normal, 18 px small, 26 px large) |
| Tutorial hints | On / Off toggle | On | Shows coach cards during the tutorial and the first few events |
| Confirm before closing a house | On / Off toggle | On | Affects "Found a new house" |
| Replay the tutorial | Button | — | Restarts the tutorial in the current house |
| Chronicle ink | Off (later: sepia / plain) | — | Placeholder for art direction |

Settings are stored on their own, not per slot.

## 6. In-game screens

### 6.1 Header

Current: title, then a two-line status (date and feast; year, season, week, abbot, generation), resources in one run of text, forecast in one line.

Problems:
- The resource line wraps mid-item ("· 12 brothers" falls to a second line).
- The status is dense: abbot and generation compete with the date.
- "Today is St Michael the Archangel" is the only feast notice and is easy to miss.

Proposed (720 px wide, 16 px gutters, 8 px grid):

```
┌──────────────────────────────────────────────┐
│ Saint Enda's at Knockmore            [Menu ≡] │  title 30 px gold; menu icon 56 px
│ Wednesday 22 November 2502 · Today: St Andrew │  date 20 px; feast chip gold when today
│ Year 3 · Autumn, week 12 · Abbot Murtagh      │  status 20 px dim
├──────────────────────────────────────────────┤
│ [Food 120/320] [Firewood 16/120] [Medicine 3/4] │  resource tiles, 2 rows of 3 on a phone
│ [Books 8] [Goodwill 29] [12 brothers]          │
├──────────────────────────────────────────────┤
│ ⚠ Winter needs 104 food and 52 firewood.      │  forecast banner, red only when short
└──────────────────────────────────────────────┘
```

Each resource tile shows value and cap; a tile turns red when it is below the winter need. The feast chip is tappable and opens the day's feast description.

### 6.2 Tabs

Chronicle · Estate · Road. Tab labels 22 px; the active tab is underlined in gold. Chronicle shows a small dot when there are new entries since the last visit.

### 6.3 Estate

Sections, in order: brothers (one row each), buildings, The Rule (four axes), The house (saints, daughter houses, generation).

Brother row (as built, improved):
- Name, age, vocation on line one; path ("path: ?" or the path name) and the health word on line two when it matters.
- Traits and the top two skills on line three, dim.
- Job dropdown on the right, 190 × 56 px. Its label is the job name.
- A training brother shows "learning Scribing" in place of the health word.

A row is 96 px at minimum so the text does not crowd. Dropdowns keep 56 px height as a touch target.

### 6.4 Road

Map at the top (the sketch, at least 420 px tall), labels 16 px with a halo so they do not overlap. Tap a place to select it. Below the map: the selected place's name, faction and standing; the party checklist; Send the party; Send three brothers to found a daughter house.

Known issue: map labels overlap at some places. Fix with per-node label offsets in `map.json`.

### 6.5 Bottom bar

Four buttons, 64 px tall, equal width: **Next day · Next week · Until something · Menu**. "Until something happens" is too long for a quarter of the width and wraps; use "Until event" with a tooltip-style line under the bar: "runs until a choice, a feast or a chronicle entry".

When an event is waiting, the bar is hidden and the event sheet replaces it.

### 6.6 Event sheet

Title 24 px gold. Text 22 px. Choices full width, 64 px tall, 8 px apart. A check choice shows its skill and difficulty in brackets and, once tutorial hints are on, a small "rolls 2d6 + …" line below its label.

The sheet is a full-height panel that scrolls, so long text never pushes the choices off the screen.

### 6.7 Menu sheet

Opened from the menu icon. Rows, 64 px each:

1. Copy chronicle
2. Save chronicle as a text file
3. Settings
4. Back to the main menu (saves first; no confirm)
5. Found a new house (danger colour; confirm)

### 6.8 Fallen house

The annals end: the last chronicle entry is shown in full. Two buttons: **Found a new house here** (this slot) and **Back to the main menu**.

## 7. Tutorial (in-game, from a new house)

When a new house begins, a tutorial offer appears on the first screen:

> "Would you like the keeper's walk-through? It takes about five minutes and can be left at any step."
> **[Begin the walk-through]** **[Skip the tutorial]**

The tutorial runs inside the house, not as a separate scene:

- Each step dims the rest of the screen and shows a coach card (title, two lines, Next, and Skip all).
- A "Skip all" button is on every step and on the offer. Skipping sets the tutorial as done for that slot.
- A step waits for the player's action where one is needed (for example, "Set one brother to the fields").

Steps:

1. **The house.** The header, the date and the feast chip.
2. **The estate tab.** Brothers, jobs, the job dropdown.
3. **Time.** Next day, Next week, Until something happens; what the forecast means before winter.
4. **Your first choice.** The event sheet, a check choice, what the brackets mean.
5. **The road.** Tap a place, send a party.
6. **Skills and paths.** Skills grow by work; a "?" path is hidden until an event reveals it.
7. **Settings and the menu.** Where to save the chronicle, where to replay the tutorial.

Hints (the coach cards after the first game) follow the Tutorial hints setting. The tutorial state is stored per slot, so a house that was started before the tutorial existed is never shown it.

## 8. Recognition and wording

- Use the same verbs everywhere: **Next day**, **Next week**, **Until event**. Do not mix "week" and "turn".
- Icons next to resources (grain, wood, a cross, books, a heart for goodwill) — 24 px, in the tile.
- Button labels are verbs: "Send the party", "Found a new house", "Back to the main menu".
- Danger actions are red and confirmed: found a new house, delete a slot, quit with unsaved work (none, by design).

## 9. Spacing and touch

- Gutters: 16 px each side; top margin 44 px for the device status bar.
- Vertical rhythm: 8 px between related items, 16 px between sections, 24 px before a section title.
- Touch targets: at least 56 px tall; main buttons 64–72 px.
- Text: normal 22 px, small 18 px, large 26 px; titles 30–40 px.
- Maximum line length: about 40 characters in the body text at 22 px.
- Nothing scrolls sideways. The Estate and Road tabs scroll vertically only.

## 10. Implementation order (proposal)

1. **Slots:** split the save into ten files with a small index (name, date, year, brothers). Migrate the single file into slot 1 on first run.
2. **Main menu scene** with New, Load, Settings, Quit; the house moves to its own scene and is opened from a slot.
3. **Settings** with the text size and the two toggles, saved on their own.
4. **Header and bottom bar** layout changes (resource tiles, the feast chip, shorter labels).
5. **Event sheet** as a scrolling full-height panel, with check details.
6. **Tutorial** as coach cards on top of the house, with Skip all and replay.
7. **Road labels** offsets and the Chronicle tab's new-entry dot.

Each step is a commit and a push, as before, with the UI smoke test updated to open the menu, load a slot and play a few days.

## 11. Open questions

1. Ten slots fine, or fewer (three, say) with a larger card each?
2. Should Quit be shown on touch devices at all, or hidden (phones usually close apps from the system)?
3. Is "Continue" wanted in addition to the four buttons?
4. Tutorial: first game only, or offered again on every new house?
