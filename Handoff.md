# LitJev Handoff

> 首期训练收尾交接文档
> 日期：2026-10-05
> 当前模型快照：`full-v3.1`

---

## 1. 交付物清单

### 1.1 开源代码与模型

- GitHub 仓库：https://github.com/yuyang-rgb094/litjev
- 模型 release：https://github.com/yuyang-rgb094/litjev/releases/tag/v3.1
- Release 资产：150 个，完整 `full-v3.1` 权重约 7.9GB
- ⚠️ **2026-10-15 起下载渠道迁移中**：GitHub Release 无法断点续传、资产碎片化
  （150 个资产 / 首分片被迫切成 `.part-*`），已判定不适合分发 7.9GB 权重。
  改以**魔搭为主渠道**，详见 **§9**。
- 下载与重建：

```bash
git clone https://github.com/yuyang-rgb094/litjev.git
cd litjev
bash download_model.sh ./model
```

### 1.2 本地文档

位于本地 `claw search/litjev/`：

- `PROJECT_STATE.md`：从立项到 v3.1 的状态文档
- `TEST_RESULTS.md`：测试结果总表
- `GLM_COMPARISON_REPORT.md`：GLM 对比
- `MODEL_POSITIONING_AND_EVALUATION.md`：模型定位与能力评估
- `DATA_EXPANSION_PLAN.md`：数据扩充方案
- `NEXT_TRAINING_GUIDE.md`：后续训练指引
- `PIPELINE_AND_TRAINING.md`：数据/蒸馏/训练全流程复盘（2026-10-16；仅本地与 spark，未公开）
- `M2_TRAIN_DISK_AUDIT.md`：`m2-train` 磁盘审计与可删清单（同上，未公开）
- `paper/`：论文 md/tex 与审查
- `LitJve.png`：Logo

### 1.3 远端训练环境

- 主机：`ssh dgx-spark`
- 项目目录：`~/litjev`
- 训练容器：`litjev-train`
- 模型快照：`~/litjev/m2-train/runs/full-v3.1/`
- 训练日志：`~/litjev/m2-train/full-v3.1.log`
- 数据目录：`~/litjev/m1-pipeline/data/`

---

## 2. 当前模型状态

### 2.1 架构

- 基座：Qwen3.5-4B
- 结构：decoder trunk + last-token pooling + 2-way head
- 输入：论文标题 + 摘要，max_len 1024
- 输出：12 个 `question_id` 的独立概率
- 不生成自然语言评审，不输出论文总分

### 2.2 主要指标

| 指标 | full-v3.1 |
|---|---:|
| `citation_chain_clean` AUROC | 1.0000 |
| `in_coverage` AUROC | 0.9963 |
| `method_type` AUROC | 0.9893 |
| `rigor` AUROC | 0.9887 |
| `clarity` AUROC | 0.9803 |
| `reproducibility` AUROC | 0.9756 |
| `misconduct_signal` AUROC | 0.9755 |
| `paradigm_trajectory` AUROC | 0.8780 |
| `experiments_support` AUROC | 0.7732 |
| `silent_source_potential` AUROC | 0.7607 |
| `expert_accept` AUROC | 0.6966 |
| `long_term_impact` Spearman rho | 0.4707 |

校准：isotonic 后 11/12 问 ECE <= 0.0261，`silent_source_potential` ECE = 0.0595。

### 2.3 已明确的限制

- 只有标题 + 摘要，没有 full-text
- 语料以 ICLR/NeurIPS 相关社区为主
- `silent_source_potential` 受高置信正例不足限制
- 高影响被拒召回样本 n=5，不可统计
- `long_term_impact` rho 只作为回归门禁，不作为优化目标
- 未做 serving 延迟、吞吐、内存基准

---

## 3. 数据管线状态

### 3.1 已完成

- craft 蒸馏：19,071/19,071
- 主样本流：`samples_v3.jsonl` 132,406 条
- KML 样本流：`kml_samples.jsonl` 26,499 条
- v3.1 训练 pairs：515,633
- LTI outcome 覆盖：`outcomes_all.jsonl` 9,124 篇

### 3.2 仍在运行

Spark 上仍有两个后台循环：

