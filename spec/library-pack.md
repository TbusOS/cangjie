# Skill 库打包 / 部署 (library pack & deploy)

whetstone 的产物是 skill 包;`bin/pack.sh` / `bin/deploy.sh` 把**整个本地 skill 库**打包、搬到另一台机部署。
**公开 whetstone 仓库提供这套通用方案;真实数据(你的 skill 库)只在你自己的私有 repo / 本地包里。**

## 两种模式(脱敏铁线,见 CLAUDE.md「工具 / 产物分离」)

| 模式 | 包内容 | 脱敏 | 去向 |
|---|---|---|---|
| **全量内部** —— 搬到你自己的另一台机 | 全部 skill,带真实平台值 | **不脱敏**(都是你的) | 私有 repo / 本地包,**绝不公开** |
| **分享给外人 / 公开** | 只挑要分享的 skill | **必须先脱敏**(`SoC-X` / `OTP[ADDR]` / `RSA-N`,另写 generic 版) | 公开渠道 |

## 用法

```bash
# 打包(默认 src = ~/.claude/skills;别的 runtime 用 --src)
bin/pack.sh                                  # 打全部 skill
bin/pack.sh --only verified-boot,sdk-migration   # 只打指定
bin/pack.sh --src /path/to/skills --out my.tar.gz

# 部署到新机(默认 dest = ~/.claude/skills)
bin/deploy.sh whetstone-skills-<ts>.tar.gz             # 已存在的 skill 默认 SKIP
bin/deploy.sh my.tar.gz --dest /path/to/skills --force   # 覆盖已有
```

- 排除运行时产物(`journal/ inbox/ shots/ .git/ *.bak`);包内带 `MANIFEST.txt`(名单 + 文件数 + 时间)。
- deploy **冲突默认 SKIP,不静默覆盖**;要覆盖加 `--force`。
- 暂存在 repo 下(`.pack-stage` / `.deploy-stage`),`--clean` 清理;不用 /tmp。

## 推荐:私有 repo 做长期多机同步

把你**自己的** skill 放一个**私有** git repo(带真实值,**绝不设公开**):

```bash
# 机器 A:把 skill 库装填进私有 repo(或直接 cp 你的 skill 目录进去),push
# 机器 B:
git clone <你的私有 repo>
whetstone/bin/deploy.sh <私有 repo>/<pack>.tar.gz       # 或直接 cp skill 目录进 ~/.claude/skills
```

- 好处:`git clone` 即部署 + 版本历史 + 随时同步。
- 工具(本公开仓库)`git clone` 即可;数据(私有 repo)分开,互不污染。
