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

## 1.5 The open editor owns `export_presets.cfg`

**Editing this file by hand while the Godot editor is running loses the edit.**
The editor holds the presets in memory and writes its own copy back to disk the
moment the Export dialog is touched — silently, with no conflict and no warning.

Hit on 2026-08-29: three presets written to disk came back as one, with
`exclude_filter=""`. The Gemini-key exclusion in step 2 was the casualty, which
is the worst possible thing to lose this way, because the export still succeeds
and looks fine.

Two safe routes, pick one:

- **Edit in the editor**, not on disk — `Export → Resources → Filters to exclude
  files/folders from project`. What you type there survives, because the editor
  is the one writing it.
- **Close the editor first**, then edit the file, then export from the CLI. The
  headless exporter reads `export_presets.cfg` fresh and never writes to it, so
  nothing can be clobbered mid-release.

Same mechanism as the editor resurrecting a moved `.tscn`: a running editor
treats its own memory as the truth and the disk as an output.

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
B=../builds
mkdir -p $B/web $B/linux $B/windows
godot --headless --path . --export-release "Web"             $B/web/index.html
godot --headless --path . --export-release "Linux"           $B/linux/WarPerangTactics.x86_64
godot --headless --path . --export-release "Windows Desktop" $B/windows/WarPerangTactics.exe
```

The target directory must already exist — Godot will not create it.

**Export outside the project folder, not into `build/`.** Godot scans `res://`
on every run, so an output directory inside it gets re-imported as project
assets: exporting once into `build/web/` produced `index.png.import`,
`index.icon.png.import` and `index.apple-touch-icon.png.import` sitting next to
the build, and left the exported icons queued to ship inside the *next* export's
`.pck`. A filter can paper over that; a path outside `res://` removes the
possibility.

### What actually has to be excluded, and why the list is not obvious

**`.json` is a Godot resource type.** That single fact is what makes the filter
load-bearing beyond the API key. `graphify-out/` holds nine knowledge-graph
snapshots totalling ~5 MB of JSON, and under *Export all resources in the
project* every one of them shipped — **half the `.pck`**. Measured
2026-08-29: excluding `graphify-out/*` took the web pack from **10.66 MB to
5.54 MB** and the string `graphify` from 368 occurrences to 0.

`.cfg` is **not** a resource type, which is why the Gemini secret might have
stayed out on its own — but "might" is not a security position, and the file is
named in the filter for that reason.

Dot-directories at the project root (`.claude/`, `.vscode/`, `.git/`) are
skipped by the exporter and need no filter; this was checked against the built
pack rather than assumed.

### What the presets already handle

- **Excluded**: the Gemini secret, `scripts/test/`, `scenes/test_*.tscn`,
  `scripts_dev/`, `docs/`, and every `.md`. Roughly 6 000 lines of test harness
  and prose that a player has no use for.
- **Kept**: `addons/godot_ai/`, whose compiled `.gdc` files ship. The autoload
  it registers does **not** — the addon removes itself, logging
  `MCP | export: stripping autoload/_mcp_game_helper from the exported pack`
  on every export, including headless CLI ones. So the missing-autoload crash
  that would normally forbid excluding the folder cannot happen here. It is
  kept because it costs little in a 5.5 MB pack, not because it must be.

---

## 4. Verify the build before it leaves the machine

**The key.** This is the check that matters, because a filter that silently
misses is indistinguishable from one that worked:

```bash
grep -ac "AQ.Ab8RN6" ../builds/web/index.pck ../builds/linux/WarPerangTactics.x86_64
strings -a ../builds/web/index.pck | grep -c "gemini_secret"
strings -a ../builds/web/index.pck | grep -ci graphify    # 0 = the graph stayed out
```

Every count must report `0`. A non-zero count means the key shipped — rotate it
at [aistudio.google.com](https://aistudio.google.com/apikey) and do not upload.

**The game.** A headless export proves the build exists, not that it runs:

```bash
python3 -m http.server 8000 --directory ../builds/web
# then open http://localhost:8000
```

The desktop build answers a cheaper question first — does it boot at all:

```bash
timeout 25 ../builds/linux/WarPerangTactics.x86_64 --headless
```

Exit **124** is the pass: the timer killed a process that was still running.
Any other exit code, or any `SCRIPT ERROR` on stdout, is a real failure.

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
cd ../builds/web && zip -r ../war-perang-tactics-web-v0.2.0.zip . && cd -
```

`zip` is not installed on this machine. Python's `zipfile` does the same job and
makes the root-level layout explicit rather than incidental:

```bash
python3 -c "
import zipfile, sys; from pathlib import Path
web = Path('../builds/web'); out = Path('../builds/war-perang-tactics-web-v0.2.0.zip')
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for f in sorted(web.rglob('*')):
        if f.is_file(): z.write(f, f.relative_to(web))
print(out, out.stat().st_size // 1000, 'kB')
"
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