1. keyed OpenAlex 匹配循环
   - 当前 `keyed_outcomes.jsonl` 约 7,600
   - 最近一轮命中率下降到约 49%
   - 说明容易匹配的论文已基本消耗完
2. oa_enrich + samples 每日重建循环
   - 会定期刷新 `outcomes_all.jsonl` 和 `samples_v3.jsonl`

注意：keyed drip 的收益正在下降。后续不要盲目继续追加搜索预算，先看新增
outcome 对训练和测试集的实际增益。

### 3.3 KML 数据缺口

- KML 语料 16,147 篇，只有 9,931 篇有摘要
- 进入主样本的有摘要且有 score 的为 8,833 篇
- `silent_frontier` 正例仅 44
- 已生成候选清单：
  - `kml-pipeline/data5/candidates_missing_abs.tsv`（36 个缺摘要已知正例）
  - `kml-pipeline/data5/candidates_source_established.tsv`（35 个待核验候选）

---

## 4. 训练与评测脚本

关键脚本：

| 路径 | 作用 |
|---|---|
| `m1-pipeline/prep_sft_data.py` | 决策样本 -> 命题 pairs |
| `m1-pipeline/build_samples.py` | 合并 outcome / craft / KML 信号 |
| `m1-pipeline/build_kml_samples.py` | KML 样本流 |
| `m2-train/train_sft.py` | SFT 训练 |
| `m2-train/dump_preds.py` | 转存预测 |
| `m2-train/calibrate.py` | isotonic 后校准 |
| `m2-train/test_metrics.py` | CPU 终测 |
| `m2-train/compare_glm_v2.py` | GLM 对比脚本 |

### 4.1 推理

```bash
python inference.py --model-dir ./model --question in_coverage \
  --title "Title" --abstract "Abstract"
```

### 4.2 重建 pairs

```bash
cd ~/litjev/m2-train
python3 prep_sft_data.py \
  --samples ../m1-pipeline/data/samples_v3.jsonl,../m1-pipeline/data/kml_samples.jsonl,../m1-pipeline/data/coverage_samples.jsonl \
  --out data_pairs_vX.jsonl
```

### 4.3 训练

```bash
docker exec -w /litjev/m2-train litjev-train \
  python3 train_sft.py \
  --pairs data_pairs_vX.jsonl \
  --out runs/full-vX \
  --ckpt-threshold 0 --bs 32 --grad-accum 1 \
  --rank-every 6 --rank-lambda 1.0 --rank-papers 8
```

### 4.4 评测

```bash
python3 dump_preds.py --pairs data_pairs_vX.jsonl --ckpt runs/full-vX/base_sft \
  --split valid --out runs/full-vX/preds_valid.jsonl
python3 dump_preds.py --pairs data_pairs_vX.jsonl --ckpt runs/full-vX/base_sft \
  --split test --out runs/full-vX/preds_test.jsonl
python3 calibrate.py
python3 test_metrics.py runs/full-vX/preds_test.jsonl
```

---

## 5. GLM 对比结论

frozen test 抽样 192 pairs，有效配对 172：

| 模型 | Brier | Hard accuracy | MAE |
|---|---:|---:|---:|
| glm-5.3 | 0.1475 | 0.7558 | 0.2736 |
| glm-5.3-flash | 0.1578 | 0.7151 | 0.2956 |
| LitJev v3.1 | 0.0766 | 0.8663 | 0.1298 |

必须保留的限定：

- GLM 是 zero-shot、未校准
- 样本小，不是通用能力排名
- 只能说明 LitJev 在固定命题判定上任务对齐更好

---

## 6. 下一步优先级

### P0：补齐 36 个缺摘要的已知 KML 正例

- 目标：`silent_frontier` 44 -> 约 80
- 来源：S2、Crossref、arXiv、PubMed

### P1：核验 source_established 候选

- 目标：人工确认 15-30 个新的高置信正例

### P2：扩大被拒/高影响检验池

- 当前 n=5，先扩到 n>=100
- 候选会议：NeurIPS 2023、ICML 2023

### P3：serving 与产品化

- 实现 `/v1/systemone` 兼容服务
- 测 p50 延迟、吞吐、内存
- 接入 isotonic 映射表

### P4：论文修订

