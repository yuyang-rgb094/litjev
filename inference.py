#!/usr/bin/env python3
"""Minimal LitJev inference example.

Expected model directory layout:
  model_dir/
    config.json
    model-*.safetensors
    tokenizer.json / tokenizer_config.json / ...
    head_final.pt
"""

import argparse

import torch
import torch.nn as nn
from transformers import AutoModelForCausalLM, AutoTokenizer


TEMPLATE = "文献标题：{title}\n文献摘要：{abstract}\n\n评估命题：{prop}\n\n基于文献内容判断：该命题是否成立？"

QUESTIONS = {
    "clarity": "本文的研究问题清晰明确",
    "method_type": "本文属于实证研究",
    "rigor": "本文的方法严谨性至少为3分(满分5分)",
    "reproducibility": "本文的可复现性至少为3分(满分5分)",
    "experiments_support": "本文的实验设置足以支撑其结论",
    "long_term_impact": "本文的长期影响力至少为3分(满分5分)",
    "expert_accept": "本文的结论会被领域专家接受",
    "silent_source_potential": "本文处于沉默期但具备成为领域源节点的潜力",
    "citation_chain_clean": "本文的引用链没有明显操纵痕迹",
    "misconduct_signal": "本文存在数据或学术不端信号",
    "in_coverage": "本文属于本模型已覆盖的学术共同体(机器学习及相关领域)",
    "paradigm_trajectory": "本文的范式轨迹属于沉默前沿",
}


class XEnc(nn.Module):
    def __init__(self, base):
        super().__init__()
        self.decoder = base.get_decoder()
        h = self.decoder.config.hidden_size
        self.head = nn.Linear(h, 2)

    def forward(self, input_ids, attention_mask):
        out = self.decoder(input_ids=input_ids, attention_mask=attention_mask)
        h = out.last_hidden_state
        idx = attention_mask.sum(1) - 1
        pooled = h[torch.arange(h.size(0)), idx].float()
        return self.head(pooled)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model-dir", required=True)
    ap.add_argument("--question", required=True, choices=sorted(QUESTIONS))
    ap.add_argument("--title", required=True)
    ap.add_argument("--abstract", required=True)
    args = ap.parse_args()

    tok = AutoTokenizer.from_pretrained(args.model_dir)
    base = AutoModelForCausalLM.from_pretrained(
        args.model_dir, dtype=torch.bfloat16, attn_implementation="sdpa"
    )
    base.config.use_cache = False
    model = XEnc(base).eval()
    model.head.load_state_dict(torch.load(f"{args.model_dir}/head_final.pt", map_location="cpu", weights_only=True))

    text = TEMPLATE.format(title=args.title, abstract=args.abstract, prop=QUESTIONS[args.question])
    enc = tok(text, return_tensors="pt", truncation=True, max_length=1024)
    with torch.no_grad():
        logits = model(enc.input_ids, enc.attention_mask)
        p = torch.softmax(logits.float(), dim=-1)[0, 1].item()
    print(f"{args.question}\t{p:.4f}")


if __name__ == "__main__":
    main()
