---
type: Guide
title: "Release Guide — Building and Publishing to itch.io"
description: "How a tagged version becomes a build, and how that build becomes an itch.io page."
tags: [release, export, itch, godot4]
---

# Release Guide

How a version number turns into something a stranger can play. Written against
**Godot 4.7.2** and the presets already committed in `export_presets.cfg`.

---

## 0. What the version number means here

Semantic versioning, in its pre-1.0 form. While the major is `0`, the **minor**
carries the weight the major normally would:

| Bump | When |
|---|---|
| `0.x.0` | New features, or anything that changes how the game plays |
| `0.x.y` | Fixes to a version that has already been published |
| `1.0.0` | Reserved. Not before save/load and the campaign exist |

`v0.1.0` was the repository going public — a licence and a README, no build.
`v0.2.0` is the first version anyone can actually play.

A release touches four places, and all four must agree:

1. `project.godot` → `config/version`
2. `README.md` → the Project Status heading
3. `CHANGELOG.md` → a `## 🏷️ Release` section above the dated entries
4. A git tag → `git tag -a v0.2.0`

`export_presets.cfg` carries the version too, but only for the Windows
executable's file properties (`application/file_version`). Update it in the same
pass or the .exe will claim the wrong version in its Properties dialog.

---

## 1. Install the export templates — once per Godot version

Nothing exports without these, and they must match the editor **exactly**:
`4.7.2.stable`. The Arch package ships the editor only, and there is no
`godot-export-templates` package in the repos.

**From the editor** (has a progress bar, recommended):
`Editor → Manage Export Templates… → Download and Install`

**From a terminal** — there is no `--install-export-templates` flag; the CLI
route is to fetch the archive yourself:

```bash
VER=4.7.2
curl -L -o /tmp/templates.tpz \
  "https://github.com/godotengine/godot/releases/download/${VER}-stable/Godot_v${VER}-stable_export_templates.tpz"
mkdir -p ~/.local/share/godot/export_templates
unzip -q /tmp/templates.tpz -d /tmp/godot_tpl
mv /tmp/godot_tpl/templates ~/.local/share/godot/export_templates/${VER}.stable
```

The `.tpz` unpacks to a folder literally named `templates`, and Godot looks for
one named after the version — that rename is the whole trick, and skipping it
leaves the editor still reporting no templates installed.

Roughly 1 GB either way. They land in
`~/.local/share/godot/export_templates/4.7.2.stable/`. Verify:

```bash
ls ~/.local/share/godot/export_templates/4.7.2.stable/ | grep web
# expect: web_nothreads_debug.zip, web_nothreads_release.zip
```

The `nothreads` variant is the one this project needs, because
`variant/thread_support=false` in the Web preset. That choice matters again in
step 5 — it is why itch.io's SharedArrayBuffer switch can stay off.

---

## 2. Take the API key out of the build

**Do this before every public export.** `config/gemini_secret.cfg` holds a live
Google Gemini key. An exported `.pck` is a public archive — anyone who downloads
the game can read every file inside it, and a browser build serves the `.pck`
straight to the visitor.

The presets already exclude it:

```
exclude_filter="config/gemini_secret.cfg,config/*secret*,*.env,…"
```

That is a filter, not a guarantee, so **verify it rather than trusting it**
(step 4). The belt-and-braces version is to not have the file at all:
`GeminiClient._load_api_key()` checks the `GEMINI_API_KEY` environment variable
*before* it looks for the config file, so the key can live in your shell profile
and never sit in the project folder.

**Nothing breaks without it.** `GeminiClient` has no callers anywhere else in
the codebase — it self-subscribes to `EventBus.combat_resolved` and
`building_captured` and writes flavour lines. With no key,
`is_ready_for_requests()` returns `false` and every request falls back to a
canned line ("Yield to our blade!"). The browser build could not reach the API
regardless: a page served from itch.io calling `generativelanguage.googleapis.com`
is blocked by CORS.

---

## 3. Export

```bash
godot --headless --path . --export-release "Web"             build/web/index.html
godot --headless --path . --export-release "Linux"           build/linux/WarPerangTactics.x86_64
godot --headless --path . --export-release "Windows Desktop" build/windows/WarPerangTactics.exe
```

The target directory must already exist — Godot will not create it and fails
with a bare path error if it is missing.

`build/` is gitignored. Builds are artefacts of a tag, not repository contents.

### What the presets already handle