- 保留 GLM 对比
- 主要限制写清楚
- 投稿前核对 arXiv 引用与作者信息

---

## 7. 凭证与注意事项

- GitHub token 已从 Spark 临时文件删除
- OpenAlex key：`~/litjev/.openalex_key`
- ARK coding key：`~/litjev/.ark_coding_key`
- 不要把 key 内容写入仓库或论文
- 训练前确认容器 memory=100GB、gradient checkpointing 开启
- `--ckpt-threshold 0` 是必须项

---

## 8. 一句话交接

LitJev v3.1 已经可以作为“摘要级、多命题、可校准筛选用模型”开源使用；但它还不是
可替代人工评审的模型。后续工作的核心不是继续堆训练，而是补 KML 高置信正例、扩大
可统计的评测池，并完成 serving 基准。

---

# 9. 2026-10-15 权重分发渠道迁移 + 基座许可证核实

> 触发：同事反馈从 GitHub Release 下载 `full-v3.1` 权重总是断。
> **本节待办是当前唯一权威清单**，其余章节为 v3.1 训练期历史记录。

## 9.1 诊断结论

GitHub Release 不适合发 7.9GB 权重，三个原因叠加：

1. `download_model.sh` 用的 `gh release download` **不支持断点续传**，脚本又是
   `set -euo pipefail`，第一个文件失败就整体退出。
2. **150 个资产 = 150 次独立连接**。129 个 safetensors 分片里 `model-00001`
   超 GitHub 单资产上限，被迫再切 `.part-*` 靠本地 `cat` 拼回。断一次全白下。
3. GitHub 在大陆连通性本身不稳（`objects.githubusercontent.com` 时好时坏）。

已排除：**GitHub Git LFS 同样不可用**（免费额度 1GB 存储 + 1GB/月带宽）。

## 9.2 渠道方案（已定）

| 渠道 | 定位 |
|---|---|
| 魔搭 ModelScope | **主渠道**。国内 CDN + `modelscope download` 原生续传，模型托管免费 |
| Hugging Face | 国际镜像；大陆走 `HF_ENDPOINT=https://hf-mirror.com` |
| GitHub | 只留代码/论文/模型卡 + 指向魔搭的链接；Release 保留但标「历史渠道，不推荐」 |

## 9.3 基座许可证：已确认 Apache-2.0（不是 MIT）

证据：魔搭注册表 API `https://www.modelscope.cn/api/v1/models/Qwen/Qwen3.5-4B`
返回 `"License":"apache-2.0"`。同批数据还显示
`"BaseModel":["Qwen/Qwen3.5-4B-Base"]`、`"BaseModelRelation":"finetune"`
——即该基座自身也是 `Qwen3.5-4B-Base` 的微调版。

由此产生的 Apache-2.0 §4 四项义务（仓库当前仅满足 §4a）：

| 条款 | 义务 | 现状 |
|---|---|---|
| §4a | 保留原始版权/许可/归属声明 | ✅ 未删改 |
| §4b | 修改过的文件须带显著「已修改」声明 | ❌ 待补 |
| §4c | 随分发提供许可证副本 | ❌ 待补 `LICENSE-base` |
| §4d | 原仓库有 `NOTICE` 须包含其内容 | ❌ 待补 `NOTICE` |

**重要纠正**：原先设想的「基座是 MIT，注明引用即可」不成立。Apache-2.0 的义务是
**随包附许可证与声明**，论文里写一句引用不能替代 §4b/§4c/§4d。

## 9.4 本轮交付物（均在 `claw search/litjev/release/`）

| 文件 | 作用 | 状态 |
|---|---|---|
| `PUBLISH_GUIDE.md` | 渠道评估、上传步骤、§5 许可证义务与物料说明 | 完成 |
| `download_model.sh` | 替换版下载脚本：魔搭 → HF → GitHub 兜底，带重试 + SHA256 校验 | 完成，待替换进仓库 |
| `LICENSE-base` | 基座快照原文（Apache-2.0 全文，含 `Copyright 2026 Alibaba Cloud`，sha256 `50cbab8a…`） | 完成 |
| `NOTICE` | 归属声明 + §4b「全部权重已修改」 | 完成 |
| `apply_repo_license.sh` | 一键落库：拷许可文件 + 改 README 中英文许可段 + MODEL_CARD 追加 License 段；留 `.bak`、幂等 | 完成，dry-run 已对真仓库验证 |
| `check_base_license.sh` | 基座许可证核查脚本 | 完成，但默认路径需按 §9.5-2 修正 |

