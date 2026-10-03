# LitJev Model Card

## English

- **Model name:** LitJev `full-v3.1`
- **Base model:** Qwen3.5-4B
- **Task:** typed academic manuscript decision heads from title + abstract
- **Architecture:** decoder trunk, last-token pooling, two-way classification head
- **Output:** 12 independent probabilities in `[0,1]`
- **Input:** title and abstract only
- **Training data:** 515,633 NLI-style paper/proposition pairs; train 268,039 / validation 137,987 / test 109,607
- **Limitations:** abstract-only input; ICLR/NeurIPS-centric community benchmark; rare value-class supervision is limited; no serving latency benchmark; not full-text.

### Frozen test results

| question_id | AUROC | n |
|---|---:|---:|
| citation_chain_clean | 1.0000 | 1,590 |
| in_coverage | 0.9963 | 2,587 |
| method_type | 0.9893 | 24,670 |
| rigor | 0.9887 | 19,736 |
| clarity | 0.9803 | 14,802 |
| reproducibility | 0.9756 | 19,736 |
| misconduct_signal | 0.9755 | 2,277 |
| paradigm_trajectory | 0.8780 | 8,235 |
| experiments_support | 0.7732 | 4,934 |
| silent_source_potential | 0.7607 | 974 |
| expert_accept | 0.6966 | 3,794 |

Post-hoc calibration: ECE <= 0.0261 for 11/12 heads; `silent_source_potential` ECE = 0.0595.

`long_term_impact` is evaluated per paper with cohort Spearman rho = 0.4707 on the frozen test cohort. This metric is reported as a regression baseline, not as an optimization target.

## 中文

- **模型名称：** LitJev `full-v3.1`
- **基座模型：** Qwen3.5-4B
- **任务：** 从标题 + 摘要生成类型化的学术文献判断
- **架构：** decoder trunk + last-token pooling + 二分类 head
- **输出：** 12 个独立的 `[0,1]` 概率
- **输入：** 仅标题和摘要
- **训练数据：** 515,633 条 NLI 风格论文/命题对；train 268,039 / validation 137,987 / test 109,607
- **局限：** 仅摘要级输入；benchmark 以 ICLR/NeurIPS 为中心；稀少价值类监督有限；未测 serving 延迟；不支持全文。

### 冻结测试结果

| question_id | AUROC | n |
|---|---:|---:|
| citation_chain_clean | 1.0000 | 1,590 |
| in_coverage | 0.9963 | 2,587 |
| method_type | 0.9893 | 24,670 |
| rigor | 0.9887 | 19,736 |
| clarity | 0.9803 | 14,802 |
| reproducibility | 0.9756 | 19,736 |
| misconduct_signal | 0.9755 | 2,277 |
| paradigm_trajectory | 0.8780 | 8,235 |
| experiments_support | 0.7732 | 4,934 |
| silent_source_potential | 0.7607 | 974 |
| expert_accept | 0.6966 | 3,794 |

后校准结果：11/12 个 head 的 ECE <= 0.0261；`silent_source_potential` ECE = 0.0595。

`long_term_impact` 使用 per-paper cohort Spearman rho = 0.4707；该指标仅作为回归基线记录，不作为优化目标。
