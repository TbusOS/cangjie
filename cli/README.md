# CLI · `whetstone`

A runtime-agnostic command-line entry point so Whetstone is usable outside an
agent runtime (CI, scripting, muscle memory). Pure bash, zero deps, paths
resolved relative to the repo — clone anywhere and run.

```bash
./cli/whetstone help
# or put it on PATH:
ln -s "$PWD/cli/whetstone" ~/.local/bin/whetstone
```

## Commands

| Command | Wraps | What it does |
|---|---|---|
| `whetstone pack [--src D] [--out F] [--only a,b]` | `bin/pack.sh` | package a skill library → tarball + MANIFEST |
| `whetstone deploy <pack.tar.gz> [--dest D] [--force]` | `bin/deploy.sh` | install a pack into a skills dir (collision-safe) |
| `whetstone promote <proposal> [--list] [--dry-run] [--force]` | `bin/promote.sh` | apply an approved `inbox/` proposal to the live library |
| `whetstone sync engram <skill> [--dry-run]` | `adapters/sync/engram.sh` | push a skill into engram (optional sink) |
| `whetstone lint [--src D] [--strict] [--json]` | `bin/lint.py` | flag empty / overlapping / colliding skill descriptions |
| `whetstone index [--src D] [--out F]` | `bin/index.py` | generate a grouped `INDEX.md` catalog |
| `whetstone capture [--clean]` | `adapters/capture/claude-code.sh` | the Claude Code session journaler |
| `whetstone selftest` | `adapters/capture/selftest.sh` | run the capture-hook selftest |
| `whetstone journal` | — | list captured sessions |
| `whetstone version` / `help` | — | — |

## Why `distill` is NOT a CLI command

Mining the transcript + git diff and layering into L1–L4 is **agent work** — it
needs a model in the loop. The CLI refuses to fake it: `whetstone distill` prints
a pointer to invoke the `/distill` skill (or run `SKILL.md` Phase 0–5) instead.
The CLI owns the deterministic steps *around* distillation: `promote` / `pack` /
`deploy` / `sync`.

This keeps the boundary honest — runtime-neutral scripting for the mechanical
parts, agent runtime for the judgement parts.

## Index hygiene (`lint` / `index`)

The skill **selection menu** = every skill's `name` + `description`, always in the
agent's context. As the library grows, vague or overlapping descriptions make the
model pick the wrong skill or miss the right one. `lint` checks that menu against the
description contract (extraction-framework §13): missing triggers, overlapping trigger
sets, name near-collisions (e.g. `foo-review` vs `foo-review-framework`). `index`
emits a grouped `INDEX.md` for humans. Run `lint` after adding or editing any skill.