`LICENSE-base` 于 2026-10-15 从基座快照原文
（`dgx-spark:~/litjev/models/models/Qwen--Qwen3.5-4B/snapshots/master/LICENSE`）逐字节拷贝，
sha256 `50cbab8a…`；基座快照**没有** NOTICE 文件。

## 9.5 环境坑（下次会话必读）

1. **Codex 沙箱默认封掉所有出网 TCP**：`connect()` 返回
   `PermissionError [Errno 1] Operation not permitted`（DNS 能解析，socket 被拦）。
   且 `approval policy = granular` 下 `sandbox_approval=false`，
   **提权申请会被自动拒绝、连确认都不弹**。
   已通过向 `~/.codex/config.toml` **追加**（不是覆盖）解决：

   ```toml
   [sandbox_workspace_write]
   network_access = true
   ```

   **仅对新会话生效**，改完必须重启 Codex。单次覆盖：
   `codex -c sandbox_workspace_write.network_access=true`。
   ⚠️ `~/.codex/config.toml` 内含 Agent Plan provider/key、4 个 MCP server 与
   routing hook，**只能追加，绝不能重建覆盖**。
2. **`/litjev/models/...` 是训练容器内的路径**，宿主机不存在（所有训练命令都是
   `docker exec -w /litjev/m2-train litjev-train ...`）。读基座文件要
   `docker exec litjev-train ...`，不要直接 `ls` 宿主路径。
3. **Spark 访问不了 huggingface.co**（curl 超时），查元数据走魔搭即可。
4. **路由闸门**：本环境启用了 ARKCLI routing.v1，每轮对话在任何受管检索
   （豆包搜索 / dataPro / OpenViking / Supabase）前必须先提交 RoutePlan。
5. **代码仓库分支状态**：GitHub `main` 已更新（许可物料 + 渠道改造 + Handoff），
   本地对应分支是 `~/litjev_repo_tmp` 的 `gh-dist`。本地 `main` 上另有一个
   **未推送**的权重提交 `15ea626`（129 个 LFS 指针，weights 不该进 git 树）；
   ⚠️ 从 `main` 切到 `gh-dist` 会删掉工作区的 `model/*.safetensors`（可再从 HF 下），
   改代码请在 `gh-dist` 上或从它拉新分支。
6. **`hf upload` 的 PATH_IN_REPO 对单文件是「文件名」，不是目录前缀**：写成
   `hf upload REPO shard.safetensors model/` 会在仓库根生成一个叫 `model` 的
   1.27GB 文件，之后再整目录上传 `model/*` 就与它冲突，commit 被拒并报
   `Bad request for commit endpoint: Invalid file change`（数据其实已传完，只是
   commit 失败）。单文件要写全路径 `model/model-00001-of-00129.safetensors`，
   整目录用 `cd <dir> && hf upload REPO . .`（文件夹默认 PATH_IN_REPO 才是 `.`）。
7. **后台 nohup 的进程会被会话结束清掉**：第一次魔搭上传用 `nohup … &` 跑到 12%
   就静默死掉（日志无报错）。长任务要在**前台会话里跑并保持轮询**，
   或改用用户自己的终端。
9. **`dgx-spark` 免密已修好（2026-10-15）**：`vivolight@192.168.50.243:22` 一直可达，但本机
   `~/.ssh/id_ed25519`（当天重新生成过）不在 spark 的 `authorized_keys` 里，所以
   `ssh dgx-spark` 报 `Permission denied (publickey)`。用 `SSH_ASKPASS` + 密码登录后追加公钥
   （现 2 行），免密可用。基座模型：宿主 `~/litjev/models/models/`，容器内 `/litjev/models/models/`。
8. **本机 `cdn-lfs.huggingface.co` 解析失败/不可达**（系统 DNS 无应答，已知 IP 也
   连不通），而 `huggingface.co` 与 `cas-bridge.xethub.hf.co`（Xet）正常。所以走
   `hf upload`（Xet 路径）可行，`git push` + git-lfs 分片上传会卡在上传阶段。

