# LIFESTATE

A life-simulation game: **BitLife**-style life progression (age, needs, life events,
family) layered with **Melvor Idle**-style activity progression (Study, Work, Play,
Family Time as idle activities with per-hour rewards).

## Current implementation

| Project | Language | Status |
| --- | --- | --- |
| `Lifestate.Godot/` | Godot 4 · GDScript | **Primary implementation.** Playable game. |
| `*.cs` (repo root) | C# · .NET 10 · WinForms | **Retained as the golden reference.** Not the target build. |

The C# WinForms application is kept deliberately: it is the behavioural
specification the GDScript port was written against, it still builds, and its
287-assertion regression suite still runs. It is a migration oracle, not dead code.
Do not delete it, and do not port gameplay *out* of it — the two implementations
must stay semantically identical until the C# front-end is retired on purpose.

## Architecture

```
Lifestate.Godot/scripts/core/     engine-independent simulation (no Godot node deps)
        ↑
Lifestate.Godot/scripts/GameService.gd    autoload session: owns clock + player
        ↑
Lifestate.Godot/scripts/ui/       presentation: shell, theme, screens
```

**Rule:** the simulation is authoritative and the UI adapts to it. Core classes
(`GameClock`, `PlayerState`, `LifeEventSystem`, `SaveManager`, …) are `RefCounted`
objects with no scene-tree coupling; `GameService` is the single owner of one
authoritative `GameClock` + `PlayerState`. Screens never create their own state —
they read the session and render it.

### Simulation semantics (preserved from the C# reference)

- **Clock:** 1 real second = 4 game minutes · 15 real seconds = 1 game hour ·
  6 real minutes = 1 game day. Frame-rate independent; delta is accumulated and
  applied as whole seconds so low framerates cannot slow the simulation.
- **Needs:** Energy −1/hour awake, +5/hour sleeping; Hunger −1/hour; Thirst −2/hour.
- **Activities:** Sleep, Work, Study, Play, Family Time. Mutually exclusive, with
  per-activity minute accumulators carried across sub-hour boundaries.
- **Progression:** Study grants StudyXP, Academics XP and Intelligence; Play and
  Family Time grant Attributes/Traits; Skills are XP-based with derived levels;
  formal education spans Primary Grades 1–6 and Secondary Grades 7–12.
- **Life events:** `LifeEventCatalog` holds immutable definitions; one pending
  event at a time; choices resolve deterministically into ordered history.
- **Offline progression** uses O(1) bulk arithmetic, never a per-minute loop.

## Running it

### Godot 4 (the game)

The installed engine on the development machine is the standard (non-.NET) build:

```
D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe
4.7.2.stable.steam.ed1daf0bf
```

Open `Lifestate.Godot/project.godot` in the editor, or launch it directly:

```bash
godot --path Lifestate.Godot
```

The project boots straight into `scenes/Main.tscn`. Navigation is
**LIFE / ACTIVITIES / PEOPLE / MORE**, with Character, Education, Save/Load and
Settings under MORE. `F2` toggles the developer overlay.

### GDScript regression suite (618 assertions)

```bash
godot --headless --path Lifestate.Godot --script res://tests/run_tests.gd
```

Exits non-zero on any failure. Coverage: clock, age, life stages, needs, every
activity, attributes, traits, skills, education, family, relationships, life
events and history, total play hours, save/load, offline progression, God Mode.

### Godot UI structure checks (453 assertions)

```bash
godot --headless --path Lifestate.Godot --script res://tests/run_ui_checks.gd
```

Instantiates the real `Main.tscn` and verifies the scene tree, navigation wiring,
that displayed values come from the live `PlayerState`, that navigation mutates
nothing, the F2 overlay's enable/visibility coupling, and the colour palette.

### Godot runtime smoke test (44 assertions)

```bash
godot --headless --path Lifestate.Godot --script res://tests/run_smoke.gd
```

Boots the real shell through the session autoload and checks it end to end:
autoload session, initial values, the frame-rate-independent tick accumulator
(split deltas, sub-second fragments, a 500-second stall losing no time), the live
loop over three seconds of real time, pause/resume, and that the scene displays
the session's actual numbers.

### C# → Godot save compatibility (23 assertions)

