# Relapse-risk ML pipeline

Offline training and evaluation code. The API now runs a packaged experimental
XGBoost candidate by default (`RELAPSE_PREDICTOR_MODE=ml`); legacy results below
refer to the original pipeline, not the new candidate. See
[ML integration](../../docs/ML_INTEGRATION.md) for the active artifact and limits.

See `docs/superpowers/plans/2026-08-17-backend-ai-ml-implementation-plan.md`
Sections 11-12 (dataset research) and the Phase 1-6 results appendix for
full context, decisions, and honest limitations.

## Dataset — obtaining it

This pipeline uses **EMASENS_ML** (Perski et al., 2024, *PLOS Digital
Health*), **not included in this repository** (raw third-party data is
git-ignored — see `.gitignore`'s `backend/ml/data/` entry).

- Source: Zenodo, DOI [`10.5281/zenodo.10472386`](https://doi.org/10.5281/zenodo.10472386) (resolves to the
  latest version, record `12532026`, v2.0.0)
- License: **CC-BY-4.0** (Zenodo deposit metadata) / **MIT** (the
  repository's own `LICENSE` file) — both permissive, attribution to Olga
  Perski required either way.
- File: `OlgaPerski/EMASENS_ML-v2.0.0.zip`, 3,341,664 bytes,
  MD5 `a71897ea6a8fc1f38d9c9d25edf1e48f`

To reproduce:
Run `python -m ml.fetch_data` from `backend/` to download the pinned archive,
verify its checksum, and extract it into the exact `backend/data/EMASENS_ML/`
location used by the loader. Then run `python -m ml.train`.

The original manual download instructions below use an alternative location;
prefer the command above so the loader can find the extracted file.

```bash
mkdir -p ml/data/raw
curl -sL -o ml/data/raw/EMASENS_ML-v2.0.0.zip \
  "https://zenodo.org/api/records/12532026/files/OlgaPerski/EMASENS_ML-v2.0.0.zip/content"
md5sum ml/data/raw/EMASENS_ML-v2.0.0.zip  # verify against the hash above before using
python3 -c "import zipfile; zipfile.ZipFile('ml/data/raw/EMASENS_ML-v2.0.0.zip').extractall('ml/data/raw/extracted')"
```
The raw data file used is `data/analytic_sample_1.rds` inside the extracted
archive (6,124 rows x 98 columns, EMA-only, no wearable sensor data) — this
repository never modifies it in place.

## Setup

```bash
cd backend
source .venv/Scripts/activate   # .venv/bin/activate on macOS/Linux
pip install -r ml/requirements.txt   # separate from ../requirements.txt — training-only deps
```

## Run

```bash
python -m ml.train
```

Trains Random Forest + XGBoost on two feature sets (see
`pipeline/feature_mapping.py`), evaluates both, derives Low/Medium/High
thresholds from the best model, and saves everything to `ml/models/` and
`ml/outputs/` (both git-ignored).

## Known limitations (state these, do not omit them)

- **Small sample:** 38 participants, 6,124 EMA entries, 6.8% lapse rate;
  13/38 participants have zero recorded lapses.
- **UK adult quit-attempt trial population**, not Pakistan-based young
  adults/students using a consumer app long-term.
- **The feature set our app can actually supply (`cravinglog_compatible`)
  performs at or below chance level (ROC-AUC 0.48-0.50: Random Forest
  0.5032, XGBoost 0.4779)** — see `ml/outputs/training_metadata.json`
  and the plan document's Phase 1-6 results appendix. These are offline
  research metrics on the EMASENS_ML dataset, not app-compatible
  production performance. The stronger offline results come from the
  `full_ema` feature set (Random Forest ROC-AUC 0.8525, XGBoost ROC-AUC
  0.8099), which uses fields (demographics, cigarette availability,
  structured location/activity, 10-dimension affect) that `CravingLog`
  does not collect today. This is an open, unresolved decision for
  Phase 7, not a solved problem.
- This is an FYP research artifact, **not a clinically validated
  diagnostic tool**.
