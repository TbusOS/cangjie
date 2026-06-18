#!/usr/bin/env python3
"""whetstone index — generate a human-readable INDEX.md catalog of a skill library.

Groups skills into families (so a growing library stays navigable) and prints one
line per skill: its capability summary (the description up to the trigger list).
Family edges come from three signals: shared trigger tokens, name near-collision,
and cross-references (one description naming another skill).

Runtime-neutral. stdlib only. Reuses the parser/heuristics from lint.py.

  bin/index.py [--src DIR] [--out FILE]      # default: print to stdout
"""
import os
import sys
import re
import argparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lint  # noqa: E402  (sibling module: parse_frontmatter / trigger_tokens / jaccard / name_collision / load_skills / FAMILY_T)

# segments too generic to name a family after (keep meaningful ones like "design")
GENERIC_SEG = {"workflow", "tool", "dev", "to", "md", "pdf", "markdown", "the", "for", "of"}
SUMMARY_CUT = re.compile(r"触发词|TRIGGER|DO NOT|。|\. ", re.I)
SUMMARY_MAX = 110


def summary(desc):
    """First clause of a description: the capability line before triggers/boundaries,
    capped so the catalog stays scannable."""
    m = SUMMARY_CUT.search(desc)
    s = desc[:m.start()] if m else desc
    s = s.strip().rstrip("—-·,， ")
    if not s:
        s = desc[:SUMMARY_MAX]
    if len(s) > SUMMARY_MAX:
        s = s[:SUMMARY_MAX].rstrip() + "…"
    return s


def build_families(skills):
    names = [s["name"] for s in skills]
    by_name = {s["name"]: s for s in skills}
    trig = {n: lint.trigger_tokens(by_name[n]["desc"]) for n in names}

    # union-find over family edges
    parent = {n: n for n in names}

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(a, b):
        parent[find(a)] = find(b)

    for i in range(len(names)):
        for j in range(i + 1, len(names)):
            a, b = names[i], names[j]
            edge = (lint.jaccard(trig[a], trig[b]) >= lint.FAMILY_T
                    or lint.name_collision(a, b)
                    or re.search(r"\b" + re.escape(b) + r"\b", by_name[a]["desc"])
                    or re.search(r"\b" + re.escape(a) + r"\b", by_name[b]["desc"]))
            if edge:
                union(a, b)

    groups = {}
    for n in names:
        groups.setdefault(find(n), []).append(n)
    return groups, by_name


def family_label(members):
    """Most common non-generic name segment shared by >=2 members, else 'misc'."""
    from collections import Counter
    segs = Counter()
    for m in members:
        for s in set(m.split("-")):
            if s not in GENERIC_SEG and len(s) >= 2:
                segs[s] += 1
    for seg, c in segs.most_common():
        if c >= 2:
            return seg
    return None


def render(skills):
    groups, by_name = build_families(skills)
    fams = [m for m in groups.values() if len(m) >= 2]
    singles = [m[0] for m in groups.values() if len(m) == 1]
    fams.sort(key=lambda m: (-len(m), sorted(m)[0]))

    out = []
    out.append("# Skill 库索引")
    out.append("")
    out.append(f"> 自动生成(`whetstone index`)。{len(skills)} 个 skill · {len(fams)} 个族 · {len(singles)} 个独立。")
    out.append("> 索引 = selection menu 的导航。新增/改 description 后重跑;配合 `whetstone lint` 查重叠/撞车。")
    out.append("")
    for members in fams:
        lab = family_label(members)
        head = f"{lab} 族" if lab else f"{sorted(members)[0]} 等"
        out.append(f"## {head} ({len(members)})")
        out.append("")
        for n in sorted(members):
            s = by_name[n]
            tag = " `[symlink]`" if s["symlink"] else ""
            out.append(f"- **{n}**{tag} — {summary(s['desc'])}")
        out.append("")
    if singles:
        out.append(f"## 独立 ({len(singles)})")
        out.append("")
        for n in sorted(singles):
            s = by_name[n]
            tag = " `[symlink]`" if s["symlink"] else ""
            out.append(f"- **{n}**{tag} — {summary(s['desc'])}")
        out.append("")
    return "\n".join(out)


def main():
    ap = argparse.ArgumentParser(description="whetstone index — generate INDEX.md catalog")
    ap.add_argument("--src", default=os.environ.get("WHETSTONE_SKILLS_DIR",
                    os.path.expanduser("~/.claude/skills")))
    ap.add_argument("--out", default=None, help="write to FILE (default: stdout)")
    args = ap.parse_args()

    if not os.path.isdir(args.src):
        print(f"src not found: {args.src}", file=sys.stderr)
        return 2
    skills = lint.load_skills(args.src, include_symlinks=True)
    if not skills:
        print(f"no skills under {args.src}", file=sys.stderr)
        return 2
    text = render(skills)
    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(text + "\n")
        print(f"whetstone index: {len(skills)} skills -> {args.out}", file=sys.stderr)
    else:
        print(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
