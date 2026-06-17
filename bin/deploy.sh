#!/usr/bin/env bash
# cangjie deploy — install a skill-library pack into a target skills dir. Collision-safe.
#
#   bin/deploy.sh <pack.tar.gz> [--dest <skills-dir>] [--force] [--clean]
#
# Default dest is the Claude Code skills dir; override with --dest (or env
# CANGJIE_SKILLS_DIR) for other runtimes. Existing skills are SKIPPED unless
# --force (never silently clobbers). No /tmp: staging under the repo.

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export PYTHONNOUSERSITE=1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
STAGE="$REPO_DIR/.deploy-stage"

PACK=""; DEST="${CANGJIE_SKILLS_DIR:-$HOME/.claude/skills}"; FORCE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dest)  DEST="$2"; shift 2;;
    --force) FORCE=1; shift;;
    --clean) rm -rf "$STAGE"; echo "cangjie deploy: cleaned"; exit 0;;
    -*) echo "unknown arg: $1" >&2; exit 2;;
    *)  PACK="$1"; shift;;
  esac
done

[ -f "$PACK" ] || { echo "pack not found: $PACK" >&2; exit 1; }
mkdir -p "$DEST"
rm -rf "$STAGE"; mkdir -p "$STAGE"
tar xzf "$PACK" -C "$STAGE"
[ -d "$STAGE/skills" ] || { echo "bad pack (no skills/)" >&2; rm -rf "$STAGE"; exit 1; }

installed=0; skipped=0
for d in "$STAGE/skills"/*/; do
  name="$(basename "$d")"
  if [ -e "$DEST/$name" ] && [ "$FORCE" -ne 1 ]; then
    echo "SKIP (exists, use --force): $name"; skipped=$((skipped+1)); continue
  fi
  rm -rf "$DEST/$name"; cp -r "$d" "$DEST/$name"
  echo "installed: $name"; installed=$((installed+1))
done
rm -rf "$STAGE"
echo "cangjie deploy: $installed installed, $skipped skipped → $DEST"
