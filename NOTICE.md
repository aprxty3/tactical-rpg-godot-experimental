# Notice — Licensing Scope and Third-Party Components

The [MIT License](LICENSE) in this repository covers **this project's own source code
and documentation** — the contents of `scripts/`, `scripts_dev/`, `tests/`, `docs/`, the
scene and resource definitions under `scenes/` and `resources/`, and the Markdown files
at the repository root.

It does **not** cover the third-party components bundled here. Those remain under their
original terms and their original copyright holders.

---

## Bundled editor addons — `addons/`

Each ships its own `LICENSE` file, which governs it:

| Path | License | Copyright |
|---|---|---|
| `addons/script-ide/` | MIT | © 2023 Marius Hanl |
| `addons/godot_ai/` | MIT | © 2025 Godot AI contributors |
| `addons/GDQuest_GDScript_formatter/` | MIT | © 2025–present GDQuest |

These are MIT-licensed, but by **their own authors**. Their copyright notices must be
retained. Nothing in this repository relicenses them.

---

## Art and audio assets — `assets/`

**Not covered by the MIT license.**

The artwork derives from third-party pixel-art packs (*Tiny Swords*, *Pixel RPG Pack*)
and is redistributed here under those packs' own terms.

The generated spritesheets under `assets/characters/generated/` are programmatic
derivatives of that source art — palette rotation, rim lighting, role markers. They
inherit the terms of the art they derive from: **the derivation scripts are MIT, the
pixels they operate on are not.**

If you reuse this repository, verify the current terms of those asset packs with their
original authors before shipping anything. Do not assume the MIT grant extends to any
file under `assets/`.

---

## Godot Engine

The engine itself is not bundled here. Godot Engine is MIT licensed,
© 2014–present Godot Engine contributors.
