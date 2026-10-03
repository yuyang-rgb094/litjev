# LitJev: A Calibrated Single-Pass Decision Model for Academic Manuscript Screening

> arXiv draft, in-domain systems/evaluation paper.
> Replace author metadata before submission.

## Abstract

Evaluating academic manuscripts with large generative models is expensive,
slow, and produces free-form assessments that are difficult for software agents
to consume. This paper presents LitJev, a 4B-parameter single-pass decision
model that maps a manuscript title and abstract to twelve typed decisions, each
with a calibrated probability, without autoregressive generation or growing
KV-cache. The model is trained with three groups of supervision: craft
questions use teacher distillation as a cold-start signal, value questions use
long-term academic outcomes and knowledge-manifold trajectory labels rather
than current large-model consensus, and integrity/coverage questions use
retraction, manipulation-cluster, programmatic-perturbation, and out-of-domain
signals. On a frozen, year-held-out in-domain benchmark, eight of twelve
question heads achieve AUROC above 0.95, eleven of twelve achieve post-hoc
expected calibration error at or below 0.026, and the explicit
domain-coverage head reaches AUROC 0.996. An exploratory comparison shows that
the specialized model produces lower Brier score than zero-shot general-purpose
models on the same typed propositions, while several rare-class value tasks
remain limited by supervision. We intentionally do not optimize the
long-term-impact rank-correlation beyond a regression gate, because citation
alignment is not the same as evidence that the model can recognize silent
frontiers.

## 1. Introduction

Scientific publishing increasingly depends on preliminary screening under
resource constraints. A complete expert review is expensive and slow; a
generative large language model (LLM) review is faster but still has several
limitations for machine-to-machine workflows: (1) it is costly at scale; (2)
it emits free-form prose that downstream systems must parse; (3) it is often
uncertain in ways that are not expressed as usable probabilities; and (4) if
used as a value judge, it tends to reproduce current mainstream consensus.

LitJev is a deliberate System-1 counterpart to generative System-2 review. It
is not a reviewer, a chatbot, or a journal decision system. It is a
task-specific decision model that produces a fixed vector of per-question
probabilities in one forward pass. The contributions of this work are:

1. a twelve-question typed decision schema spanning craft, value, integrity,
   and domain-coverage dimensions;
2. a three-signal supervision design in which only time-invariant craft
   dimensions are teacher-distilled, while value dimensions use academic
   outcomes and trajectory geometry instead of current LLM opinion;
3. a 4B-parameter cross-encoder implementation with soft-label training and a
   pair-ranking objective for long-term-impact thresholds;
4. a frozen in-domain benchmark with explicit calibration and OOD abstention;
5. an exploratory zero-shot comparison with two general-purpose models, framed
   as evidence about task specialization rather than a superiority claim.

## 2. Related Work

**System-1 decision models.** Jev introduced the idea of training models to
produce typed decisions and calibrated probabilities instead of generating
text. OpenJev and mini-jev showed that compact cross-encoders can approximate
this downstream shape for benchmark-style inference. RLCD, the calibration
method behind Jev, has not been fully disclosed; we therefore follow the
public RLCR formulation only as a conceptual reference and do not claim to
reproduce RLCD.

**Outcome-based review.** ReviewGuard aligns review signals toward future
citation impact. APRES searches for rubrics that predict future citations.
These systems demonstrate that long-term outcome signals can be learned, but
they also measure consensus-compatible ranking signals. Our design keeps these
signals for instrumented monitoring but does not make them the primary target
of all value supervision.

**Knowledge manifold learning and silent frontiers.** KML models citation
trajectories as a graph manifold and defines source nodes, silent-frontier
trajectories, and manipulation clusters. This family of signals is used for
value and integrity supervision because it explicitly addresses papers whose
early citation patterns do not yet reflect long-term influence.

**Calibration and abstention.** Temperature scaling and isotonic regression are
standard post-hoc calibration tools. Selective prediction and OOD detection are
relevant for models that should abstain outside their training community. We
implement an `in_coverage` question head rather than a generative refusal.

## 3. Task Formulation

LitJev receives a structured paper state. The current snapshot uses only title
and abstract. The output is a vector:

```
y = [p_1, ..., p_12],  p_i in [0,1]
```

The twelve question heads are grouped as follows:

| Group | Question | Output |
|---|---|---|
| Craft | clarity | choice posterior |
| Craft | method_type | choice posterior |
| Craft | rigor | 1–5 threshold set |
| Craft | reproducibility | 1–5 threshold set |
| Craft | experiments_support | predicate probability |
| Value | long_term_impact | 1–5 threshold set |
| Value | expert_accept | predicate probability |
| Value | silent_source_potential | predicate probability |
| Value | paradigm_trajectory | five-class posterior |
| Integrity | citation_chain_clean | predicate probability |
| Integrity | misconduct_signal | predicate probability |
| Coverage | in_coverage | predicate probability |

The model does not output a total score and does not rank papers against one
another. Each probability is exposed independently so that a downstream agent
can enforce its own decision rules.

## 4. Supervision Design

### 4.1 Craft dimensions

Clarity, method type, rigor, reproducibility, and experimental support are
treated as time-invariant properties. They are cheap for a strong teacher to
estimate and are not the main source of value bias. We produce soft labels by
prompting a commercial teacher with five reviewer personas per paper and
taking the vote distribution.

### 4.2 Value dimensions

Value labels are not teacher-distilled. `long_term_impact` is derived from
citation counts normalized within venue-year cohorts. `expert_accept` is a
human decision anchor. `silent_source_potential` and `paradigm_trajectory` use
KML source and trajectory criteria.

The reason is conceptual: frontier ideas can be systematically misestimated by
consensus models during the silent period. Distilling a general-purpose LLM for
these questions would therefore train on the wrong direction for a key
differentiator.

### 4.3 Integrity and coverage

Integrity labels combine retraction status, KML manipulation clusters, and
programmatically perturbed negatives. The coverage question is trained with
in-domain ML-community papers as positives and twelve OpenAlex scientific
domains as negatives. It allows the model to express "this input is outside my
coverage" as a first-class decision.

## 5. Data

### 5.1 Sources

The main community corpus contains ICLR and NeurIPS submissions with decision
metadata, augmented with OpenAlex citation information, Semantic Scholar
matching, arXiv identifiers, and KML trajectory features. OOD negatives are
sampled from mathematics, physics, chemistry, biology, medicine, economics,
psychology, geology, materials science, sociology, history, and philosophy.

### 5.2 Pair construction

Each decision sample becomes one or more NLI-style premise-hypothesis pairs.
Choice questions emit one pair per value. Score questions emit threshold
propositions ("at least k"). Binary predicates emit one proposition. A paper is
the premise; a proposition is the hypothesis.

### 5.3 Final snapshot

| Split | Pair count |
|---|---:|
| train | 268,039 |
| validation | 137,987 |
| test | 109,607 |
| total | 515,633 |

The test split is held out by year and is not used for model selection or
calibration fitting. Calibration mappings are fit on validation only.

## 6. Model and Training

The model uses Qwen3.5-4B as a decoder trunk, takes the last token of the
concatenated input, and maps the pooled representation to a two-way head. The
positive-class logit is softmax-normalized into the decision probability.

Training uses a soft cross-entropy loss against target probabilities and a
RankNet-style pair loss for long-term-impact papers within the same
venue-year cohort:

```
L = L_CE + lambda * L_rank
```

The full parameter set is fine-tuned in bf16 with gradient checkpointing.
Sortish length bucketing reduces padding. Checkpoints store optimizer and
scheduler state for exact resumption.

After training, each question is calibrated independently on validation using
temperature scaling and isotonic regression. The final head outputs are
monotonically remapped before use.

## 7. Evaluation

### 7.1 Metrics

- AUROC: binary discrimination for predicate and threshold questions.
- Brier: squared error against the stored target probability.
- ECE: ten-bin expected calibration error after post-hoc calibration.
- `rho_LTI`: cohort-level Spearman correlation of per-paper expected score.
- `high_impact_rejected_recall`: recovered high-impact rejected manuscripts.

### 7.2 Comparators

