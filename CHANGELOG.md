---
type: Changelog
title: "War Perang Tactics — Daily Changelog"
description: "Comprehensive record of architectural restructuring, game systems implementation, and testing."
tags: [changelog, architecture, godot4, gameplay]
generated: { by: human:aprxty3, at: 2026-08-23T00:00:00Z }
---

# Changelog

All major changes to the **War Perang Tactics** project are recorded below.

---

## 📅 Wandering Encounters, Castle Garrisons & the Turn Banner (2026-08-29)

The Black Castle sat in the middle of the map for four milestones holding
nothing. It is a den now: six creatures guard it, they raid rather than
conquer, and clearing them is what makes the keep in the centre of the board
worth walking to.

`scenes/test_milestone5.tscn` grew from **277 to 308 checks**, all passing.
Nine other suites: zero failures.

### 👹 Six monsters out of art that was never referenced
`assets/characters/enemy_animations/` had been in the repo since the start and
**no line of code had ever loaded it** — idle, movement, attack, death and
take-damage strips for three creatures. `scripts_dev/generate_monsters.py`
composes idle + movement into the same 6x2 sheet layout every other derived
unit uses, then rotates the garment palette to turn three bodies into six:

| | Body | HP / ATK / DEF / MOV |
|---|---|---|
| **Ghoul** | skeleton1, green | 38 / 14 / 2 / **4** |
| **Bone Stalker** | skeleton1, pale | 30 / 12 / 1 / **6** — the scout |
| **Grave Warden** | skeleton2, steel | **70** / 20 / **12** / 3 — the wall |
| **Plague Wraith** | skeleton2, violet | 40 / 22 / 3 / 3, **range 2** |
| **Blood Fiend** | vampire, crimson | 62 / **26** / 8 / 4 |
| **Dread Warden** | vampire, gold | **140 / 34 / 16** / 3, **range 2** — the boss |

They are deliberately *not* tuned against faction units of the same tier. A
monster costs nothing to field and never recruits; its job is to make the
centre of the map cost something, not to be a fair fight.

### 🚫 A rule shaped as a negative — `Building.claim_for()`
Three callers used to imply their own answer to "who may take what" by simply
calling `capture()`. There is now one function that answers it, returning
`CAPTURE`, `RAZE` or `NOTHING`:

- A **marauder cannot claim** a castle, a gold mine or an iron mine. It holds
  no ground, so those are scenery to it.
- A **held village it BURNS** rather than flying a flag over. A *neutral*
  village it leaves alone — an unclaimed house is nobody's supply line, and
  razing neutral ground would just strip the map.
- **Armies can claim the den.** Clearing it is the whole point of the
  encounter, and nothing extra guards that: the boss stands on the keep's own
  cell and a unit cannot end its move on an occupied one, so "kill the guardian
  first" is enforced by the board rather than by a rule.

`EventBus.building_destroyed` had been a `pass` in `EconomyManager` with a note
saying it depended on the node structure. It stopped being hypothetical the
moment a village could burn: without it an army kept the +2 troop capacity of a
village that no longer existed, permanently, because nothing else ever
decrements that count.

### 🕯️ `EncounterManager` — a turn, but not an army
Its own manager rather than an `AIManager` with four flags. An `AIManager`
plays to win: it recruits, banks gold, and values every building by what it
yields. None of that applies to a den. The *judgement* is still shared —
`AITacticalEvaluator` picks targets and scores swings here exactly as it does
for the armies, so a ghoul attacks through the same damage rules the player
attacks through.

Two rules shape it:
- **The leash.** No monster steps further than 11 cells from the den, enforced
  when a step is *chosen* rather than corrected afterwards — so a monster is
  never out of bounds even for a frame.
- **The boss never moves.** It swings at whatever comes into reach and is
  otherwise furniture. Killing it stops reinforcements: whatever is still
  standing stays, but the den stops being a source, so the centre can finally
  be cleared for good instead of bleeding a ghoul every third round.

### ⚖️ `contenders` split from `faction_order` in TurnManager
The monsters needed a turn without becoming a fifth contender. With one list a
den of ghouls counted as a surviving faction, "last one standing" was never
reached, and **a won match simply never ended**. `faction_order` is who takes a
turn; `contenders` is who can win or lose. `setup_match()` takes the marauders
as a third, defaulting-to-empty argument, so every existing two-argument caller
keeps the behaviour it had.

Two smaller consequences of the same split:
- **Monsters take no prisoners.** Refused in `MoraleManager.begin_surrender()`
  rather than at the branches below it, because both of those assume a captor
  with a treasury and a roster. A ghoul reaching `resolve_surrender` would press
  a captured knight into the undead ranks — a fine mechanic, and emphatically
  not this one.
- **An occupied building is not an objective this turn.** `get_path_cells()`
  temporarily un-solids both ends of a route so AStar can find one, so a keep
  with a boss parked on it still scored as reachable. Every army would march on
  the most valuable building on the board, fail the final step, and queue up
  outside it for the rest of the match. General rule, not a monster one.

### 🏰 A castle heals its garrison 40%
Villages resupplied at 20% since 2026-08-28; a castle now does double. It is
the one building whose loss ends the match, so the ground worth defending
hardest should also be the ground worth retreating to — and it gives the trip
to a castle for a promotion a second reason to exist. Both rates run through
one per-type table in the upkeep sweep rather than a test for `HOUSE`.

### 🎬 Retry goes to the faction screen; Quit goes to the menu
`reload_current_scene()` replayed the match with the army the player had just
lost with — the one choice a defeat argues against. Retry now returns to the
faction screen (which also re-rolls the board), and the button that used to
quit the application outright is **Main Menu**. Both unpause the tree first:
`paused` belongs to the `SceneTree`, not to the scene hanging off it, so
leaving it set carries the freeze into the menu and every button there does
nothing.

### 💣 Buried mines: 6 → 14
Six on a 30x20 board is one mine per hundred cells, and play-testing found what
that arithmetic predicts — whole matches passed without one going off. Minimum
spacing drops 5 → 4: the blast is 3x2, so four cells still leaves a gap no
single detonation can bridge, and fourteen at spacing five would have the
scatter quietly return fewer than asked.

### 🟣 The turn banner was blue for everyone
A literal `🔵` in the format string told a player commanding the Purple
Syndicate, every single turn, that they were blue. The pip comes off the
faction now. The monsters' turn reads **"🕯️ THE BLACK CASTLE STIRS…"** rather
than naming a fifth enemy — they are not an army, and announcing them as one
invites the player to count five opponents and wonder why one never recruits,
never expands and cannot be beaten for the win.

### 🧪 Two test failures worth recording
- **"the turn order carries all 4 armies"** went red, and it was right
  literally: turn order now carries five. The premise was stale, not the code.
  Its replacement is *stricter* — it asserts `contenders` separately, so it
  would fail if the marauders were ever folded back into the victory check,
  which is the exact bug the split exists to prevent.
- A **new check failed for a reason unrelated to what it tested**: it handed a
  gold mine to the same faction it then asked whether that faction wanted it.
  An army never marches on ground it already holds.

---

## 📅 God Nodes Split, Mines That Trigger, Fair Random Boards (2026-08-28)

Three passes in one day, in this order: break up the files that had grown into
god nodes, fix a hazard that could not be met, and make the board different
every match without making it unfair.

`scenes/test_milestone5.tscn` grew from **193 to 277 checks**, all passing.

### 🧩 Five god nodes became ten collaborators
`MatchController`, `MainHUD`, `TacticalUnit` and `MapObjectManager` had each
accumulated several jobs. Nothing about their behaviour changed; what changed is
that each extracted piece can now be exercised on a bare grid, without building
a match around it.

| New | Out of | Job |
|---|---|---|
| `ArmyMuster` | MatchController | Castle lookup, the ring search for standing room, unit instancing |
| `GridOverlay` | MatchController | The highlight layer |
| `PandoraTable` | MapObjectManager | What comes out of a chest |
| `UnitOverlay` | TacticalUnit | HP bar, morale strip, floating damage text |
| `ModalOverlay` | MainHUD | The dimmed blocking-panel skeleton both dialogs hand-built |
| `GameOverModal` · `SurrenderModal` · `UnitChoicePopup` | MainHUD | One dialog each |

`ModalOverlay` is the clearest case: two dialogs had independently built the
same seven-node skeleton — full-rect ColorRect, centred PanelContainer,
MarginContainer with four identical margins, VBoxContainer. `MOUSE_FILTER_STOP`
is the load-bearing detail in it, not decoration: a modal that lets clicks
through is cosmetic, and it is also why these are Controls rather than
`PopupPanel`s — a PopupPanel is dismissable by clicking outside, and neither of
these dialogs has a valid "no answer" outcome.

`GridOverlay` keeps no copy of what is selected. The controller stays the single
owner of that, so the two can never fall out of step.

### 💥 A buried mine you could walk over
Traps only fired when a unit **ended its move** on one. Six cells out of roughly
five hundred, and only the destination counted — so in practice they were
scattered onto the map and never met. A mine you can stride over on your way
past is not a mine.

New `EventBus.unit_path_walked(unit, path)` carries the whole route, emitted
**before** `unit_move_completed`, so a hazard the unit crossed has already
resolved by the time anything reacts to where it ended up — a mine that killed
the walker must not then be told the walker completed its move. The handler
re-checks `is_instance_valid(unit)` at every cell, because the rest of a route
belongs to a unit that may no longer exist.

Only traps trigger this way. A chest is opened by stopping to open it, and a
powder keg is a landmark you can see and route around; both stay
destination-only on purpose.

### 🎲 A different board every match, provably fair
`ResourceScatter` rolls a fresh mine-and-village layout each match. The rule
that makes it fair is structural: **it never places one building, only an orbit
of four** — a cell and its three mirror images.

Symmetry alone is not proof, because the terrain underneath is only *almost*
symmetric. So every candidate orbit is measured with a real Dijkstra sweep from
all four castles and **rejected unless the four distances tie exactly**. Not a
tolerance — a tolerance is how a map ends up with one army a turn ahead every
single match. If no measured-fair layout is found, the authored layout in the
scene file stands: a failure here costs variety, never fairness.

**Fuzzing found a real ordering bug that one run never would.** The first 24
rolls came out with 6 lopsided — one army reaching the iron two moves before
another. The cause was order: forests were planted *after* the scatter measured,
and forest costs 2 MP. Props are now dressed before the roll, so it measures the
terrain that will actually exist. Re-run: **60 of 60 rolls, spread 0.**