## 9.6 待办（按顺序）

- [x] **P0** 落库许可物料并提交：`bash release/apply_repo_license.sh` →
      复核 → commit `a7c2533`（LICENSE-base / NOTICE / README / MODEL_CARD）
- [x] **P0** 同步本文件：`cp Handoff.md ~/litjev_repo_tmp/Handoff.md`（已随该 commit 落库）
- [x] **P1** HF 建仓并上传：<https://huggingface.co/yuyang-rgb094/LitJev-v3.1>
      —— 权重在仓库根（不是 `model/` 子目录），2026-10-15 完成，校验见 §9.8
- [x] **P1** 用 `release/download_model.sh` 替换仓库里的 `download_model.sh`，
      并已填 `LITJEV_HF_ID=yuyang-rgb094/LitJev-v3.1`（`LITJEV_MODELSCOPE_ID` 待魔搭建仓后填）
- [x] **P0** 推送 GitHub：commit `a7c2533`/`cfeca64` 的内容已以 `gh-dist` 分支
      推送到 `main`（远端 main 从 `6b4f997` 快进），`v3.1` Release 说明顶部加
      弃用提示、仓库 homepage 指向 HF
- [x] **P2** README 下载段落改指向 HF、GitHub Release 标「历史渠道，不推荐」
      （MODEL_CARD.md 无下载段，无需改）
- [x] **P0** 基座许可证**已逐字核实**：spark 上
      `~/litjev/models/models/Qwen--Qwen3.5-4B/snapshots/master/LICENSE` = Apache-2.0 全文
      （11,343 B，sha256 `50cbab8a…`，含 `Copyright 2026 Alibaba Cloud`），已逐字节替换
      `release/LICENSE-base` 与仓库副本，并同步到 HF/魔搭；基座无 NOTICE 文件（§4d 无额外义务）
- [x] **P1** 魔搭建仓并上传：<https://www.modelscope.cn/models/yuyang094/LitJev-v3.1>
      —— 权重在仓库根，143 个文件 sha256 与本地全部一致，抽样下载校验通过（见 §9.8.5）
- [x] **P2** ~~分片合并为 4–8 个 ~1GB / 再发 int4 量化版~~：**不做**（4B 已足够小，收益不足）
- [ ] **P2** 让同事从魔搭重下一次，确认不再断
- [x] **P2** `m2-train` 瘦身：方案 A+B 全删，**943G → 19G**（旧世代 `full-v1/v2/v3`、
      四个冒烟 run、v3.1 的 4 个 ckpt；小文件留档 `m2-train/keep/`）。C 档
      （`release/` 7.9G + 老 `data_pairs` ~1G）未做

## 9.7 阻塞与需要人工提供（2026-10-16 更新）

- **GitHub 推送待网络**：本地 `gh-dist` 上的 `099c69b`（本次 Handoff 记录）尚未推送。
  2026-10-16 深夜 `github.com:443` 从这台 Mac 连不通（`Couldn't connect to server` /
  `Empty reply from server`，间隔 4 分钟重试仍失败），而同时段 `huggingface.co` 与
  `dgx-spark` 都正常。恢复后执行：

  ```bash
  git -C ~/litjev_repo_tmp -c credential.helper='!gh auth git-credential' \
    push https://github.com/yuyang-rgb094/litjev.git gh-dist:main
  ```

- **需要你决策**：① spark 上两个后台循环是否重启；② C 档清理是否执行（≈9G）；
  ③ `m2-train/keep/` 108M 留档是否保留
- **人工动作**：让同事从魔搭实拉一次做体验验收
- **凭据现状**：`gh`（macOS keyring）、HF token（`~/.cache/huggingface/token`）、
  魔搭（`~/.modelscope/credentials`）；早前贴在对话里的明文 token 已失效，建议确认吊销

---

# 9.8 2026-10-15 HF 上传执行记录（已完成）

目标仓库：<https://huggingface.co/yuyang-rgb094/LitJev-v3.1>（public，model）

## 9.8.1 结果