- **Excluded**: the Gemini secret, `scripts/test/`, `scenes/test_*.tscn`,
  `scripts_dev/`, `docs/`, and every `.md`. Roughly 6 000 lines of test harness
  and prose that a player has no use for.
- **Kept**: `addons/godot_ai/`. It looks like dead weight, and it nearly is —
  but `project.godot` registers `_mcp_game_helper` as an autoload pointing into
  it, so excluding the folder makes the exported game fail on startup with a
  missing autoload. `game_helper.gd` detects the absent debugger channel and
  sits idle in a release build, which is why keeping it is safe. To strip it,
  remove the autoload **first**, then add `addons/godot_ai/*` to the filter.

---

## 4. Verify the build before it leaves the machine

**The key.** This is the check that matters, because a filter that silently
misses is indistinguishable from one that worked:

```bash
grep -ac "AQ.Ab8RN6" build/web/index.pck build/linux/WarPerangTactics.x86_64
```

Every file must report `0`. A non-zero count means the key shipped — rotate it
at [aistudio.google.com](https://aistudio.google.com/apikey) and do not upload.

**The game.** A headless export proves the build exists, not that it runs:

```bash
python3 -m http.server 8000 --directory build/web
# then open http://localhost:8000
```

Opening `index.html` as a `file://` URL will **not** work — the browser blocks
the WebAssembly fetch. It must be served over HTTP, which is also how itch.io
serves it.

Play one full match: menu → faction select → move a unit → capture a building →
end turn and let the AI move → walk into the Black Castle's monsters. Audio in a
browser only starts after a click, so the menu button doubling as the gesture is
expected, not a bug.

---

## 5. Publish to itch.io

### 5.1 Zip the web build

```bash
cd build/web && zip -r ../war-perang-tactics-web-v0.2.0.zip . && cd -
```

**`index.html` must sit at the root of the zip, not inside a folder.** This is
the single most common reason an itch.io upload shows a blank page. Zipping the
directory itself (`zip -r out.zip build/web`) produces the broken layout; the
`cd` above is what avoids it.

### 5.2 Create the page

`itch.io → Dashboard → Create new project`

| Field | Value |
|---|---|
| **Title** | War Perang Tactics |
| **Classification** | Games |
| **Kind of project** | **HTML** — this is what enables the browser player |
| **Release status** | Prototype / In development |
| **Pricing** | No payments (or Donate) |

Getting **Kind of project** wrong is worth care: pick "Downloadable" and the
browser-play checkbox in the next step never appears.

### 5.3 Upload and mark it playable

Upload the zip, then tick **"This file will be played in the browser"** on that
file's row. Upload the Linux and Windows builds as additional files if you want
them, each tagged with its platform.

### 5.4 Embed options

| Setting | Value | Why |
|---|---|---|
| Viewport dimensions | **1408 × 792** | Matches `viewport_width` / `viewport_height` in `project.godot` exactly. Any other number letterboxes or crops. |
| Fullscreen button | **on** | A 30×20 grid is cramped in an embedded frame |
| Mobile friendly | **off** | Every interaction is mouse-driven; there is no touch input path |
| Automatically start on page load | off | Let the visitor click — that click is also the browser's audio-permission gesture |
| **SharedArrayBuffer support** | **off** | Only needed when the Web preset has `variant/thread_support=true`. This project exports the `nothreads` variant, so leaving it off is correct. Turn it on **only** if you later enable thread support — it adds cross-origin isolation headers that break embedded third-party content. |

### 5.5 The rest of the page

Screenshots do most of the selling. Good candidates from this build: the main
menu over the battlefield backdrop, a movement range overlay mid-turn, and the
Black Castle with its garrison visible.

Copy for the description can come straight out of `README.md` — the "What the
game actually is" section was written for exactly this. Say plainly that it is
an experimental build with **no save system**, so a match is one sitting.
Suggested tags: `turn-based`, `tactical`, `strategy`, `pixel-art`, `godot`.

Then **Save & view page** and play it once on the live URL before setting
visibility to Public. The embedded frame is a different environment from
`localhost` and is where a wrong viewport size or a missing file shows up.

---

## 6. Tag the release

Only after the live page works:

```bash
git tag -a v0.2.0 -m "v0.2.0 — first playable build"
git push origin main --tags
```

The tag goes on the commit the build came from. Tagging first and fixing the
build afterwards leaves a tag that does not correspond to anything anyone played.
