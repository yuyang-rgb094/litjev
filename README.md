<div align="center">
  <img src="assets/logo.png" alt="LitJev logo" width="220">
</div>

# LitJev

**A calibrated, single-pass decision model for academic manuscript screening.**

> LitJev is a research snapshot, not a replacement for expert peer review.

---

# LitJev 中文简介

**面向学术文献初筛的、可校准、单次前向决策模型。**

> LitJev 是研究阶段模型，不是专家评审的替代品。

---

## English

LitJev maps a manuscript title and abstract to 12 typed decisions, each with
an independent probability in `[0,1]`. It does not generate prose and does not
produce a total paper score. A single forward pass emits:

- craft: `clarity`, `method_type`, `rigor`, `reproducibility`, `experiments_support`
- value: `long_term_impact`, `expert_accept`, `silent_source_potential`, `paradigm_trajectory`
- integrity: `citation_chain_clean`, `misconduct_signal`
- coverage: `in_coverage`

The model is a 4B-parameter cross-encoder built on Qwen3.5-4B. It uses a
last-token pooled representation and a small two-way head. The released
snapshot is `full-v3.1`.

For a description of training, supervision design, benchmark, limitations, and
results, see [`MODEL_CARD.md`](MODEL_CARD.md) and the paper under [`paper/`](paper/).

### Download model weights

The full `full-v3.1` base weights are distributed as assets in the GitHub
`v3.1` release (the Git tree itself does not store the multi-GB weights):

```bash
bash download_model.sh ./model
```

The script downloads the release assets, reassembles the split first
`safetensors` shard, and verifies all files against `SHA256SUMS`.

### Quick start

```bash
pip install -r requirements.txt
python inference.py --model-dir ./model --question in_coverage \
  --title "A short title" --abstract "A longer abstract..."
```

`inference.py` loads the base model and `head_final.pt`, tokenizes the
paper/proposition pair with the same template as training, and prints the
probability for the requested question.

### Repo layout

```text
download_model.sh download and reassemble the release weights
model/            local model weights (after download)
paper/            manuscript in Markdown and LaTeX
inference.py      minimal one-shot inference example
MODEL_CARD.md     technical model card
```

### License note

Our added code and head weights are released under the [MIT License](LICENSE).
The underlying Qwen3.5-4B base model remains subject to its original license.

## 中文

LitJev 将论文标题和摘要映射为 12 个类型化判断，每个判断独立输出一个
`[0,1]` 之间的概率。它不生成自然语言评审，也不输出论文总分。单次前向即可得到：

- 工艺维度：`clarity`、`method_type`、`rigor`、`reproducibility`、`experiments_support`
- 价值维度：`long_term_impact`、`expert_accept`、`silent_source_potential`、`paradigm_trajectory`
- 诚信维度：`citation_chain_clean`、`misconduct_signal`
- 覆盖维度：`in_coverage`

模型是基于 Qwen3.5-4B 的 4B 参数 cross-encoder，采用 last-token pooling 和小型
二分类 head。本次开源快照为 `full-v3.1`。

训练、监督设计、评测基准、局限性与结果见 [`MODEL_CARD.md`](MODEL_CARD.md)，
论文草稿见 [`paper/`](paper/)。

### 下载模型权重

完整 `full-v3.1` 基座权重通过 GitHub `v3.1` Release 资产发布，不放入 Git 提交历史：

```bash
bash download_model.sh ./model
```

脚本会下载 release 资产、合并被拆分的首个 `safetensors` 分片，并使用
`SHA256SUMS` 校验全部文件。

### 快速开始

```bash
pip install -r requirements.txt
python inference.py --model-dir ./model --question in_coverage \
  --title "论文标题" --abstract "论文摘要..."
```

`inference.py` 会加载 base model 与 `head_final.pt`，使用训练相同模板构造输入，
并输出所请求问题的概率。

### 目录结构

```text
download_model.sh 下载并重建 release 权重
model/            本地模型权重（下载后生成）
paper/            论文 Markdown 与 LaTeX
inference.py      最小单次推理示例
MODEL_CARD.md     技术模型卡
```

### 许可说明

我们新增的代码与 head 权重使用 [MIT License](LICENSE) 开源。底层
Qwen3.5-4B 基座模型仍受其原始许可证约束。