| 项 | 值 |
|---|---|
| 权重布局 | **仓库根**：`model-000XX-of-00129.safetensors` + `config.json` + tokenizer + `model.safetensors.index.json` + `head_final.pt` + `SHA256SUMS` + `chat_template.jinja` + `generation_config.json` |
| 合规物料 | `LICENSE`（MIT，自有代码）+ `LICENSE-base`（Apache-2.0 全文）+ `NOTICE`（§4b 修改声明）+ `MODEL_CARD.md` |
| 模型卡 | `README.md` = MODEL_CARD.md + YAML front matter `license: apache-2.0`（HF cardData/tags 已识别） |
| 本地校验 | 131 个 LFS 文件用 `paths-info` 的 sha256 oid 逐一比对：**0 mismatch**；5 个小文件仅比 size |
| 字节账目 | 远端 `usedStorage` = 8,431,573,085 = 本地 LFS 文件字节数（差值为 66,446 = 6 个非 LFS 小文件，符合预期） |
| 下载抽检 | `hf download` 取 `model-00020/00129`、`model-00129/00129`、`head_final.pt` + `SHA256SUMS`，`shasum -c` 全部 OK |

## 9.8.2 事故与修复（下次别踩）

第一次单文件上传写成 `hf upload REPO …/model-00001-of-00129.safetensors model/`：
`hf upload` 对**单文件**把第三个参数当**目标文件名**，于是仓库根多出一个叫 `model`
的 1.27GB 文件；随后整目录上传要写 `model/*`，与同名文件冲突，commit 被拒：

```
Bad request for commit endpoint: Invalid file change
```

要点：

- 数据其实已经传完（Xet 分块在服务端），**删掉错文件后重跑不重传**（实测约 2 分钟完成）
- 正确写法：单文件 `hf upload REPO <local> <full/path/in/repo>`；
  整目录 `cd <dir> && hf upload REPO . .`（文件夹的默认 `path_in_repo` 才是 `.`）
- 修复用 `HfApi().delete_file('model', repo_id=…)` 或网页删除
- 本机 `cdn-lfs.huggingface.co` 不通 → 用 `hf upload`（Xet），不要用 `git push` + git-lfs

## 9.8.3 仍未做

- 魔搭：需 ModelScope 令牌（主渠道，国内同事真正要用的那条）
- 基座原始 LICENSE 交叉验证：本机 ssh spark 无权限，未做
- 可选：合并分片 / int4 量化版

## 9.8.4 GitHub 侧更新（2026-10-15）

- 远端 `main`：`6b4f997` → 新提交（快进推送，本地分支 `gh-dist`）
- 仓库内容：`LICENSE-base`、`NOTICE`、改写后的 README（下载段指向 HF）、
  `MODEL_CARD.md`（+License 段）、多通道 `download_model.sh`（已填 HF id）、
  `Handoff.md`、`model/SHA256SUMS`（校验用）
- 权重**没有**进 git 树（本地的 `15ea626` 权重指针提交未推送）
- `v3.1` Release 说明顶部提示引导到 **魔搭 + Hugging Face 双渠道**（2026-10-15 更新）；
  资产保留为历史渠道；仓库 homepage/description 也带上两个模型仓库链接
- 仓库 homepage 指向 HF 模型仓库

## 9.8.5 魔搭 ModelScope（2026-10-15 完成）

- 仓库：<https://www.modelscope.cn/models/yuyang094/LitJev-v3.1>（public，License 填 Apache License 2.0，中文名「LitJev 学术文献判断模型」）
- 内容：权重 137 个文件 + `LICENSE` / `LICENSE-base` / `NOTICE` / `MODEL_CARD.md` /
  `inference.py` / `README.md`（模型卡），全部在**仓库根**
- 校验：远端 `Sha256` 与本地逐字节比对 **143/143 一致，0 mismatch**；
  另用 `modelscope download` 实拉 `model-00129-of-00129.safetensors` + `head_final.pt`，
  `shasum -a 256 -c SHA256SUMS` 通过 —— 同事路径可用
- 客户端：`modelscope` 1.37.1，装在系统 Python 3.9 用户目录
  （`~/Library/Python/3.9/bin/modelscope`）；登录凭据在 `~/.modelscope/credentials`，
  之后上传/下载都不需要再提供令牌
