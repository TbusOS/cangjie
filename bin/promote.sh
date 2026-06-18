#!/usr/bin/env bash
# whetstone promote — apply an approved inbox/ proposal to the live skill library.
#
#   bin/promote.sh <proposal> [--inbox <dir>] [--dest <skills-dir>]
#                             [--force] [--dry-run] [--list] [--clean]
#
# Scope (deliberately the mechanically-safe subset):
#   * Installs BRAND-NEW skills from a proposal.
#   * On an EXISTING skill it REFUSES to overwrite — merging L2 lessons / superseding
#     facts is a semantic op (append + mark, never silent clobber). Run the agent
#     `/promote` for that, or pass --force to replace the skill wholesale.
# Human judgement (is the L1-L4 split right?) already happened in /distill Phase 5;
# this just moves bytes, collision-safe, with provenance.
#
# A proposal under <inbox>/<proposal>/ is resolved as:
#   1. has SKILL.md            -> one skill named <proposal>
#   2. has skills/             -> each subdir with a SKILL.md
#   3. otherwise               -> each immediate subdir with a SKILL.md
# No /tmp. cp straight from inbox to dest; provenance appended to journal/promoted.jsonl.

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export PYTHONNOUSERSITE=1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

INBOX="$REPO_DIR/inbox"
DEST="${WHETSTONE_SKILLS_DIR:-$HOME/.claude/skills}"
PROPOSAL=""; FORCE=0; DRY=0; LIST=0
PROV="$REPO_DIR/journal/promoted.jsonl"

while [ $# -gt 0 ]; do
  case "$1" in
    --inbox)   INBOX="$2"; shift 2;;
    --dest)    DEST="$2"; shift 2;;
    --force)   FORCE=1; shift;;
    --dry-run) DRY=1; shift;;
    --list)    LIST=1; shift;;
    --clean)   echo "whetstone promote: nothing to clean (no staging dir)"; exit 0;;
    -*)        echo "unknown arg: $1" >&2; exit 2;;
    *)         PROPOSAL="$1"; shift;;
  esac
done

[ -d "$INBOX" ] || { echo "inbox not found: $INBOX" >&2; exit 1; }

if [ "$LIST" -eq 1 ]; then
  echo "proposals in $INBOX:"
  found=0
  for d in "$INBOX"/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    n="$(find "$d" -name SKILL.md | wc -l | tr -d ' ')"
    [ "$n" -gt 0 ] && { printf '  %-28s (%s skill[s])\n' "$name" "$n"; found=$((found+1)); }
  done
  [ "$found" -eq 0 ] && echo "  (none)"
  exit 0
fi

[ -n "$PROPOSAL" ] || { echo "usage: promote.sh <proposal> [--list] [--dry-run] [--force]" >&2; exit 2; }
PDIR="$INBOX/$PROPOSAL"
[ -d "$PDIR" ] || { echo "proposal not found: $PDIR  (try --list)" >&2; exit 1; }

# Resolve which skill dirs this proposal carries.
SKILLS=()
if [ -f "$PDIR/SKILL.md" ]; then
  SKILLS=("$PDIR")
elif [ -d "$PDIR/skills" ]; then
  for d in "$PDIR/skills"/*/; do [ -f "${d}SKILL.md" ] && SKILLS+=("${d%/}"); done
else
  for d in "$PDIR"/*/; do [ -f "${d}SKILL.md" ] && SKILLS+=("${d%/}"); done
fi
[ "${#SKILLS[@]}" -gt 0 ] || { echo "no SKILL.md found under $PDIR" >&2; exit 1; }

mkdir -p "$DEST"
installed=0; replaced=0; deferred=0
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
for s in "${SKILLS[@]}"; do
  # name = single-skill proposal uses <proposal>, else the dir's own basename
  if [ "$s" = "$PDIR" ]; then name="$PROPOSAL"; else name="$(basename "$s")"; fi
  target="$DEST/$name"
  if [ -e "$target" ] && [ "$FORCE" -ne 1 ]; then
    echo "DEFER  $name — exists; L2 merge / fact supersede is semantic. Use /promote (agent) or --force to replace."
    deferred=$((deferred+1)); continue
  fi
  action="installed"; [ -e "$target" ] && action="replaced"
  if [ "$DRY" -eq 1 ]; then
    echo "DRY    would $action: $name -> $target"
  else
    rm -rf "$target"; cp -r "$s" "$target"
    printf '{"ts":"%s","proposal":"%s","skill":"%s","action":"%s","dest":"%s"}\n' \
      "$TS" "$PROPOSAL" "$name" "$action" "$DEST" >> "$PROV"
    echo "$action: $name -> $target"
  fi
  [ "$action" = "replaced" ] && replaced=$((replaced+1)) || installed=$((installed+1))
done

sfx=""; [ "$DRY" -eq 1 ] && sfx=" (dry-run)"
echo "whetstone promote: $installed new, $replaced replaced, $deferred deferred$sfx"
[ "$DRY" -eq 1 ] && echo "(dry-run: no files written, no provenance recorded)"
exit 0
