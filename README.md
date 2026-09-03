# dgtex-ctpred-src

Code backing the dGTEx/aGTEx ctPred training, linearization, and prediction pipeline used by
[`analysis-temi/posts/2026-08-04-reproducing-dgtex-data`](https://github.com/hakyimlab/analysis-temi/tree/main/posts/2026-08-04-reproducing-dgtex-data),
which orchestrates these scripts via `sbatch`.

This repo is code-only -- no data, predictions, or figures are tracked (see `.gitignore`). The
working directory these scripts read/write from (`data/`, `predictions/`, `figures/`, etc.) is the
separate, non-git `/beagle3/haky/users/temi/projects/dgtex` directory. Small reference/metadata
inputs the notebook needs are bundled separately as `external_inputs.zip` (see that notebook's own
README for what's in it and why the large genomic data isn't).

## Layout

- `src/` -- sbatch job scripts and the R/Python they call. Scripts directly invoked by the
  `2026-08-04-reproducing-dgtex-data` notebook:
  - `train_ctpred.sbatch` -- trains a ctPred model per tissue/context
  - `predict_with_ctpred.{sbatch,py}` -- predicts expression in Geuvadis individuals with trained ctPred models
  - `linearize_ctpred_per_tissue.sbatch` -- converts ctPred predictions into a linear (elastic-net) PredictDB model per context, via PredictDb-nextflow
  - `predict_grex_component.sbatch` -- predicts with the linearized PredictDB models via PrediXcan's `Predict.py`
  - `correlate_predictions_sqlite.{sbatch,R}` -- pairwise correlations between two SQLite prediction/observed-expression databases
  - `aggregate_epigenomes.{sbatch,py}` -- aggregates per-locus Enformer predictions into a feature CSV. `aggregate_epigenomes.py` is copied in from [`TemiPete/Enpact`](https://github.com/TemiPete/Enpact) (`src/aggregate_epigenomes.py`), the repo that actually originated it -- not tracked as a submodule, just vendored. A near-identical `aggregate_epigenomes.sbatch` also still lives at `TFXcan/src/aggregate_epigenomes.sbatch`, left there untouched because three other analysis-temi notebooks (`2025-04-23-enhancers`, `2025-09-08-dGTEX-ctpred-training`, `2025-09-17-aGTEx-ctPred-training`) reference that exact path.

  The remaining scripts in `src/` (epigenome collection/merging, other correlation variants,
  plotting, UMAP) support the broader dgtex project and downstream analysis posts, not just this
  one notebook.
- `configs/` -- example ctPred training config JSON/YAML.
- `envs/` -- exported conda environment specs for the three environments these scripts run under
  (`scPrediXcan_env`, `imlabtools`, `predictdb-env`). Recreate with e.g.
  `conda env create --prefix ./scPrediXcan_env --file envs/scPrediXcan_env.yaml`.

## Using this from the notebook

The notebook points at this repo's `src/` via a single variable (`dgtex_src_directory`) near the
top of `index.qmd` -- update that one variable if you clone this repo somewhere other than
`/beagle3/haky/users/temi/projects/dgtex-ctpred-src`.
