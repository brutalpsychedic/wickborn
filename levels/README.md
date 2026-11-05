# Level format

Each level is a plain text file. `tools/build_levels.gd` generates them, but you can also
edit them by hand. Re-running the tool overwrites manual edits, so pick one workflow per level.

```
[meta]       key=value lines
[signs]      one line per sign; digits 1-9 in the map refer to these lines in order
[overlay]    x0,y0,x1,y1 rectangles of hidden rooms (covered by fake terrain until entered)
[map]        the grid, one character per 32x32 px tile
```

## Meta keys

| key | meaning |
|---|---|
| `name` | display name (also listed in `scripts/autoload/game.gd`) |
| `theme` | palette/backdrop from `scripts/core/palettes.gd`: path, moss, village, woods, crystal, sunken, ruins, fortress, throne, sanctuary |
| `music` | calm, deep, ruins, throne, boss, sanctuary |
| `boss` | warden, king or dimming (needs a `B` in the map) |
| `boss_reward` | `heart` drops a Heart Wick when the boss dies |
| `upgrade` | upgrade granted on completion if the player skipped its pickup (dash, double_jump, quick_blade) |
| `lore` | text shown when the level's Memory Wick (`*`) is found |

## Map legend

| char | tile |
|---|---|
| `.` | air |
| `#` | solid ground (merged into large collision rectangles) |
| `=` | one-way platform (jump up through it) |
| `x` | crumbling slab (falls 0.5 s after you land, returns after 2.6 s) |
| `%` | cracked wall (3 sword hits) |
| `^` / `v` | floor / ceiling spikes (hazard: lose a flame, return to safe ground) |
| `~` | dark water (hazard) |
| `M` | moving platform, 3 tiles wide, centred here. `M----` moves right along the dashes; `|` cells above `M` make it an elevator |
| `G` | boss gate (vertical run, seals the arena while the boss lives) |
| `P` | player start |
| `C` | checkpoint lantern (heals, respawn point) |
| `E` | exit arch |
| `o` | ember (score) |
| `*` | Memory Wick (one hidden secret per level) |
| `H` | Heart Wick (+1 max health) |
| `D` `J` `Q` | upgrades: Dash, double jump (Twin Flame), Quickened Blade |
| `c` `f` `m` `r` `h` | crawler, shade wisp (flyer), sentry (melee), caster (ranged), brute (heavy) |
| `B` | boss spawn |
| `L` | decorative lantern |
| `1`-`9` | sign showing the matching `[signs]` line |

Place ground enemies, signs, checkpoints and exits in the air cell directly above the ground.

## Checking a level

```
godot --headless --path . --script res://tools/validate_levels.gd
```

The validator simulates the real jump, double-jump and dash physics from `P`. It reports any
exit, checkpoint or collectible that can't be reached. Design limits:

- single jump: rise up to 3 tiles, gaps up to 4 tiles
- dash jump: gaps up to 7 tiles
- double jump: rise up to 5 tiles