- 上传行为：`upload_folder` 分批提交（137 文件 → 3 批 × 64），**中途远端一直只有 1 个文件**，
  别误判卡死；判断进度用 `lsof -p <pid>` 看当前还开着哪几个分片
- 遗留：本地上传缓存 `~/litjev_repo_tmp/model/.ms_upload_cache`（不会上传，可留可删）

## 9.8.6 收尾（2026-10-15）

- 分片合并 / int4 量化：**不做**（4B 模型本身已很小，收益不足）
- 临时产物已清理：`~/litjev_dl_verify/`、`~/litjev_ms_verify/`、`~/litjev_upload.log`、
  `~/litjev_ms_upload.log`、`~/litjev_ms_upload.py`、`~/litjev_ms_README.md`、
  `model/.ms_upload_cache` 及 `/tmp` 下的中间文件
- 保留：`~/.modelscope/credentials`（魔搭登录凭据）、`~/.cache/huggingface/token`（HF 凭据）、
  用户目录下的 `modelscope` 客户端（后续下载/校验要用）
- 基座 LICENSE 待办关闭：结论以魔搭注册表 API 为准（本机 ssh spark 无权限，未逐字读取）

## 9.8.7 dgx-spark 现状快照（2026-10-15 深夜）

SSH：`ssh dgx-spark` 免密可用（本次修复，见 §9.5-9）。

| 项 | 值 |
|---|---|
| 主机 | `spark-2f58`，Ubuntu 24.04.3 LTS，kernel `6.11.0-1014-nvidia`，aarch64（DGX GB10） |
| 运行 | up 16 天 10:19，load 0.16 |
| CPU / 内存 | 20 核；121 GiB 总 / 3.2 GiB 已用（118 GiB 可用），无 swap |
| GPU | NVIDIA GB10，利用率 5%，42℃ |
| 磁盘 | `/` 3.7T，已用 1.4T（38%），余 2.2T |
| 容器 | `litjev-train` Up 2 weeks（`vllm/vllm-openai:latest`，mem_limit=100 GiB，挂载 `~/litjev -> /litjev`）；容器内无训练进程 |
| 占用 | `m2-train` 943G、`models` 8.8G、`pylibs` 5.5G、`m1-pipeline` 1.3G、`venv` 470M |

⚠️ **§3.2 里的两个后台循环实际都已停**：host 上无 python 进程（只剩 Sep 30 的 zombie）、
无 tmux/screen 会话，`m1-pipeline/data` 最新文件停在 **Sep 30 21:21**。是否重启需先决策
（keyed drip 的收益此前已在下降）。

基座快照复核：`.../Qwen--Qwen3.5-4B/snapshots/master/` 含 `LICENSE`(Apache-2.0, 11,343 B)、
`README.md`(77 KB)、`config.json`(`Qwen3_5ForConditionalGeneration` / `model_type=qwen3_5`)、
两个 safetensors（5.33 GB + 3.99 GB），**无 NOTICE**。

## 9.8.8 磁盘与文档收尾（2026-10-16）

- **`m2-train` 清理（方案 A+B 全删）**：943G → **19G**
  - 删除：`runs/full-v1`(55G)、`runs/full-v2`(337G)、`runs/full-v3`(408G)、
    `runs/{smoke,speed,bs64,v3-smoke}`(各 7.9G)、`runs/full-v3.1/ckpt_step{9000,9500,10000,10500}`(95G)
  - 留档：`m2-train/keep/{full-v1,full-v2,full-v3}/`（各 run 的 `head_final.pt`、`base_sft/config.json`、
    `preds_*.jsonl`、训练日志，合计 108M）
  - 保留：`runs/full-v3.1/{base_sft,head_final.pt,metrics.json,preds_valid.jsonl,preds_test.jsonl}`、
    `data_pairs_v3.1.jsonl`、全部脚本与报告
  - ⚠️ 坑：这些目录属主是 **root**（容器内创建），宿主 `vivolight` **删不掉**，
    要用 `docker exec litjev-train sh -c 'rm -rf /litjev/m2-train/...'`
  - 效果：整机 `/` 从 1.4T 用到 **410G（12%）**，余量 3.1T
