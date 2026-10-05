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
