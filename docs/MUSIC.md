# Music and sound effects

Status: built. 100 tracks, shuffle, follow the season, and sound effects for buttons, cards, deaths and the fall of the house.

## How it is made

- The 100 tracks are recipes in `data/music/tracks.json`, written by `tools/audio/make_tracks.py`. Each has a **moment** (16 of them: dawn, winter, storm, death and so on) and an **element** (14: bell, wind, rain, the Hollow, the engine and so on), with a mode, tempo, voice and texture. No two tracks share a moment and an element.
- The game synthesises each track from its recipe when it plays (`scripts/audio/synth.gd`). Nothing is stored as audio, so the repository stays small. A 40 second track takes about a second to render, in a background thread.
- Sound effects are synthesised the same way (`Synth.effect`): click, chime, bell, page, thunder, clash, horn, snuff, door and error.

## The player

- **The bar at the top of the house** shows the track now playing. Tap it to open the menu.
- **The menu** has previous, pause, next, shuffle, follow the season, music on or off, sound effects on or off, and the list of all 100 tracks. Tap a track to play it.
- **Follow the season** (on by default) plays a track of the season's moment: dawn in spring, work in summer, harvest in autumn, winter in winter. It changes when the season does. Choosing a track from the list turns it off.
- Tracks play one after another, each for its length, in list order or shuffled.

## Settings

Music and sound effects are saved in `user://settings.cfg` under `[audio]`.

## Not yet built

- Music that follows the scene of a card (a storm card changing the music).
- Volume controls. The music is at a fixed level under the sound effects.
- Track titles and sound effects are not yet checked by ear. The tests check that they are made and have sound in them.