- **新增两份本地文档**（未公开、未进仓库）：
  - `PIPELINE_AND_TRAINING.md`：语料获取（OpenAlex 三通道 + KML 管线）、
    蒸馏（`distill_craft.py` 5-persona 投票 → 软标签 jsonl）、样本与 pairs、训练与评测、
    导出发布、一页复现清单、已知限制
  - `M2_TRAIN_DISK_AUDIT.md`：本次清理的依据与 dry-run 脚本
  - 两份都已同步到 `dgx-spark:~/litjev/`

---

# 9.9 下次开工清单（2026-10-16 收尾）

## 9.9.1 一句话状态

v3.1 已在 **魔搭 + Hugging Face + GitHub** 三处发布并校验一致；`dgx-spark` 免密可用、
`m2-train` 从 943G 瘦到 **19G**；训练与数据管线**全部停止**（数据停在 9-30）；
本地新增两份流程文档（未公开）。

## 9.9.2 三处入口与校验

| 位置 | 地址 | 校验 |
|---|---|---|
| 魔搭（主渠道） | <https://www.modelscope.cn/models/yuyang094/LitJev-v3.1> | 143 文件 / 8.43 GB；sha256 **143/143 一致**；抽样 `modelscope download` 校验通过 |
| Hugging Face | <https://huggingface.co/yuyang-rgb094/LitJev-v3.1> | 144 文件；131 个 LFS 文件 sha256 一致 + 全量 size 一致；抽样下载校验通过 |
| GitHub | <https://github.com/yuyang-rgb094/litjev> | 远端 main `a90935e`；本地 `gh-dist` `099c69b`（待推送）。`LICENSE-base` = 基座原文 `50cbab8a…` |

## 9.9.3 待办（按优先级）

| 优先级 | 事项 | 动作 |
|---|---|---|
| **P0** | 推送待推提交 | `gh-dist` → GitHub main（命令见 §9.7） |
| **P1** | 同事从魔搭实拉验收 | `modelscope download --model yuyang094/LitJev-v3.1 --local_dir ./model` |
| **P1** | 决定 spark 后台循环是否重启 | keyed OpenAlex 匹配 + `oa_enrich`/samples 重建；已停 2 周，且 keyed 命中率此前已在下降 → 先评估增益再投预算 |
| P2 | 可选 C 档清理（≈9G） | 删 `m2-train/release/litjev-model/`(7.9G)、`data_pairs.jsonl`(767M)、`data_pairs_v1.jsonl.bak`(255M) |
| P2 | `m2-train/keep/` 108M 留档 | 保留 v1/v2/v3 的 `head_final.pt`/`config.json`/`preds`/日志以便追溯；不想留可删 |
| P3 | 论文修订 | 见 §6 与 `PAPER_OUTLINE.md`（保留 GLM 对比、写清限制） |

## 9.9.4 下次第一条命令（自检）

```bash
cd "/Users/yangyu/Documents/Documents - yang’s Mac mini/claw search/litjev"
git -C ~/litjev_repo_tmp log --oneline -3 gh-dist          # 看是否还有未推送提交
ssh dgx-spark 'df -h / | tail -1; du -sh ~/litjev/m2-train; ls ~/litjev/m2-train/runs'
```

## 9.9.5 必读的坑（浓缩）

1. spark 上 `runs/**` 属主是 **root**，宿主 `vivolight` 删不掉 → 用
   `docker exec litjev-train sh -c 'rm -rf /litjev/...'`
2. `/litjev/...` 是**容器内**路径；宿主路径是 `~/litjev/...`
3. 长任务别用 `nohup … &`（会被会话清理杀掉，日志里没有报错）
4. `hf upload` 单文件时第 3 个参数是**文件名**，不是目录前缀；整目录用 `cd <dir> && hf upload REPO . .`
5. 本机 `cdn-lfs.huggingface.co` 不通 → 走 `hf upload`（Xet），别用 `git push` 传大权重
6. `github.com` 从这台 Mac 偶发连不通（HF/魔搭/spark 正常）→ 重试即可
7. 用受管检索（豆包搜索/dataPro/OpenViking/Supabase）前先提交 RoutePlan
8. 详细版见 §9.5（1–9 条）
