# 采集适配器 (Capture Adapters)

采集 = 会话结束时,把原材料(cwd、git HEAD、改了几个文件、transcript 路径)**追加**到
`../../journal/`,供后续 `/distill` 挖掘。**全程只追加、从不覆盖,可放心自动。**

**采集是可选的,也是 Whetstone 唯一的 runtime-专属环节。** 不接采集也能用——做完功能手动跑蒸馏即可。

| Runtime | 怎么采集 |
|---|---|
| Claude Code | 把 `claude-code.sh` 接进 settings.json 的 `Stop` / `SessionEnd` hook:`{"command": "bash <abs>/claude-code.sh"}` |
| Codex / Cursor / 其他 | 用各自的会话结束事件 / hook 调一个等价脚本;或**手动**——做完功能直接触发蒸馏(无需采集) |

清理:`bash claude-code.sh --clean`(或 `whetstone capture --clean`)。

## 实测

```bash
bash adapters/capture/selftest.sh      # 或 whetstone selftest
```

隔离跑(repo 下 `.capture-selftest`,不碰真 journal,不用 /tmp),覆盖:jq 路径、python 回退
(`WHETSTONE_FORCE_PY=1` 强制走 python 分支)、空 stdin、`--clean`。journal 写在 **skill 根的
`journal/`**(脚本里 `SKILL_DIR` 是 `adapters/capture/` 上跳两级——正是 `/distill` 读的那个目录)。

## 新增一个 runtime 的采集脚本

照 `claude-code.sh` 的契约——读会话信息(stdin JSON 或环境)→ 取 cwd / transcript →
记 git 状态 → 往 `journal/sessions.jsonl` 追加一行紧凑 JSON(只放指针,**不放 diff 内容、
不放任何 secret**)。建议照 `selftest.sh` 也加一份隔离自测。

> 跨 runtime(Codex / Cursor 等)采集:契约中立、可照搬,但**尚未在真实 Codex/Cursor 上实测**。