For an exploratory comparison, we evaluate GLM-5.3 and GLM-5.3-Flash on the
same 192-pair stratified test sample with zero-shot prompting and JSON-encoded
probabilities. The models are general-purpose and are not calibrated; the
comparison is not intended to establish general capability.

## 8. Results

### 8.1 Frozen held-out benchmark

| Question | AUROC | n |
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

`long_term_impact` reports per-paper rank calibration rather than a single
AUROC. On the frozen test cohort, `rho_LTI = 0.4707` with n=1,568. We present
this number as a regression baseline, not as the headline value capability.

### 8.2 Calibration

After isotonic calibration, ECE is at or below 0.0261 for eleven of twelve
question heads. The exception is `silent_source_potential`, with ECE 0.0595.

### 8.3 Training lineage

| Snapshot | Change | paradigm_trajectory test | silent_source_potential test | rho_LTI test |
|---|---|---:|---:|---:|
| v2 | full SFT | 0.913 | 0.757 | 0.474 |
| v3 | ranking loss, coverage, strong rare oversampling | 0.857 | 0.762 | 0.470 |
| v3.1 | reduced rare oversampling, continuation | 0.878 | 0.761 | 0.470 |

The v3.1 checkpoint recovers most of the paradigm-trajectory regression while
preserving the silent-source value signal.

### 8.4 Exploratory GLM comparison

| Model | Brier | Hard accuracy | MAE |
|---|---:|---:|---:|
| GLM-5.3 | 0.1475 | 0.7558 | 0.2736 |
| GLM-5.3-Flash | 0.1578 | 0.7151 | 0.2956 |
| LitJev v3.1 | 0.0766 | 0.8663 | 0.1298 |

The comparison is at most preliminary evidence for task specialization and
must not be read as a general-capability ranking.

## 9. Discussion

The main architectural value of LitJev is not a new model family but an
explicit separation between signals. Craft dimensions may be teacher-supervised
because they are time-invariant. Value dimensions require slow, structurally
defined signals because consensus models are biased in the exact regime that a
silent-frontier detector must handle.

We deliberately avoid optimizing `rho_LTI` beyond a regression gate. Citation
alignment is a useful instrumentation channel, but it is not identical to
recognizing under-appreciated work, and optimizing it too strongly can push
the model back toward mainstream consensus.

## 10. Limitations

- The model uses title and abstract only; full-text understanding is future
  work.
- The community benchmark is ICLR/NeurIPS-centric and not a general academic
  sample.
- `silent_source_potential` and `high_impact_rejected_recall` have insufficient
  positive supervision for decisive conclusions.
- The GLM comparison is zero-shot, uncalibrated, and based on 172 paired
  examples.
- No serving-level latency or throughput benchmark is included.
- The study does not perform multi-seed replications, bootstrap tests, or a
  formal train/test contamination audit.
- The absence of domain coverage is not a substitute for robustness outside
  the trained community.

## 11. Conclusion

We introduced LitJev, a trained single-pass decision model for manuscript
screenings. It provides twelve independent, calibrated decision head and an
explicit coverage signal. On an in-domain held-out benchmark it is strong on
craft, integrity, and coverage tasks, while its rare value-class tasks remain
data-limited. The model is therefore positioned as a rapid screening and
calibration instrument, not as a replacement for expert review.

## Acknowledgements

We thank Dongbi Technology Data (Dongbi Data), the Chinese Academy of Sciences,
and Professor Dengsheng Wu of Shenzhen University for foundational
philosophical contributions to the principles of paper evaluation.

## References

[1] TypeSafe AI. Jev: typed, calibrated decisions.  
[2] OpenJev / mini-jev. Open reimplementation of a System-1 decision model.  
[3] RLCR. Reinforcement Learning for Calibrated Decisions. arXiv:2507.16806.  
[4] ReviewGuard. Aligning review models with future citation outcomes. arXiv:2606.24892.  
[5] APRES. Rubric discovery for predictable future citations. arXiv:2603.03142.  
[6] Citation prediction is more learnable than review scores. arXiv:2503.05712.  
[7] Yu Yang. Knowledge Manifold Learning, 2026.  
[8] QGT V2/V3. Preceding manifold-quality studies in the same project repository.
