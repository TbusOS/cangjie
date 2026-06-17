#!/usr/bin/env bash
# whetstone pack — package a local skill library into a portable tarball + manifest.
#
# Runtime-neutral: --src is any skills dir; default is the Claude Code skills dir,
# override with --src (or env WHETSTONE_SKILLS_DIR) for other runtimes.
# Excludes per-skill runtime products (journal/ inbox/ shots/ .git/ *.bak).
#
#   bin/pack.sh [--src <skills-dir>] [--out <pack.tar.gz>] [--only name1,name2] [--clean]
#
# No /tmp: staging lives under the repo (.pack-stage), cleaned each run.

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export PYTHONNOUSERSITE=1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
STAGE="$REPO_DIR/.pack-stage"

SRC="${WHETSTONE_SKILLS_DIR:-$HOME/.claude/skills}"
OUT=""; ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --src)   SRC="$2"; shift 2;;
    --out)   OUT="$2"; shift 2;;
    --only)  ONLY="$2"; shift 2;;
    --clean) rm -rf "$STAGE" "$REPO_DIR"/whetstone-skills-*.tar.gz; echo "whetstone pack: cleaned"; exit 0;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done

[ -d "$SRC" ] || { echo "src not found: $SRC" >&2; exit 1; }
TS="$(date -u +%Y%m%d-%H%M%S)"
[ -n "$OUT" ] || OUT="$REPO_DIR/whetstone-skills-$TS.tar.gz"
# tar runs inside $STAGE, so a relative --out would resolve there and be lost — make it absolute.
case "$OUT" in /*) : ;; *) OUT="$(cd "$(dirname "$OUT")" 2>/dev/null && pwd)/$(basename "$OUT")";; esac

rm -rf "$STAGE"; mkdir -p "$STAGE/skills"
MANIFEST="$STAGE/MANIFEST.txt"
{ echo "# whetstone skill-library pack"
  echo "# packed: $(date -u +%Y-%m-%dT%H:%M:%SZ)   src: $SRC"
  echo ""; } > "$MANIFEST"

if [ -n "$ONLY" ]; then
  IFS=',' read -ra NAMES <<< "$ONLY"
else
  NAMES=()
  for d in "$SRC"/*/; do [ -f "${d}SKILL.md" ] && NAMES+=("$(basename "$d")"); done
fi

count=0
for name in "${NAMES[@]}"; do
  s="$SRC/$name"
  [ -f "$s/SKILL.md" ] || { echo "skip (no SKILL.md): $name" >&2; continue; }
  mkdir -p "$STAGE/skills/$name"
  ( cd "$s" && tar cf - --exclude='./journal' --exclude='./inbox' --exclude='./shots' \
       --exclude='./.git' --exclude='*.bak' . ) | ( cd "$STAGE/skills/$name" && tar xf - )
  files="$(find "$STAGE/skills/$name" -type f | wc -l | tr -d ' ')"
  printf '%-32s files=%s\n' "$name" "$files" >> "$MANIFEST"
  count=$((count+1))
done

( cd "$STAGE" && tar czf "$OUT" MANIFEST.txt skills )
rm -rf "$STAGE"
echo "whetstone pack: $count skill(s) → $OUT"