Reach bands per type were added in the same pass. Without them the roll was fair
but shapeless — one layout threw both village orbits 13 steps out, which is
perfectly fair and still a bad map. Villages now land 3–8, gold 3–11, iron 9–14,
keeping iron the contested centre prize.

### 🏘️ A village resupplies whoever holds it
20% of **maximum** health per upkeep to any unit standing on one of its own
villages — a hero on 20/100 leaves on 40/100, not 24/100. Villages were worth
taking for the troop capacity and worth nothing afterwards; this makes them
worth standing in, and gives a mauled army somewhere to pull back *to* instead
of only forward to die.

Ordered deliberately: the village feeds **before** the starvation check, so
holding one softens an over-capacity turn without cancelling it.

### 🔒 The troop ceiling now binds every way a unit can arrive
Recruiting always checked it. **Nothing else did.** There are three doors into
the roster and only one of them ever asked:

| Door | Before | After |
|---|---|---|
| Recruit at a castle | ✅ refused | ✅ + the message now names the unit's weight |
| **Claim a prisoner** | ❌ straight through | ✅ |
| **Chest mercenary** | ❌ straight through | ✅ |

The rule lives once, in `EconomyManager.has_capacity_for()`. The prisoner door
leaked in a specific way: the AI asks before it chooses, but the human is asked
by a *dialog*, and a dialog can be answered "capture" by an army with no room.
The Capture button is now greyed out with the reason written on it, and an
impossible claim reaching `resolve_surrender` is downgraded to a ransom —
enforced there because it is the single point every claim passes through.

### 🧪 A test that had been passing by luck
`TestMilestone4`'s fog check went red, and the engine was right. It put an enemy
in a forest and asserted it was invisible from a distance — but a leftover Blue
unit from an earlier section was standing one cell from that forest and could
see straight in, exactly as the *next* assertion required. The premise had never
been established; it passed until the forest moved. The test now picks a forest
that nothing is watching.

---

## 📅 Match Bootstrap — Main Menu, Faction Select & Four Armies (2026-08-27)

The game's main scene was `TestGridScene.tscn`, driven by a controller that still
lived in `scripts/test/`. A test board had been promoted into a product, and
three separate-looking gaps all came from that one fact: there was no main menu,
the player could not choose a faction, and only two of the five armies ever took
the field. This pass builds the layer that was missing underneath all three.

`scenes/test_milestone5.tscn` grew from 177 to **193 checks**, all passing.

### 🎬 The game boots from a menu now
- **`scenes/ui/MainMenu.tscn`** is the project's `run/main_scene`: Start Game and
  Quit, nothing else. Settings and Continue each need a system that does not
  exist yet (a settings store, a save layer), and a button that opens nothing is
  worse than no button.
- **`scenes/ui/FactionSelect.tscn`** builds one card per faction from
  `MatchSetup.participants` rather than authoring four buttons by hand — the
  participant list is what a campaign chapter will vary, and hand-authored
  buttons would silently disagree with it. Each card is tinted with its own
  faction colour so the choice reads at a glance.

### ⚙️ `MatchSetup` — a new autoload for "this match", not "the rules"
Deliberately separate from `GameConfig`, which is easy to confuse it with:
GameConfig holds rules that never change while the game runs, MatchSetup holds
what the player picked and changes every match. It has to be an autoload — the
choice is made on one screen and consumed on another, and
`change_scene_to_file()` frees everything in between.

It also answers *"is this faction the computer's?"* as **"a participant that is
not the player"**, rather than as a list of enemy ids. Adding a fifth army needs
no change there.

### ⚔️ Four armies where there were two
The pieces were mostly already in place and unused: `TurnManager.setup_match()`
has always accepted any number of factions, `EconomyManager` already registered
all five, and all five castles were already on the map. Three things were
actually blocking it:

- **`const PLAYER_FACTION`** in the controller. A `const` — which is precisely
  why the player could never be anything but Blue. Now `player_faction`, read
  from `MatchSetup`.
- **`AIManager` was a single node in the scene** with one `ai_faction_id`. It is
  now created per opponent at runtime, because which factions the computer
  drives depends on which one the player chose — something a scene file cannot
  express. `ai_faction_id` is assigned *before* `setup()`, since `setup` builds
  the tactical evaluator around it; the other order would have each AI scoring
  the board from the wrong side.
- **Two hardcoded `== RED_LEGION` tests** stood in for "is it the AI's turn".
  With three opponents that let the player keep full control through Purple's
  and Yellow's turns. Both now ask `MatchSetup.is_player()`.

The opening armies were six nodes saved in the scene file, which is a large part
of why the match could only ever be Blue versus Red — a scene file cannot hold
"three units for whichever factions happen to be playing". They are mustered in
code now, ring by ring outward from each faction's own castle, skipping water,
buildings and occupied cells. That moved a guarantee that used to come free from
hand-placement onto a search, so the suite checks it: nobody in the river, no two
units on one cell, every participant at full strength.

Black Coven is deliberately **not** a participant. It holds a castle as a neutral
prize but fields no troops and takes no turn, and is reserved for the campaign's
undead track.

### 📁 The match scene left `scripts/test/`
- `scenes/TestGridScene.tscn` → **`scenes/Match.tscn`**
- `scripts/test/TestGridController.gd` → **`scripts/game/MatchController.gd`**

Moved with `git mv` so the history follows. Every suite loads the new path. A
`--import` pass is required after pulling this: Godot resolves the script by UID
and the cached UID still points at the old location until the project is
rescanned.

`_setup_tactical_map()` split into `_build_terrain()` and `_finish_map_setup()`,
because the armies are now placed between the two halves — the river has to exist
before anyone can be mustered, and the props, fog and camera all need to know
where both the terrain and the armies ended up.

### 🐛 Three latent bugs that four factions exposed immediately
None is new; all three were invisible, or self-correcting, while exactly two
armies played. The third was found by playing the four-faction match rather than
by running the suite.

- **Any faction's annihilation was read as the player's victory.**
  `MainHUD._on_defeat_condition_met` ended the match on
  `faction_id != player_faction_id`. Correct with two armies. With four, the
  match ended the instant the first opponent fell, handing the player a win over
  two armies still standing. Victory is now decided solely by
  `victory_condition_met`, which fires when one army is all that remains.
- **Retry could never be won.** `TurnManager.setup_match()` cleared `match_over`
  but not `_is_game_over`, so a retried match advanced turns forever and could
  never declare a result. There were two latches and only one was being reset.
- **The resource bar showed whoever was playing, not the player.**
  `MainHUD._refresh_resources()` was called with the *active* faction. With two
  armies that self-corrected every time the player's turn came round — which is
  when a player looks — so it read as harmless. With four, the bar spends three
  quarters of every round displaying an opponent's treasury, and leaks the exact
  gold and iron the fog of war is otherwise hiding. The live `_on_gold_changed` /
  `_on_iron_changed` / `_on_capacity_changed` handlers had the same fault: they
  compared against `current_faction_id`. All five now use `player_faction_id`.
  Caught by reading the running HUD, not by a test — the suite ran with the
  player as the first faction in turn order, where the bug is invisible.
- `application/config/version` was never set, so the menu's version label
  rendered as a bare `v`: the key exists in `project.godot` even when blank, so
  `get_setting`'s default never fires.

### 🧹 Housekeeping
- `config/name` was still `"war-perang-tactics"` after the repo was renamed.
- `scenes/_vfx_preview.tscn`, a throwaway harness, had been committed twice.
  Removed.
- `GameConfig.faction_title()` — "Blue Kingdom", "Red Legion" — for menus with
  room for the full name. Only the house word is tabled; the colour still comes
  from `FACTION_SUFFIX`, so a faction renamed there is renamed everywhere.

---

## 📅 VFX Correction Pass 2 — Sheets, Keg Fire & Death Marker (2026-08-27)

Three faults found by watching gameplay recordings rather than by running the
tests. `scenes/test_milestone5.tscn` grew from 128 to **157 checks**, all passing.

### 🎞️ Every particle asset is a sheet — not just the fire ones
All eight files in `assets/effects/Particle FX/` are filmstrips of 8-12 frames.
The previous pass fixed only the three named `Fire_*`, because those were the
ones reported. `impact`, `crit`, `death`, `desert`, `explosion` and `ambush` were
still assigned flat, so each particle stretched an entire filmstrip across the
screen: a kill painted a red band six tiles wide, a keg a brown one across ten.

The test now iterates the **whole** `EFFECTS` table and asserts each row's
`hframes` against the real image's dimensions. A new row that forgets the field
fails instead of silently smearing.

### 🔥 A keg left no fire in the one place kegs actually sit
`_apply_blast` ignited only cells passing a flammability roll. Kegs are placed at
BRIDGE and ROAD chokepoints from `MapBuilder`'s own bridge analysis, and both
terrains are `flammable: 0.00` — so the only place a keg could realistically be
shot was the only place its blast could never leave a fire.

- A blast now ignites every cell it touches, with no roll. Terrain flammability
  still governs where fire **spreads on its own** (`spread_fire_from`), which is
  what that number was always for.
- Water is refused inside `ignite()` rather than by each caller, since callers no
  longer ask permission.
- Fire still burns `FIRE_LIFETIME_TICKS = 3` rounds, now asserted end to end.
- The trap's own `_is_flammable` guard was removed as redundant.

### 💀 Death spawned an explosion
`_on_unit_died` fired a red `Dust_02` burst. A spray of red debris is the
vocabulary of ordnance, not of a sword to the chest.

Deaths now play `assets/characters/dead/Dead.png` — a 7x2, 14-frame skull that
drops in, bounces, settles and sinks away. It shipped with the project and had
never been referenced by any script.

- The particle burst is gone entirely; the shake drops from 4.0 to 1.2 so a kill
  reads as a thump rather than as ordnance.
- `flipbook_at_cell` gained a `vframes` parameter and a `flipbook_at_position`
  sibling. Grid sheets need the row count for scale — a frame is
  `texture_height / vframes` tall — and a dying unit is mid-animation between
  cells, so snapping its marker to a cell centre would place it where the unit
  no longer is.
- The keg blast is fire-only now (blast front, fireball, flame, embers); the
  debris row that turned it into a brown cloud was dropped.

### 🐛 Found while testing
- A test that cleared the effect container with `free()` tripped
  `Lambda capture at index 0 was freed`: `burst_at_position` schedules its own
  deferred free through a lambda holding the particle node. Rewritten to
  snapshot the pre-existing children and inspect only what the death added —
  the error was self-inflicted by the test, not a fault in the effect.