```bash
# 1. regenerate only when the retained C# Version 7 reference changes
dotnet run -- --save-fixture Lifestate.Godot/tests/fixtures/csharp_save_v7.json \
                            Lifestate.Godot/tests/fixtures/csharp_summary.json

# 2. prove Godot still imports the Version 7 C# save
godot --headless --path Lifestate.Godot --script res://tests/run_save_interchange.gd

# 3. keep the retained Version 7 C# golden fixture regression green
bin/Debug/net10.0-windows/Lifestate.exe --verify-fixture \
    Lifestate.Godot/tests/fixtures/godot_save_v7.json \
    Lifestate.Godot/tests/fixtures/godot_summary.json
```

The port loads the C#-written Version 7 save, preserves every legacy field while
upgrading it to Version 8 with `SecondaryGrade = 0`, matches a canonical summary,
reproduces C# offline progression, and rejects Version 1 transactionally. The
retained Version 7 Godot fixture keeps the old C# reader regression-covered;
Version 8 Godot saves are not compatible with the old C# build. Fixtures live in
`Lifestate.Godot/tests/fixtures/`.

The C# executable exposes the test-only flags `--save-fixture`, `--load-fixture`,
`--verify-fixture` and `--reject-fixture` for this (see
`SaveInterchangeHarness.cs`). None of them are reachable from the interactive
game; they are the same kind of entry point as `--test`.

### C# reference build and tests

```bash
dotnet build
dotnet run -- --test          # 287 assertions, also via bin/…/Lifestate.exe --test
```

## Save compatibility

The JSON schema is intentionally PascalCase and `Version` is **7** in both
implementations, so the two can read each other's files. Version 2–6 saves are
migrated on load by both.

| Build | Save location |
| --- | --- |
| Godot | `user://save.json` → `%APPDATA%\Godot\app_userdata\LIFESTATE\save.json` |
| C# / WinForms | `%LOCALAPPDATA%\LIFESTATE\save.json` |

Loading is **transactional**: the JSON is parsed, validated and offline-advanced
on temporary objects, and the live clock/player are only replaced once the whole
pipeline succeeds. A rejected save leaves the running game untouched.

**Reusing an existing C# save** — either copy
`%LOCALAPPDATA%\LIFESTATE\save.json` over
`%APPDATA%\Godot\app_userdata\LIFESTATE\save.json`, or call
`SaveManager.import_windows_save()`, which performs that copy. Offline time is
applied from the save's UTC timestamp; a timestamp in the future yields zero
offline progress.

## Android readiness

The Godot front-end is structured to be portable, not yet exported:

- saves use `user://`, which resolves per platform — no drive letters or
  `%LOCALAPPDATA%` in the normal path (the Windows import helper is the only
  place that reads an environment variable, and it is opt-in);
- core has no Windows-only dependency — no WinForms, no `System.Drawing`; the
  only .NET dependency is `Environment.GetFolderPath` in the C# reference build;
- UI is built from `Control` containers with anchors and size flags, and every
  action is a real `Button`, so touch works without hover; F2 is dev-only;
- `OS.get_environment` is guarded, so a missing variable fails cleanly.

Android export templates and the Android SDK are **not** installed on this
machine, so no export has been attempted.

## Repository layout

```
*.cs                  C# reference implementation (WinForms front-end + core)
Lifestate.csproj      C# reference project (.NET 10, net10.0-windows)
SimulationTests.cs    C# regression suite (287 assertions)
SaveInterchangeHarness.cs  test-only C#<->GDScript save fixture bridge
Lifestate.Godot/      Godot 4 GDScript implementation
  project.godot       project config: autoload, theme, main scene, window
  scenes/Main.tscn    shell: top bar, screen host, feedback line, bottom nav
  scripts/core/       simulation (engine-independent)
  scripts/GameService.gd   autoload session owner
  scripts/ui/         theme, shell controller, screens/
  scripts/ui/screens/ Life, Activities, People, More + four secondary screens
  themes/Lifestate.tres    generated theme resource
  tools/generate_theme.gd  regenerates themes/Lifestate.tres
  tests/              GDScript suites: core regressions, UI structure,
                      runtime smoke, save interchange + headless runners
  tests/fixtures/     cross-implementation save fixtures
```

The `.godot/` editor cache is generated on open and is git-ignored. Scene,
script, theme and `.uid` files are source and **are** committed.
