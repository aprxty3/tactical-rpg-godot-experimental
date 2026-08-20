# Factions & Units Guide

This document defines the warring factions, unit archetypes, stat blueprints, and combat advantage systems in **War Perang Tactics**.

---

## 1. The Five Warring Factions

1. **Blue Kingdom**:
   - *Theme*: Standard chivalric kingdom, disciplined formations, and balanced defense.
   - *Signature Units*: **Knight**, **Warrior**, **Pawn**.
2. **Red Legion**:
   - *Theme*: Aggressive offensive juggernaut focusing on brute physical damage and siege tactics.
   - *Signature Units*: **Warrior**, **Archer**, **TNT Specialist**.
3. **Purple Syndicate**:
   - *Theme*: Cunning shadow guild relying on high mobility, poisons, and ambush strikes.
   - *Signature Units*: **Rogue**, **Vampire**.
4. **Yellow Empire**:
   - *Theme*: Wealthy empire harnessing golden economy and ancient elemental sorcery.
   - *Signature Units*: **Wizzard**, **Priest**, **Castle Defender**.
5. **Black Coven / Necropolis (Undead Faction)**:
   - *Theme*: Dark death cult summoning legions of skeletal minions and cursed vitality.
   - *Signature Units*: **Skeleton Army (Base, Warrior, Rogue, Mage)**, **Skull**, **Vampire**.

---

## 2. Unit Archetypes & Roles

| Unit Class | Primary Role | Move Range | Attack Range | Special Traits & Capabilities |
| :--- | :--- | :---: | :---: | :--- |
| **Pawn** | Worker & Builder | 3 Tiles | 1 Tile (Melee) | Lowest cost. Captures and repairs structures twice as fast. |
| **Warrior** | Frontline Infantry | 3 Tiles | 1 Tile (Melee) | Reliable frontline brawler with balanced HP and physical defense. |
| **Knight** | Heavy Armored Cavalry | 4 Tiles | 1 Tile (Melee) | Immense physical armor. Gains a *Charge Bonus* when moving in a straight line before attacking. |
| **Archer** | Ranged Marksman | 3 Tiles | 2-3 Tiles | Long-range physical attacks without triggering melee counter-attacks. |
| **Rogue** | Skirmisher / Infiltrator | 4 Tiles | 1 Tile (Melee) | Ignores enemy zones of control; inflicts critical *Backstab* damage from behind. |
| **Wizzard** | Area Elemental Mage | 2 Tiles | 2 Tiles (AoE) | Deals area-of-effect magical damage that pierces heavy physical armor. |
| **Priest** | Support & Holy Healer | 3 Tiles | 1-2 Tiles | Restores ally HP, cleanses status ailments, and deals $+150\%$ holy damage vs Undead. |
| **Vampire** | Hybrid Bruiser | 4 Tiles | 1 Tile (Melee) | Recovers health proportional to damage dealt (*Lifesteal*). |
| **Skeleton Army** | Undead Swarm | 3 Tiles | 1-2 Tiles | Inexpensive fodder unit that can be reanimated on death by necromantic spells. |

---

## 3. Combat Advantage System (Tactical Triangle)

Combat damage resolution incorporates class matchups and elemental strengths:

```
                  ┌───────────────┐
                  │    Warrior    │
                  │   & Knight    │ (Heavy Melee)
                  └───────┬───────┘
                          │
             Crushes      │    Vulnerable to
             (Smash)      │    (Armor Piercing Magic)
                          ▼
┌────────────────┐                 ┌────────────────┐
│     Archer     │◄────────────────┤    Wizzard     │
│    & Rogue     │    Outranges    │    & Magic     │
└────────────────┘ (Speed / Range) └────────────────┘
```

- **Heavy Melee (Knight, Warrior)** $\rightarrow$ Overpowers **Rogue & Archer** in close-quarters combat.
- **Ranged & Agility (Archer, Rogue)** $\rightarrow$ Eliminates slow **Wizzard** units before casting completes.
- **Magic (Wizzard)** $\rightarrow$ Melts heavy plate armor of **Knight & Warrior**.
- **Holy vs Undead**: **Priest** attacks deal $+150\%$ damage against **Skeleton** and **Vampire** units.

---

## 4. Unit Stat Blueprint (Godot Resource)
Each unit is instantiated using a `UnitData.gd` custom resource:
- `max_health`: Hit Points (HP)
- `attack_power`: Base Physical/Magical Attack
- `defense_power`: Damage Reduction
- `movement_points`: Base Move Distance per turn
- `attack_range_min` & `attack_range_max`: Reach distance
- `recruit_cost`: Gold cost to deploy
- `faction`: Faction alignment identifier

---

## 5. Related Documentation Links
- **Core Loop & Phases**: See [[GDD_Overview]] for turn progression and game rules.
- **Production & Capture**: See [[Terrain_and_Buildings]] for recruitment at Castles and healing in Houses.
- **Godot Implementation**: See [[Architecture]] for node hierarchy and `CombatResolver.gd`.