## 📅 Fire VFX, Hit Glitch & Hidden Traps (2026-08-27)

A correction pass on Milestone 5's Visual Polish, plus one new hazard.
`scenes/test_milestone5.tscn` grew from 88 to **128 checks**, all passing; every
earlier suite (Milestone 4, battlefield, combat, upgrade, village, undead,
all-units) still passes unchanged.

### 🔥 The fire never actually animated
`assets/effects/Particle FX/Fire_01|02|03.png` are sprite **sheets** of 8, 10 and
12 frames. `VfxManager` assigned them as flat textures, so every particle drew
the entire filmstrip at once — which is why a detonating powder keg read as
orange grit instead of fire.

- Sheet-backed effects now go through a `CanvasItemMaterial` with
  `particles_animation`, `particles_anim_h_frames` and `particles_anim_loop = false`.
- The test asserts each row's `hframes` against the real image dimensions. A
  wrong count does not error — it silently plays part of a frame, i.e. exactly
  the bug being fixed — so trusting the table was not enough.
- Plain effects deliberately get **no** material: dust and debris are lit, not
  luminous, and would pay for a material they never use.

### 💡 Additive blending, and why the tints look wrong in isolation
Fire emits light, so overlapping flames must **add** rather than occlude; on the
default mix blend the nearest particle simply hides the ones behind it and a
cluster reads as opaque rubble.

The subtlety: an additive tint is not the colour you see, it is the colour
**added to whatever is behind it**. A warm `Color(1.0, 0.80, 0.42)` looked right
over black and summed into pale yellow over this map's grass. The fire rows now
carry green-starved tints (`Color(1.0, 0.38, 0.10)` and friends) that only look
correct once added. Caught by screenshotting against a grass backdrop — judged
over black, the wrong version passed.

- New per-effect `anim_speed`: these sheets end in smoke frames. A steady flame
  should reach them; a blast should expire while still luminous (0.65–0.7).
- Explosions are now four layers — blast front, fireball, debris, embers — where
  they were two.
- `fire_ignited` gets its own flame burst. `Fire`'s steady loop starts at
  whatever frame its tween happens to be on and cannot express ignition.

### ⚡ Hit feedback is a glitch, not a fade
`TacticalUnit._flash_damage()` tweened smoothly to red and back, which reads as
"tinted" rather than "struck" — the eye needs a discontinuity to register
impact. Replaced with five hard `tween_callback` cuts alternating a blown-out red
against a dark frame while the sprite jumps sideways.

- A second hit mid-glitch kills the first tween. Two live tweens racing is how a
  sprite ends up stranded tinted and offset, and a unit *can* be hit twice in one
  frame — a blast plus the fire it started.
- Jitters `sprite.position`, never `sprite.offset`: `offset` carries the baked
  `UnitData.sprite_offset` that normalises every unit to 38 px, so writing to it
  would fight the render-metric pass and misalign the unit permanently.

### 💣 Hidden traps (`scripts/mapobjects/Trap.gd`)
The only `MapObject` that renders nothing at all. `Chest` and `Barrel` are
landmarks you route around; a trap exists to punish a route that looked safe, so
drawing it even faintly would defeat it. No sprite, no adjacency tell, no reveal
mechanic — and **the AI walks the same blind map**, which is the only thing that
makes an invisible hazard fair.

- Placement reuses `MapBuilder._scatter_cells`, extracted from the existing chest
  scatter — the two differ only in spacing, and a copy would drift the moment
  either one's candidate filter changed.
- `HIDDEN_TRAP_MIN_SPACING` keeps traps apart so one step can never set off two.
- Traps are scattered **last**, after everything visible has claimed its cell, so
  a mine can never end up hidden under a chest.
- Named `HIDDEN_TRAP_*` because `PANDORA_TRAP_DAMAGE` already exists and is a
  different thing: that one punishes a unit for opening something, these punish
  it for walking.

### 🧨 The 3x2 blast
`spring_trap_at()` is deliberately **not** routed through `detonate_at()`. A keg's
blast is a Manhattan radius that chains into neighbouring kegs; a trap is a fixed
rectangle that chains into nothing. Merging them would mean threading a
shape flag and a chain flag through every call to save about six lines.

- Width 3 centres cleanly; height 2 cannot, so the extra row goes **above** the
  origin — the unit that stepped on the mine is always in the lower row and the
  blast reads as erupting upward out of it.
- Every flammable cell in the footprint catches, with no flammability roll: a
  keg's ignition is chancy, a mine is incendiary by design.
- `EventBus.trap_sprung(cells)` carries the whole footprint with the origin
  first, so `VfxManager` can centre the blast sprite without re-deriving the
  shape.

### 🐛 Found while testing
- **GDScript lambdas capture locals by value.** A test capturing the signal
  payload with `func(c): seen = c` updated the lambda's own copy and left the
  outer array empty. `seen.assign(c)` works because `Array` is a reference type.
  Two checks failed on this before it was understood; the product code was
  correct throughout.

## 📅 Milestone 5 — Advanced AI, Visual Polish, Mount System & Audio (2026-08-25)

Four of Milestone 5's five items. **Full Campaign is deliberately deferred**: it
needs a save/load layer that does not exist anywhere in the repo, and is alone
larger than all of Milestone 4.

**Verified**: `scenes/test_milestone5.tscn` — **88 integration checks, all
passing**. Every earlier suite still passes unchanged.

### M5.1 🧠 Advanced Enemy AI
- **`scripts/managers/ai/AITacticalEvaluator.gd`** (new, `RefCounted`): the AI's
  judgement, separated from its turn loop. `AIManager` decides *when* to act;
  this decides *what is worth doing*. The split is what makes the scoring
  testable — a test builds a board and asks "is this Gold Mine worth more than
  that Iron Mine" with no awaits, timers or signals.
- **Objectives ranked by value per step**, not proximity: `AI_OBJECTIVE_VALUE`
  ÷ real terrain-aware path cost, with a bonus for neutral over enemy-held.
  Measured live: a Gold Mine at cost 13 scores 6.25 against an Iron Mine at cost
  11 scoring 4.17 — the *further* objective correctly wins. The old
  nearest-building-wins rule could not express this at all.
- **Terrain-aware movement**: steps are chosen by real path cost with threat as
  the tiebreak. Manhattan distance used to decide this and could not tell a road
  (1 MP) from a forest (2 MP).
- **Defensive manoeuvring** (new behaviour, the Roadmap item's second half): a
  unit under 35 % HP, or standing where incoming threat is ≥ 90 % of its
  remaining HP, withdraws to the lowest-threat reachable cell with cover as the
  tiebreak. Verified: a 45 HP Pawn between two Warriors reads 96 incoming and
  retreats *at full health*. A killing blow is still taken first — a corpse
  cannot chase.
- **Attack scoring** replaces "lowest HP wins": expected damage ÷ target HP,
  minus the counter it will eat, plus kill and ambush bonuses. A swing scoring
  ≤ 0 is declined rather than trading a Knight into a Mage for chip damage.
- **Recruitment counters what it can see**, via the same advantage table combat
  resolves through.
- **`CombatResolver.preview_damage()`** promoted from private, plus
  `class_advantage()`. The AI must never own a second copy of the damage formula
  — a copy drifts the moment either side is tuned, and the AI would then plan
  against rules the player never experiences. A `def_cell_override` argument
  lets threat mapping ask "what would this cost if the unit stood *there*".

### M5.2 ✨ Visual Polish
- **`scripts/managers/VfxManager.gd`** (new): a pure EventBus consumer. No
  gameplay script holds a reference, so a scene that omits it behaves
  identically minus the sparkle — which is what the older focused test scenes
  need.
- Six burst types (impact, crit, death, desert, explosion, ambush) driving the
  previously-unused `assets/effects/Particle FX/` art through **one** shared
  spawn helper, not one function per effect. Death reads red and violent,
  desertion pale and drifting upward, so a rout is distinguishable from a kill.
- **CPUParticles2D, not GPU**: this project ships on the GL Compatibility
  renderer where the GPU path's extra features are unavailable anyway, and the
  CPU node needs no `ParticleProcessMaterial`.
- **Screen shake** — the last outstanding Dynamic Camera item — animates the
  camera's **`offset`, never `position`**. `position` is what `limit_*` clamps,
  so a position-based shake is silently flattened against the map edge, weakest
  exactly where the fighting tends to be. Reinforces rather than restarts, so a
  chain of explosions builds instead of stuttering.
- `MapObjectManager._spawn_explosion()` moved here: one explosion
  implementation instead of two owned by different managers.

### M5.3 🐴 Mount System
- **Eight-way facing from five sheets.** Only Lancer ships directional art, and
  it had been unused — the resources pointed only at `Lancer_Idle.png`, which
  fell into the single-row-strip fallback, so Lancer had no distinct attack
  animation at all. The three left-hand directions are the Right-side sheets
  mirrored.
- **`scripts/data/MountProfile.gd`** (new Resource) + `[M]`. Mounted: Cavalry,
  MOV 5, DEF 10. On foot: Melee, MOV 3, DEF 14. **Dismounting costs the unit's
  action** — without that price a rider could stand still swapping class to
  present whichever one beats its attacker, dodging the advantage triangle for
  free.
- **Bug this uncovered**: the Cavalry momentum charge was keyed on
  `att_class == "Cavalry" or "lancer" in att_name`, so a dismounted rider kept
  the charge purely because of what it was called — the mount system had no
  mechanical effect until this was fixed. Now class-only. The equivalent Rogue
  name check deliberately **stays**, because Skeleton Rogue is class `Undead`
  (so Holy Smite applies) yet is meant to backstab, and its name is the only
  thing that says so.
- **Backwards compatible by construction**: empty `directional_attack` and null
  `mount_profile` reproduce the old behaviour exactly. 86 of 91 unit resources
  needed no migration, covered by an explicit regression check.
- `scripts_dev/wire_mounts.py` wires the five Lancers idempotently, validating
  that every sheet exists and shares one frame size before touching a file.

### M5.4 🔊 Audio Overhaul
- **`default_bus_layout.tres`**: Master → Music, SFX.
- **`AudioManager` rewritten**: an 8-voice SFX pool (the old single player cut
  off its own previous hit — a busy melee sounded thinner than it was), tween
  crossfade between tracks, and combat ducking applied to the **bus** rather
  than the player so it survives a track change mid-fight. Track choice follows
  whose turn it is.
- **`scripts_dev/generate_music.py`** (new): the repo shipped no music at all,
  and crossfade/ducking cannot be judged against silence. Renders three loops
  with the stdlib only (numpy is absent), matching the existing SFX format.
  Every partial's frequency is snapped to a multiple of 1/loop-length so each
  completes a whole number of cycles; the loop point measures 0.08–0.22× the
  steepest slope already in the track. Placeholder scaffolding, not a
  soundtrack — drop real tracks at the same paths.
- Loop mode is forced on the stream at load: generated WAVs carry no `.import`
  loop setting, and the score would otherwise play once and leave the match
  silent.
- Volume API converts through `linear_to_db`, and **mutes at zero** instead of
  writing `-inf` dB.

### M5.5 🐛 Fixed along the way
- **`GridManager.get_path_cells()` corrupted the grid.** It restored `from_cell`
  to solid unconditionally while remembering the original state of `to_cell`, so
  asking for a route *from an empty cell* marked that cell permanently
  impassable — invisible until something later failed to path through it. It had
  zero callers and the AI was about to become the first. Now symmetric.
- **Cavalry charge keyed on unit name** — see M5.3.

---

## 📅 Fog Rendering, Economy Scale & Input Fixes (2026-08-25)

A bug-fix pass between Milestone 4 and 5. Every item below was reproduced live
through the Godot MCP session before being touched, and re-verified in-game
after — no fix is claimed on reasoning alone.

### F.1 🌫️ Fog of War — two separate bugs behind one symptom
- **Vision leaked to the map's top-left corner.** `TacticalUnit.grid_position` is a plain `var` defaulting to `Vector2i.ZERO` and the scene files only set pixel `position`; the cell is filled in by `GridManager`, which **defers** that to the end of the frame. `VisionManager.setup()` runs synchronously inside `_ready()`, so the first sight calculation saw all six starting units standing on cell `(0, 0)`. Blue's Archer (Ranged, vision 6) flooded a Manhattan-6 diamond around the origin — reaching Purple's castle at `(3, 3)`, exactly distance 6 — and because `_explored` never clears, that corner stayed permanently revealed. Red had the same phantom blob.
  - Fixed by making the registration callable ahead of time: `_auto_register_existing_units()` → **`register_existing_units()`** (public, idempotent), invoked from `TestGridController._setup_tactical_map()` before both the fog setup and the prop reservation. The `call_deferred` call remains as a safety net.
  - **Second bug closed by the same fix**: the prop-placement `reserved` list also reads `grid_position`, so trees and rocks had been avoiding `(0, 0)` instead of the units' real cells.
- **Unseen fog was fully opaque**, hiding the map rather than veiling it. `unseen`/`explored` alpha are now exported (`unseen_opacity` 0.78, `explored_opacity` 0.42) so the three states — visible / remembered / never seen — read as three distinct shades with the terrain still legible underneath.

### F.2 🌲 Tree sprites rendered with a sliver of the next frame
`Tree1.png`/`Tree2.png` are 1536x256 sheets holding **eight** 192 px frames, but `MapBuilder.TREE_SPECS` declared `hframes: 6`. Godot therefore sliced them at 256 px, so frame 0 carried its own tree **plus the 26 px left edge of the next frame's trunk** — the thin vertical strips beside every tree on the map. Corrected to `hframes: 8`. Verified by measuring the per-column alpha profile of both sheets: 8 content runs spaced ~192 px.

Audited the rest of the spritesheet declarations while there: `Rock1`/`Rock3`, `Fire.png` (896x128 ÷ 7) and `Explosions.png` (1728x192 ÷ 9) all check out, as do all 85 unit resources — their 6x2 grids divide cleanly, and the non-square frames are the generator's intentional crop.

### F.3 💰 Economy scale — Iron was worth 10x too much
`IRON_MINE_INCOME` was **30/turn** while the most expensive unit in the game costs **4 Iron** and a faction opens with **6**, so one captured mine funded 7.5 heavy units *per turn* and Iron stopped being a constraint after the first capture. Three independent signals agreed the constant, not the design, was wrong — unit costs, starting stock, and `PANDORA_SPOILS_IRON`'s 2-8 payout for a *rare* chest. Set to **3/turn**, which puts one mine at roughly one heavy unit per turn — the same ratio Gold already runs at.

### F.4 🏰 Castles now actually pay their stipend
`Building.get_income()` returned `gold = 20` for a Castle but **had zero callers anywhere in the repo**: `TurnManager` kept its own `match` over building types and simply never listed CASTLE. The passive income had never once been paid.
- Rather than adding a fourth parallel counter, `TurnManager` now **sums `bld.get_income()`** over the buildings a faction holds, and `collect_income(faction_id, gold, iron)` takes the totals. What a building type is worth now lives in exactly one place, and a future type earns income without either caller knowing it exists — which is precisely the duplication that hid this bug.
- The literal `20` moved to `GameConfig.CASTLE_GOLD_INCOME`.

### F.5 🧠 GeminiClient was failing every request
The log spammed `Gemini API request failed (HTTP 0)`. Not a deprecated model — two unrelated faults:
- **Timeout below the API's own latency.** Measured against the live endpoint, a banter line takes **1.3–2.1 s**; `request_timeout_seconds` was **2.0**. A timed-out Godot `HTTPRequest` reports `response_code = 0` with an empty body, which is where the meaningless "HTTP 0" came from. Raised to **10.0**.
- **The reply had no token budget left.** Gemini 3.x reasons before answering and `maxOutputTokens` covers thinking **and** output together. At 150 the model spent ~142 tokens thinking and had 4 left for the line, returning `finishReason: MAX_TOKENS` with text truncated mid-sentence (`"You cannot hide in"`) or no text part at all. Raised to **512**. Note `thinkingConfig.thinkingBudget = 0` does *not* help — this model ignores it.
- **Diagnosis was impossible by design**: the code read only `result_array[1]` and discarded `result_array[0]`, the `Result` enum, so a timeout, a dead link and a TLS fault all printed identically. Transport faults are now named (`"timeout after 10.0s — raise request_timeout_seconds"`).
- **Model switched to `gemini-3.5-flash-lite`.** Full Flash burned ~480 reasoning tokens and 2.5–5.6 s on a one-line battle cry — arriving after the fight it reacts to has ended. Lite answers the same prompt in ~1.2–1.8 s in-game. Also removed `_http_request`, a pooled `HTTPRequest` node built at startup and never used.

### F.6 🖱️ Left-drag camera panning
The camera only dragged on middle/right mouse, because left was owned by tile selection — and the grid acted on button **press**, which decides "click or pan?" before the cursor has moved and could answer it. Selection moved to **release**, and a **6 px** threshold separates the two: below it the release falls through as an ordinary click, above it the camera pans and marks the release handled so a drag never selects the tile it finished over. This works without any cross-reference between the two scripts — `TacticalCamera` is a child of the controller, so it receives unhandled input first.

---

## 📅 Milestone 4 — Advanced Tactical Systems & Morale (2026-08-23)

All six outstanding Milestone 4 systems shipped in one pass, plus the terrain
layer they all depend on. Verified by `scenes/test_milestone4.tscn` — **61
integration checks, all passing** — with the five existing suites unchanged.

### M4.1 🗺️ Terrain System & Movement Cost
- **`GameConfig.TerrainType` + `TERRAIN_RULES`**: every cell now carries a move cost, a damage-taken multiplier, a concealment flag, an ambush flag and a flammability. One table, consulted by combat, vision and fire alike.
- **`MapBuilder` derives terrain while it paints**, so a cell is Forest because a tree was actually drawn on it — the cover the player sees is exactly the cover the rules apply. Forest anchors now grow into 2-4 cell clumps instead of single decorative tiles.
- **`GridManager` is the single terrain authority** from then on: `get_terrain`, `get_move_cost`, `get_damage_taken_mult`, `is_concealing`, `is_ambush_cover`, plus runtime mutation via `set_terrain`.
- **Dijkstra movement field** replaces the uniform-cost BFS. Forest/rock cost 2 MP, road/bridge 1, so the west and east highways finally mean something. Reachability *and* the walked route come from the same field, which guarantees a unit is never offered a tile it cannot afford.

### M4.2 😰 Morale System
- **`MoraleManager.gd`** (new Logic-layer manager) is the only writer of morale. Nearby deaths, damage taken, flanking, ambushes, starvation, and captured/lost buildings all move it; it drifts back toward Fair each upkeep.
- **Scalar 0-100 on `TacticalUnit`**, with the five states derived from it — an enum FSM, per the state-machine decision flowchart (5 states, one concern, no nesting). Drives an attack multiplier of 0.80x–1.15x and desertion at Fearful.
- **Undead are immune**, derived from `unit_class` — no new resource field, no migration of the 91 `.tres` files.
- **Overhead morale strip** under each HP bar (hidden for undead), plus a full readout in the inspector panel.

### M4.3 🏳️ Surrender Mechanic
- A unit that **survives** an attack while Shaken or Fearful may break. It freezes as a prisoner — cannot act, move, or be attacked again — and its captor decides.
- **The player is asked** through a modal built as a full-rect Control with no cancel path (a `PopupPanel` can be dismissed by clicking away, which would strand the prisoner forever). **An AI captor decides itself**: take the prisoner if troop capacity allows, ransom them otherwise.
- **Captured units defect**, adopting the new owner's own art through the newly shared `UnitData.variant_for_faction()` — the same lookup `Building.resolve_for_owner()` now delegates to.

### M4.4 🌲 Terrain Ambush
- Attacking out of Forest **suppresses the counter-attack entirely** and lands a morale shock on the victim. Fills the `terrain_def_mult` hook that had been pinned to 1.0 since Milestone 1.

### M4.5 🌫️ Fog of War
- **`VisionManager.gd`** + `FogOfWarTileMapLayer` with a tileset generated in code, so the fog can never drift out of alignment when the grid is resized. Three states: unseen, explored-and-remembered, visible.
- **Advance Wars rules, not raycast LOS**: sight radius per unit class and building type, and units on concealing terrain are only spotted from an adjacent tile. Cheap, no corner cases, and familiar to the genre.
- **Symmetric — the AI is blind too.** `AIManager` targets only what it can see and keeps a last-known-position scouting report, so losing sight of an enemy makes it march on the last sighting rather than going passive.

### M4.6 💥 Environmental Hazards
- **`MapObjectManager.gd`** + a shared **`MapObject`** base for `Chest`, `Barrel` and `Fire` — all three are "one cell, reacts when stepped on, ticks once per round", so they share one base instead of three near-identical scripts.
- **Powder kegs** sit beside the bridge mouths, derived from the map's own bridge analysis rather than hardcoded coordinates. Detonate when stepped on or shot, deal TRUE damage, and **chain** through neighbours via a breadth-first walk over a visited set — each keg consumed before its blast is applied so it can never be queued twice.
- **Fire** damages whoever stands in it, spreads to flammable neighbours, and **burns forest down to `SCORCHED`**, permanently stripping that cell's cover, concealment and ambush. Explosions ignite with a boosted chance (`BLAST_IGNITION_MULT`) so forest always catches but grass only sometimes does.

### M4.7 🎁 Pandora's Box
- Seeded chest scatter (a fixed seed reproduces a layout exactly for tests), resolving into the four outcomes already priced in `GameConfig`: war spoils, a mercenary, a trap, or the awakened dead — who enlist under the opener's **enemy**.
- Closes a Milestone 3 gap: `skull_black.tres` ("Cursed Skull"), previously wired into nothing, is now what claws out of a cursed chest.

### M4.8 🐛 Pre-existing bugs found and fixed
Each was confirmed against the unmodified build before being touched.
- **Stale roster entries crashed the game.** `EconomyManager.get_used_capacity()` and `_apply_starvation()` ran `is` against roster entries without `is_instance_valid` — and `is` on a freed instance is a hard crash, not a false. Both are read on every HUD refresh and recruit check. Surfaced by the new test suite.
- **Discrete key commands accepted auto-repeat.** Space / R / U / Escape all fired on `echo` events, so *holding* Space would open the end-turn prompt and confirm it in the same breath. Fixed by dropping `event.echo` on all four — ending a turn, recruiting and promoting are one-per-press actions.
  - ⚠️ **Open, environment-side**: an idle match still advances by itself on this machine (~1 turn per 13s before the fix, ~1 per 35s after). Stack-dumping every `end_turn()` caller showed *all* of them arriving through the Space handler — never from the AI — and the same runaway reproduces on the unmodified pre-Milestone-4 build. Since the echo guard did not stop it, the remaining events are genuine discrete Space presses being delivered to the game window from outside the project (a chattering space bar, or another input source with focus). Worth checking the hardware before reading it as a game bug.
- **AI turn hardening** (defensive): `AIManager` awaited the *global* `unit_move_completed`, which resumes on whichever unit arrives first and never resumes at all if the move is rejected. Replaced with a bounded per-unit wait (`GridManager.is_unit_moving`) and a `_turn_running` re-entrancy guard.

---

## 📅 Summary of Today's Changes (2026-08-23)

### 1. 🌐 Language & Localization Standardization
- **English Translation**: Completely translated all documentation (`README.md`, `GUIDE.md`, `MEMORY.md`, `AGENTS.md`, `GEMINI.md`, `CHANGELOG.md`) and in-line code comments across all GDScript files from Indonesian to English.
- **AI Coding Philosophy**: Added strict enforcement of ROBUST, DRY, KISS, and YAGNI principles to all AI reference documents.
- **Roadmap Update**: Added the Unit Upgrade Tree and its branching logic to Milestone 3 in `Roadmap.md`.

### 2. 🧠 In-Game AI Narrative Engine (Gemini 3.7 Flash)
- **`GeminiClient.gd` Autoload**: Implemented a dynamic REST API client that interacts with Google's Gemini 3.7 Flash to generate dynamic, contextual dialogue for in-game combat and base captures.
- **Event-Driven Narrative**: Hooked into `EventBus.combat_resolved` and `building_captured` to broadcast `dialogue_generated` signals to the HUD.
- **Graceful Offline Fallback**: Safely defaults to offline hardcoded text if `GEMINI_API_KEY` is missing or rate-limited.

### 3. 🎭 Core Unit Archetypes & Animation System
- **Dynamic Animation Injector**: Upgraded `TacticalUnit.gd` to programmatically generate TinySwords-compliant animations (`idle`, `run`, `attack`) based on sprite dimensions, completely removing the need for manual track clicking and preventing out-of-bounds crashes.
- **Combat & Movement Animations**: `GridManager` and `CombatResolver` now natively call `play_animation("run")` and `play_animation("attack")` while handling sprite direction facing via `face_direction()`.
- **New Unit Data & Prefabs**: Generated accurate `UnitData.tres` and `TacticalUnit.tscn` prefabs for **Archer**, **Rogue**, **Wizzard**, **Priest**, **Skeleton**, and **Vampire**.

### 4. 🎮 Comprehensive UI, SFX & Victory Conditions (Milestone 2 Completed)
- **MainHUD (UI)**: Built a decoupled, responsive `MainHUD.tscn` (CanvasLayer) using `MarginContainer` and `PanelContainer` logic. Includes a Top Resource Bar, a Bottom-Left Unit/Building Inspector, and floating context action text.
- **Robust Victory Checks**: Upgraded `TurnManager.gd` to correctly calculate "Defeat by Castle Capture" and "Defeat by Annihilation" (0 units & 0 castles).
- **SFX Framework**: Created an `AudioManager.gd` autoload that seamlessly hooks into `EventBus` signals (`unit_move_completed`, `combat_resolved`, `victory_condition_met`). Generated procedural placeholder `.wav` assets for instant feedback.

### 5. 🩹 Dynamic Floating Health Bars & Combat Stat Rebalance
- **Overhead Health Bars**: Added dynamic, programmatic floating `ProgressBar` and `Label` to `TacticalUnit.gd` with smooth tweening and real-time color gradient indicators (Green > 50%, Amber 25-50%, Sekarat/Low Red <= 25%).
- **Combat Rebalancing**: Rebalanced unit stats across all unit `.tres` resources. Scaled Worker Pawn from 100 HP down to 45 HP (DEF 4) and Warrior to 75 HP (DEF 8), transforming combat from a 7-10 turn sponge slog into snappy, decisive 2-3 engagement tactics.
- **Bug Fixes**: Fixed `MainHUD.gd` property bindings (`attack_power` and `defense_power`), cleaned unused signal parameter warnings, and formatted recruit popup buttons with live cost displays.

### 6. 🏹 Dynamic Recruitment Spritesheet Injection & Combat Symmetry Fix
- **Dynamic Visual Binding**: Added `spritesheet`, `hframes`, and `vframes` exports to `UnitData.gd`. Upgraded `TacticalUnit.gd`'s `_update_visuals()` to dynamically hot-swap sprite textures and reconstruct TinySwords animation tracks on runtime instantiation.
- **Recruitment Prefab Resolution**: Fixed castle recruitment in `Building.gd` so recruited Archers, Warriors, Rogues, Mages, etc., properly render their distinct spritesheets instead of defaulting to the generic Pawn sprite.
- **Combat Symmetry & Resource Expansion**: Created `pawn_red.tres` and `warrior_blue.tres`, populated both Blue and Red castles with distinct recruitable rosters, and resolved the apparent "Pawn vs Pawn" damage imbalance (which occurred because enemy Red Warriors were previously displaying Pawn sprites while dealing Melee Advantage damage).

### 7. 🔄 TurnManager API Clean-up & Private Access Fix
- **Public `end_turn()` API**: Added a dedicated public `end_turn()` method to `TurnManager.gd` that cleanly handles transitioning to `END_TURN` and advancing to the next faction.
- **Private Access Warning Resolution**: Replaced direct external calls to private `TurnManager._end_current_turn()` in `AIManager.gd` and `TestGridController.gd` with `TurnManager.end_turn()`, resolving the `[private-access]` GDScript warning.

### 8. 🗂️ Asset Directory Restructuring, Archer Animation Fix & 5-Faction Unit Expansion
- **Asset Cleanliness & Reorganization**: Restructured the messy 24-folder `/assets` directory into 9 clean, intuitive categories: `audio/`, `buildings/`, `characters/`, `decorations/`, `effects/`, `items/`, `legacy/`, `terrain/`, and `ui/`. Automatically migrated and updated all path references across all `.tscn`, `.tres`, `.gd`, and `.import` files with zero broken links.
- **Archer Animation Resolution**: Fixed TinySwords Archer slicing bug by configuring correct dimensions (`1536x1344` $\rightarrow$ `hframes = 8, vframes = 7`). Upgraded `TacticalUnit.gd`'s animation generator to automatically map Row 3 (8 frames) for Archer attacks.
- **Complete 5-Faction Unit Rosters & Scene Prefabs**: Generated and verified **38 unit resources** (`.tres`), **45 unit scenes** (`.tscn`), and all **5 Faction Castle Prefabs** (`scenes/buildings/Castle*.tscn`) covering all lineages and color variants across all 5 factions with complete symmetry:
  - 🔵 **Blue Kingdom**: Blue Pawn, Blue Warrior, Blue Archer, Blue Knight, Blue Lancer, Blue Monk. (Castle_Blue)
  - 🔴 **Red Legion**: Red Pawn, Red Warrior, Red Archer, Red Knight, Red Lancer, Red Monk. (Castle_Red)
  - 🟡 **Yellow Empire**: Yellow Pawn, Yellow Warrior, Yellow Archer, Yellow Knight, Yellow Lancer, Yellow Monk, Yellow Priest, Yellow Wizzard. (Castle_Yellow)
  - 🟣 **Purple Syndicate**: Purple Pawn, Purple Warrior, Purple Archer, Purple Knight, Purple Lancer, Purple Monk, Purple Rogue. (Castle_Purple)
  - ⚫ **Black Coven / Necropolis**: Black Cultist Pawn, Black Guard Warrior, Black Archer, Death Lancer, Necromancer Monk, Skeleton Fodder (Base), Skeleton Warrior, Skeleton Mage, Skeleton Rogue, Cursed Skull, Vampire. (Castle_Black)
- **Comprehensive Headless Verification**: Automated multi-unit assertion test (`TestAllUnits.gd`) validating spritesheet textures, frame dimensions, and animation libraries across all 38 unit resources with 100% pass rate.


### 9. 🛑 End Turn Confirmation Modal & Lush 16x10 Battlefield Map Generation
- **End Turn Confirmation Modal**: Built a responsive, centered confirmation modal in `MainHUD.tscn` with a darkened backdrop (`Color(0,0,0,0.6)`). Prompts the player with *"End Your Turn?"* and Yes/No buttons. Pressing `[SPACE]` opens the modal; pressing `[SPACE]` again or clicking *"Yes"* confirms and ends the turn; pressing `[ESC]` or clicking *"No"* closes the modal safely without passing the turn.
- **Dynamic 16x10 Tactical Battlefield**: Added `_setup_tactical_tilemap()` in `TestGridController.gd` to completely fill the 16x10 grid with grass tiles, dirt pathways connecting Blue Castle, Neutral Gold Mine, and Red Castle, as well as natural flower/grass detail patches. Removed empty black void areas.
- **Automated Test Validation**: Added `scenes/test_popup_and_map.tscn` confirming 100% grid cell population (160 tiles) and modal state transitions with Exit Code 0.


### 10. ⚔️ In-Depth Combat Mechanics, Class Fighting Styles & Combat VFX
- **Class Fighting Styles & Special Traits**:
  - 🩸 **Vampire Lifesteal**: Recovers health ($+40\%$ of damage dealt) upon attacking.
  - ✨ **Mage Armor-Piercing**: Magical damage ignores $75\%$ of physical defense (`DEF * 0.12`), effectively countering heavily armored units.
  - 🛡️ **Knight Heavy Armor**: Endures physical damage with $-25\%$ flat physical damage reduction.
  - 🐎 **Cavalry Momentum Charge**: Devastating $+25\%$ damage bonus when initiating attacks against enemies.
  - 🗡️ **Infiltrator Backstab**: $+50\%$ critical backstab damage against targets.
  - ✝️ **Holy Smite**: Support/Monk/Priest units inflict $2.5\times$ Holy damage against Undead targets.
  - 🏹 **Ranged Advantage**: Attacks from $2\text{--}3$ tiles away prevent defender from executing melee counter-attacks.
- **Combat Visuals & Animation Polish**:
  - Dynamic floating damage text (`-X` in red, `+X` in green) with pop and float tween animations in `TacticalUnit.gd`.
  - Sprite flash effect (`_flash_damage()`) on taking damage.
  - Smooth death dissolve and fade-out animation before removal.
- **Automated Test Validation**: Added `scenes/test_combat_mechanics.tscn` verifying all 6 combat traits and calculations with 100% pass rate.


### 11. 🎯 High-Visibility Tactical Grid Highlights & Z-Index Elevation
- **Z-Index Layer Elevation**: Set `z_index = 2` for the grid drawing layer in `TestGridController.gd`. ~~Completely resolved~~ *(Correction: this alone did NOT fix it — see entry #12 below.)*
- **Vibrant Tactical Highlights**:
  - 🔵 **Reachable Move Cells**: High-contrast vibrant cyan-blue fill (`Color(0.12, 0.58, 1.0, 0.42)`) with glowing cyan borders and center pathing dot markers.
  - 🔴 **Attackable Cells**: High-contrast hazard crimson fill (`Color(1.0, 0.15, 0.15, 0.48)`) with bold red borders and precision crosshair reticle markers.
  - 🟡 **Selected Unit**: Golden pulse fill with bold double golden border (`Color(1.0, 0.92, 0.2, 1.0)`).
  - 🟢 **Selected Building**: Emerald green fill with glowing borders.
  - ◽ **Dynamic Cursor Hover**: Crisp white corner bracket highlights tracking the player's mouse over grid cells.


### 12. 🩹 Grid Highlight Occlusion — Actual Root-Cause Fix & Move-Completed Signal Crash
- **Root Cause Found**: The `z_index = 2` from entry #11 did nothing, because `TileMapLayer` is a **child** of the same node (`TestGridScene`) whose `_draw()` paints the highlights. With `z_as_relative` defaulting to `true`, the child's effective z-index rises together with its parent's, keeping them tied — and tied `CanvasItem`s paint in scene-tree order, so the child (`TileMapLayer`) always painted after (i.e. visually on top of) the parent's own `_draw()` output, regardless of the parent's `z_index` value.
- **Actual Fix**: Set `TileMapLayer.z_index = -1` (in `TestGridScene.tscn`) so terrain now has a strictly lower effective z-index than the root's highlight draw and its sibling `Units`/`Buildings`. Removed the now-inert `z_index = 2` line and replaced the misleading comment in `TestGridController.gd`.
- **Signal Signature Crash Fixed**: `EventBus.unit_move_completed(unit, from_cell, to_cell)` (3 args, emitted from `GridManager.gd:301`) was connected to `TestGridController._on_unit_move_completed(unit)` (1 arg) — every unit move threw `Method expected 1 argument(s), but called with 3` and silently skipped the handler body, which meant the player unit was never auto-reselected (and its highlights never redrawn) after finishing a move. Fixed the handler signature to accept all 3 arguments.
- **Noted, not fixed**: `CombatResolver.gd:73`'s post-attack idle timer can log a benign `Lambda capture ... was freed` error if a unit is freed within the 0.6s window after combat; low priority, does not affect gameplay correctness.


### 13. 🌳 Milestone 3 Foundation — Unit Upgrade Tree, Palette-Tint Shader & Roster Symmetry
- **Tier Data Fix**: `Warrior` was incorrectly tagged `tier = 1` (same as Pawn) despite being a clear power step up; corrected to `tier = 2` across all 5 factions.
- **Roster Symmetry**: Blue, Red, Purple, Yellow, and Black now all field the full Tier-2 roster (Warrior/Archer/Wizzard/Monk/Rogue) — previously only Purple had Rogue and only Yellow had Wizzard+Priest. Generated via a one-off script (`scripts_dev/generate_units.py`) per this project's own DRY principle rather than hand-authoring ~48 near-duplicate `.tres` files.
- **8 New Tier-3 Promotions** (×5 factions = 40 new units): Sniper & Crossbowman (from Archer), Archmage & Elementalist (from Wizzard), High Priest & Paladin (from Monk), Assassin & Shadowblade (from Rogue). Existing Knight/Lancer (from Warrior) folded into the same tree as-is.
- **`Priest` → `High Priest`**: The single existing `priest_yellow.tres` was retiered (2→3) and restatted into the Yellow High Priest, since `Monk` (already present on all 5 factions) became the tree's canonical Tier-2 Holy unit.
- **Runtime Faction Palette-Tint Shader** (`assets/shaders/faction_tint.gdshader` + `UnitData.needs_palette_tint` + `GameConfig.FACTION_TINT_COLORS`): Knight, Rogue, Wizzard, and every new Tier-3 unit that reuses a shared generic spritesheet (no hand-painted per-faction art exists) now render in their faction's color at runtime via `TacticalUnit._update_faction_tint()`, instead of every faction sharing one identical uncolored sprite.
- **Real Promotion Mechanic Wired Up**: `EconomyManager.get_upgrade_cost()`/`process_upgrade()` (Field Tax included) and `TacticalUnit.upgrade_to()` already existed but nothing called them. Added `[U]` key + `MainHUD.show_upgrade_popup()` (mirrors the existing `[R]` Recruit popup) so players can actually promote a selected unit through its `upgrade_paths`.
- **Recruitment Model Change**: Tier-3 units removed from Castle `recruitable_units` (including Yellow's former direct-recruit `priest_yellow.tres`) — they are now reachable only via promotion, which is the actual point of an "Upgrade Tree."
- **`CombatResolver.gd`**: Added `"paladin"` to the Holy-vs-Undead bonus name check so the new Holy Tier-3 melee unit gets its intended $2.5\times$ bonus.
- **New Test**: `scenes/test_upgrade_flow.tscn` / `TestUpgradeFlow.gd` verifies promotion success, HP-ratio scaling, Field Tax pricing (2x off-Castle), the insufficient-funds guard, and palette-tint flags end-to-end.
- **Deferred**: Black Coven's separate Undead lineage (Skeleton/Vampire → Lich/Vampire Lord/Nightstalker) has its own tier inconsistencies and was intentionally left out of this pass — see `Roadmap.md` Milestone 3.


### 14. 🏚️ Milestone 3 Completion — Village Economy, Troop Capacity Fix & Undead Lineage
- **Troop Capacity Bug Fix**: `Building.capture()` only ever reported the *new* owning faction via `EventBus.resource_node_captured`, so `EconomyManager` incremented the capturer's village count but never decremented the previous owner's — recapturing a village permanently inflated whoever held it first. Signal now carries both `new_faction_id` and `old_faction_id`; `EconomyManager._on_resource_node_captured` decrements the loser and increments the winner.
- **Village Economy Nodes Shipped**: `BuildingType.HOUSE` was already wired end-to-end (`"village"` type string, `+10` Gold via `collect_income`, `+2` TC via `get_max_capacity`) but no scene or map content existed. Added `scenes/buildings/House.tscn` (neutral, capturable, mirrors `GoldMine.tscn`'s pattern) and placed two neutral villages on `TestGridScene.tscn`.
- **`Building._update_visuals()`**: extended the faction modulate-tint match from 2 factions (Blue/Red) to all 5, so Purple/Yellow/Black captures now render distinctly instead of falling into the generic grey default.
- **Undead Lineage Reconciliation**: Black Coven's Skeleton/Vampire sub-tree is now a finished parallel track, independent of the human tree, reusing the identical `[U]` Upgrade mechanic with no new UI/backend code. `skeleton_black.tres` (Skeleton Warrior) retiered 1→2; previously-orphaned `skeleton_mage_black.tres`/`skeleton_rogue_black.tres` wired into `skeleton_base_black.tres`'s (Skeleton Fodder) `upgrade_paths`; `vampire_black.tres` retiered 3→2 and restatted into a Castle-recruitable Tier-2 entry point. 5 new Tier-3 units created — Bone Reaper, Lich, Wraith, Vampire Lord, Nightstalker — reusing existing small icon art (`skeleton1`/`skeleton2`/`skull`/`vampire v2`) rather than the palette-tint shader, since Undead units don't vary by faction.
- **`CombatResolver.gd`**: added `"nightstalker"` to the Vampire Lifesteal name check (previously only `"vampire"`, which would have silently excluded Nightstalker from its own signature trait).
- **Dropped `Recruitment Pool Refresh`**: this Roadmap item predated Tier-3 becoming promotion-only; a Castle-side elite-unit refresh timer no longer means anything once elites are never recruited at Castles.
- **New Tests**: `scenes/test_village_capacity.tscn` / `TestVillageCapacity.gd` verifies capture, recapture, and the capacity decrement-on-loss fix headlessly (avoids the live-mouse-click calibration issues noted in a prior session). `TestUpgradeFlow.gd` extended with a Skeleton Fodder → Skeleton Mage → Lich case to confirm the shared promotion mechanic works identically for the Undead track.
- **Known remaining gap**: `skull_black.tres` ("Cursed Skull") exists as a resource but isn't wired into any recruit list or upgrade path — flagged, not fixed, in this pass.


---

### 15. 🎨 Sprite Derivation Pipeline — Every Promotion Now Looks Different
- **The bug**: 13 of the 18 Tier-3 units re-used their Tier-2 parent's texture *verbatim*
  (`sniper_*.tres` and `crossbowman_*.tres` both pointed at `Archer_{Faction}.png`;
  `archmage`/`elementalist` at the Wizzard sheet; `assassin`/`shadowblade` at the Rogue
  sheet; `vampirelord` at the Vampire icon; `lich` at the Cursed Skull icon). Promoting a
  unit changed its stats and nothing else on screen.
- **`scripts_dev/spritegen_lib.py` + `generate_sprites.py`**: no image-generation model is
  available to this project, so **66 spritesheets are derived from their parent art** —
  the garment palette is hue-rotated onto the faction hue (skin tones and linework
  detected and excluded, so a Red wizard no longer gets a jaundiced face), then the role
  applies its own value/saturation treatment, a rim light, and a pixel accessory.
- **Role markers**: Paladin/High Priest halo, Archmage orb, Elementalist flame, Assassin &
  Bone Reaper eye-glint, Lich crown, Wraith/Shadowblade/Nightstalker wisps, Vampire Lord
  circlet. Sniper reads as a dark forest ranger and Crossbowman as pale steel — both tuned
  strong enough to survive the ~0.46 in-game downscale, where a rim alone is invisible.
- **The runtime palette-tint shader is gone.** `UnitData.needs_palette_tint` and
  `TacticalUnit._update_faction_tint()` are removed; faction color is baked into real art.
  This deliberately reverses the shader decision recorded earlier today — see `MEMORY.md`,
  which documents the reversal and why the original rationale no longer holds.
- **Idle + Run in one sheet**: derived sheets are 6x2 (row 0 idle, row 1 run) instead of a
  4-frame idle strip, so the 32px units finally animate while moving.
  `TacticalUnit._setup_default_animations()` gained a compact-layout branch for them.

### 16. 📏 Unit Render-Size Normalisation (the "mage is tiny" bug)
- **Root cause**: source frames range from 16x16 icons (Vampire, Lich, High Priest) through
  32x32 strips (Wizzard, Knight, Rogue, Skeletons) to 192x192 and 320x320 TinySwords sheets
  — yet every unit node was hard-scaled to `0.45`. Measured on a 64px tile that rendered a
  Warrior at 41px, a Pawn at 27px, a **Wizzard at 14px** and the undead icons at **7px**.
- **Fix**: two new baked fields on `UnitData` — `sprite_scale` and `sprite_offset` — applied
  by `TacticalUnit._apply_sprite_metrics()`. Unit nodes now stay at `scale = 1.0`; the
  hardcoded `0.45` is removed from `Building.recruit_unit()` and from the scene.
- **Baked, not guessed**: `scripts_dev/wire_units.py` measures each sheet's **idle-row**
  content bounding box and solves for `TARGET_CHAR_PX = 38`. Measuring the union of *all*
  rows was tried first and is wrong — a unit with a wide attack swing shrinks its resting
  pose to keep the widest frame in budget. All 91 units now render at exactly 38px.

### 17. 🚩 Faction Ownership Is Visible on Every Captured Building
- **`Building._update_faction_texture()`** replaces the old `modulate()` tint with a real
  texture swap out of `assets/buildings/{Blue,Red,Purple,Yellow,Black} Buildings/` — a
  captured Castle/Village/Tower now *becomes* the capturing faction's building.
- **`Building._update_faction_banner()`**: Gold and Iron mines have no per-faction art in
  the pack, so they fly a generated pennant in `GameConfig.FACTION_TINT_COLORS`, anchored
  above the sprite whatever its size. Neutral buildings fly none.
- **`Building.resolve_for_owner()`**: a captured castle recruits the **new owner's** unit
  variants. Blue taking the Yellow keep no longer fields yellow-sprited Blue troops. Costs
  are priced off the resolved variant in both `can_recruit()` and `recruit_unit()`.
- **Two authored-scene bugs fixed**: `Castle_Black.tscn` was pointing at
  `Castle_Destroyed.png` (the Black Coven's keep rendered as a ruin), and the *neutral*
  village used `House_Blue.png`, so uncaptured villages already looked like the player's.
  `GoldMine.tscn` also never declared `faction_id`, defaulting to `0` (Blue) instead of Neutral.

### 18. 🗺️ 30x20 Battlefield, Terrain, and a Pan/Zoom Camera
- **`scripts/managers/MapBuilder.gd`** (new, Logic layer): builds the battlefield from
  layout constants and hands the impassable cells to GridManager. Two rivers cut the map
  into a west flank, a contested centre and an east flank; roads are drawn as L-segments
  between waypoints and **every road/river crossing automatically becomes a bridge**, so
  the 8 bridge tiles sit exactly where the routes need them.
- **Four stacked `TileMapLayer`s** (water -4, ground -3, path -2, bridge -1): water fills
  the whole rect underneath, so the grass blob's own edge tiles form the shoreline. The
  tileset gained two atlas sources (`Water.png`, `Bridge_All.png`).
- **Blob-tiling fix**: `Tilemap_Flat`'s 4x4 blocks are a strict edge lookup (col 0 = left
  edge, 1 = none, 2 = right edge, 3 = both; rows likewise), verified by sampling every
  tile's border bands. A first attempt randomised columns 1/2 for "variety" and rendered
  the field as a maze of stray edges.
- **Map contents**: 5 faction castle slots (Purple NW, Red NE, Blue SW, Yellow SE, Black
  Coven centre — the contested prize), 4 Gold Mines, 2 Iron Mines, 6 Villages, 20 forest /
  rock props placed off roads, water and building approaches.
- **`scenes/buildings/IronMine.tscn`** (new): `BuildingType.IRON_MINE` was wired end-to-end
  in `EconomyManager` but had no scene and had never appeared on a map. Its art is a
  desaturated derivation of the Gold Mine sprite.
- **`GridManager`**: new `set_terrain_blocked()` / `set_terrain_blocked_cells()` /
  `get_map_pixel_size()`. Terrain blocking is kept separate from unit occupancy so a unit
  dying on a bridge cannot clear the river beside it.
- **`scripts/ui/TacticalCamera.gd`** (new): WASD/arrows, middle- or right-drag, and edge
  panning, plus wheel zoom clamped to 0.55–2.0. `Camera2D`'s own `limit_*` properties do
  the clamping, so the view can never leave the map. Pulled forward from Milestone 5
  because a 1920x1280 battlefield no longer fits one screen.
- **Also fixed**: `hovered_cell` was drawn by `_draw()` but never assigned — the hover
  cursor had never once appeared. `project.godot` now sets nearest-neighbour texture
  filtering (pixel art was being bilinear-filtered) and a 1408x792 default viewport.

### 19. 🏷️ Unit Names, Naming Convention, and Tooling
- **Faction prefix stripped from `unit_name`** across all 91 resources — the Recruit and
  Upgrade popups render `unit_name` verbatim, so a Blue castle was offering "Blue Pawn".
  Flavour names are preserved (`Cultist Pawn`, `Guard Warrior`, `Death Lancer`,
  `Necromancer Monk`). Verified safe: every name-based branch in `CombatResolver.gd`
  matches on role words (`vampire`, `wizzard`, `knight`, `paladin`, `skeleton`), never colour.
- **`priest_yellow.tres` -> `highpriest_yellow.tres`** (+ its scene), the last unit not
  following `{role}_{faction}` — a landmine for anything resolving units by convention,
  including the new `resolve_for_owner()`.
- **New dev tooling** in `scripts_dev/`: `spritegen_lib.py`, `generate_sprites.py`,
  `wire_units.py`, `validate_project.py` (static integrity check — ext_resource paths,
  frame divisibility, upgrade-path targets, baked metrics, name prefixes),
  `preview_map.py` and `preview_units.py` (render the map and the unit lineup to PNG for
  visual review without the engine). `generate_units.py` is frozen — it would reintroduce
  the removed `needs_palette_tint` property.
- **Tests**: `scenes/test_battlefield.tscn` + `TestBattlefield.gd` (map shape, terrain
  blocking, bridge crossability, capture texture swap, owner-variant recruitment).
  `TestUpgradeFlow.gd`'s palette-tint assertions are replaced by ones that check what the
  bug reports were actually about: every promotion swaps its spritesheet, no unit_name
  carries a faction prefix, and every unit carries baked render metrics.

---

## 📅 2026-08-22

### 1. 🏗️ Architecture & System Foundation (Decoupled Data-Driven)
- **4-Layer Architecture**: Changed the project architecture from a monolithic/tightly-coupled design to a separated 4-layer architecture:
  1. **Data Layer**: Pure `.tres` Resources without logic (`UnitData.gd`).
  2. **Event Layer**: Centralized signal hub Autoload (`EventBus.gd`).
  3. **Logic Layer**: Game rule managers (`TurnManager`, `EconomyManager`, `GridManager`, `CombatResolver`, `AIManager`).
  4. **Actor Layer**: Visual nodes on the map (`TacticalUnit`, `Building`).
- **Global Autoloads**:
  - [`scripts/autoload/EventBus.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/autoload/EventBus.gd) — Central typed signal hub with warning-free annotations.
  - [`scripts/autoload/GameConfig.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/autoload/GameConfig.gd) — Global Enums (`Faction`, `Phase`, `UnitClass`, `DamageType`, `MoraleLevel`) and calculation constants.
  - [`scripts/autoload/TurnManager.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/autoload/TurnManager.gd) — 4-phase turn state machine (`UPKEEP` ➔ `PRODUCTION` ➔ `ACTION` ➔ `END_TURN`).
- **Data Model & Actor Refactor**:
  - [`scripts/data/UnitData.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/data/UnitData.gd) — Custom Resource for stats, Gold/Iron recruitment costs, and Troop Capacity weights.
  - [`scripts/units/TacticalUnit.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/units/TacticalUnit.gd) — Actor node with movement & action consumption system, damage handling, and upgrades.

### 2. 🗺️ Grid System, Pathfinding & Movement
- **GridManager ([`scripts/managers/GridManager.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/managers/GridManager.gd))**:
  - Configured Godot 4.7's native `AStarGrid2D` with orthogonal mode (4 directions).
  - Two-way coordinate conversion: `world_to_grid()` and `grid_to_world()`.
  - Movement range calculation using the **BFS (Flood Fill)** algorithm capped by `movement_points`.
  - Attack range calculation using **Manhattan Distance** (`attack_range_min` to `attack_range_max`).
  - Smooth unit movement animation using sequential `Tween` between tiles.
  - Detection and auto-capture of buildings when a unit reaches its destination tile.

### 3. ⚔️ Combat & Tactical System (Combat Advantage)
- **CombatResolver ([`scripts/managers/CombatResolver.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/managers/CombatResolver.gd))**:
  - Base Damage Formula: `max(1, ATK - (DEF * 0.5))`.
  - **Combat Advantage Triangle**: Multipliers 1.5x (Advantage), 0.7x (Disadvantage), 2.5x (Holy vs Undead).
  - **Counter-Attack**: Defending enemies automatically retaliate if they survive and the attacker is within their attack range.

### 4. 💰 Economy, Buildings & Recruitment System
- **EconomyManager ([`scripts/managers/EconomyManager.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/managers/EconomyManager.gd))**:
  - Multi-faction treasury management (Gold, Iron, Troop Capacity).
  - Field Tax calculation when upgrading outside a castle (200% cost).
  - Starvation / Logistics Collapse system if unit count exceeds troop capacity.
- **Building System ([`scripts/buildings/Building.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/buildings/Building.gd))**:
  - 5 Building Types: Castle, Gold Mine, Iron Mine, House/Village, Tower.
  - Passive income generators: Gold Mine (+50 Gold/turn), Iron Mine (+30 Iron/turn), House (+10 Gold & +2 TC).
  - Recruitment at Castle (`[R]`): Validates Gold, Iron, and TC, then instantiates units on empty tiles around the castle.

### 5. 🤖 NPC / Enemy Tactical AI
- **AIManager ([`scripts/managers/AIManager.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/managers/AIManager.gd))**:
  - Full automation for the Red Legion's turn (`Faction.RED_LEGION`).
  - Recruits new troops at the Red Castle if the faction treasury allows.
  - Selects strategic targets: capturing the nearest gold mine or hunting player units.
  - Finisher logic: prioritizes attacking the unit with the lowest remaining HP.
  - Natural animation pacing (0.4s delay per action) and automatically ends the AI turn.

### 6. 🎮 Playable Interactive Testbed
- [`scenes/TestGridScene.tscn`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scenes/TestGridScene.tscn) & [`scripts/test/TestGridController.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/test/TestGridController.gd):
  - Visual Grid Overlay: Blue (Walkable Area), Red (Attackable Area), Yellow (Active Unit), Green (Active Castle).
  - Live HUD Header: Displays Gold, Iron, Troop Capacity, and realtime Combat reports.
  - Hotkeys: `[ESC]` quit, `[SPACE]` switch turn / End Turn, `[R]` recruit unit at Castle.

### 7. 📚 OKF (Open Knowledge Format) Documentation Standardization
- All documents in `docs/` have been reorganized and equipped with OKF v0.2 frontmatter:
  - `GDD_Overview.md`, `Macro_Economy.md`, `Technical_Specs.md`, `Architecture.md`, `Factions_and_Units.md`, `Terrain_and_Buildings.md`, `Roadmap.md`, and `index.md`.
- Automated **Git Hooks** integration (`graphify hook install`).
- `/graphify update` synchronization generated **414 nodes, 499 edges, 42 communities**.

---

### 12. 🛡️ Engine Warning Elimination, Lambda Capture Safety, & Concurrent HTTP Refactor
- **EventBus Warning Cleanliness**: Added `@warning_ignore("unused_signal")` to every single signal declaration in `EventBus.gd`, completely silencing 30+ GDScript reload warnings in the Godot editor.
- **Lambda Capture Lifetime Safety**: Refactored timer and tween callbacks in `CombatResolver.gd`, `GridManager.gd`, and `MainHUD.gd` from capturing raw objects in anonymous closures to using `Callable.bind()` helper methods (`_on_combat_animation_timeout`, `_on_unit_move_tween_finished`, `_on_recruit_button_pressed`, `_on_upgrade_button_pressed`). Completely eliminated Godot runtime errors: `call: Lambda capture at index X was freed. Passed "null" instead.`
- **Concurrent Gemini HTTP Requests**: Upgraded `GeminiClient.gd` to spawn dedicated, lightweight `HTTPRequest` child nodes dynamically per request and automatically `queue_free()` them upon completion. Completely resolved: `HTTPRequest is processing a request. Wait for completion or cancel it before attempting a new one.`
- **Compiler Warning Polish**:
  - Prefixed unused parameters (`_building` in `EconomyManager.gd`, `_new_unit` in `TestGridController.gd`).
  - Removed unused local variable `has_any_buildings` in `TurnManager.gd`.
  - Renamed corner bracket coordinates in `TestGridController.gd` (`tl`, `tr`, `bl`, `br` $\rightarrow$ `pt_tl`, `pt_tr`, `pt_bl`, `pt_br`) to prevent shadowing `Object.tr()`.
  - Replaced ternary enum assignment in `TacticalUnit.gd` with explicit `if/else` block to eliminate incompatible ternary warnings.
- **Skill Customization Synchronization**: Created modern, comprehensive `war-tactics-dev` skill definitions in `~/.gemini/config/skills/`, `.agents/skills/`, and `docs/skills/`.

### 13. 🎯 Initial Troop Capacity, Starvation Bug, Lancer Size Normalization & Godot-AI MCP Testing
- **Bug Fix #1 (Starting Troop Capacity 10/8 -> 5/8)**:
  - Fixed starting Red units in `TestGridScene.tscn` (`Red_Pawn`, `Red_Warrior`, `Red_Archer`) and unit scenes in `scenes/units/` lacking `faction_id = 1`, which previously caused all 6 units on the map to default to `faction_id = 0` (Blue Kingdom).
  - Added defensive auto-resolution of `faction_id` in `TacticalUnit._initialize_from_data()` based on `unit_data` resource filename.
  - Blue and Red factions now both start cleanly at exactly `5/8` capacity (1 Pawn + 2 Warrior + 2 Archer).
- **Bug Fix #2 (Starting Troops HP Dropping Below 100%)**:
  - Root cause identified: The 10/8 capacity overflow caused `EconomyManager.check_logistics()` to trigger Starvation Damage (15 True Damage) during Turn 1 Upkeep.
  - Resolving capacity to 5/8 completely eliminated accidental starvation. All starting units now begin at 100% full health.
- **Bug Fix #3 (Lancer Small Sprite Size Normalization)**:
  - Root cause identified: Lancer's 320x320 sprite contains an upright lance extending 72px above the rider's head. The previous bounding box included the lance pole (150px total), which shrank the horse+rider down to 19.5px tall on a 64px tile.
  - Re-normalised Lancer's mounted body (79px) across all 5 factions (`lancer_*.tres`) to `sprite_scale = 0.50` and `sprite_offset = Vector2(11.0, 1.0)`. The horse and rider now render at a proportionate 38.5px height matching foot soldiers, with hooves planted at +19px.
- **Automated MCP Testing (`godot-ai`)**:
  - Built `tests/test_units.gd`, `test_battlefield.gd`, `test_combat.gd`, `test_economy.gd` inheriting `McpTestSuite`.
  - Executed live test runner via `godot-ai` MCP server `test_run(verbose=True)`: **4/4 suites passed (563 assertions, 0 failures, 8ms runtime)**.
  - Updated `AGENTS.md` and `GEMINI.md` QA checklists to require automated `godot-ai` MCP testing before turn completion.

### 14. 🧛 Undead (Skeleton, Vampire) Recruitment & Tile Selection Bug Fix
- **Bug Fix (Vampire and Skeleton Not Moveable / Missing Tiles on Click)**:
  - Root cause identified: `TacticalUnit._initialize_from_data()` contained a filename-based override that forcibly set `faction_id = BLACK_COVEN` (4) whenever `_black` appeared in the `unit_data` resource path. When the player (Blue Kingdom, faction 0) recruited an undead unit (Skeleton Fodder, Vampire) at Castle Black, this override changed the unit's owner to enemy Faction 4.
  - Because `unit.faction_id` (4) != `TurnManager.get_current_faction()` (0), clicking on the unit treated it as an enemy, displaying "⚠️ Enemy unit! Select your own unit." and blocking movement/attack tiles.
  - Removed the filename override in `TacticalUnit.gd`. `faction_id` is now strictly preserved as the commanding player's faction across recruitment, instantiation, and promotion.
- **New Test Suite ([`scenes/test_undead_gameplay.tscn`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scenes/test_undead_gameplay.tscn))**:
  - Fully verified recruiting Skeleton Fodder & Vampire for Blue Kingdom at Castle Black.
  - Verified reachable movement tiles (Skeleton: 24, Vampire: 39) and attack tiles.
  - Verified complete undead upgrade paths: Skeleton Fodder $\rightarrow$ Skeleton Warrior $\rightarrow$ Bone Reaper, and Vampire $\rightarrow$ Vampire Lord while retaining Blue Kingdom ownership.

### 15. 🏡 Village Claiming & Dynamic Troop Capacity Fix (0/10 -> 5/10)
- **Bug Fix (Troop Capacity Dropping to 0/10 upon Claiming a Village)**:
  - Root cause identified: In `EconomyManager._on_resource_node_captured()`, claiming a village previously emitted `EventBus.capacity_changed(new_faction_id, 0, get_max_capacity(new_faction_id))` with a hardcoded `0` for used capacity.
  - When `MainHUD._on_capacity_changed()` received this signal, it formatted the label as `0/10`, completely zeroing out the player's active troop count display until the next turn upkeep.
  - Fixed `EconomyManager.gd` to dynamically fetch active faction units via `TurnManager.get_faction_units(faction_id)` and calculate the true `used_cap` with `get_used_capacity(faction_id, units)` on village capture, recapture, unit spawn, unit death, and unit promotion.
  - Also added capacity updates for the previous owner when a village is captured from another faction.
- **Verification**:
  - [`scenes/test_village_capacity.tscn`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scenes/test_village_capacity.tscn): Verified base capacity (8), capture (+2 $\rightarrow$ 10), and recapture by enemy.
  - [`scenes/test_qa_stress.tscn`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scenes/test_qa_stress.tscn): Step `[QA 02b]` verified that claiming a neutral village preserves the 5 starting units weight and immediately updates the HUD to `5/10`.
  - All 9 integration test suites passed with 100% exit code 0.
