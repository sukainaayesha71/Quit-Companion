"""Phase 1: reproducible dataset loading. Reads the raw EMASENS_ML .rds file
(never modified in place — see backend/data/EMASENS_ML/) and returns a
pandas DataFrame. Requires the dataset to already be downloaded; see
ml/README.md for how to obtain it. This module contains no training logic.
"""

from pathlib import Path

import pandas as pd
import pyreadr

# Canonical dataset location (Open Decision 6, 2026-08-17): backend/data/
# EMASENS_ML/, distinct from and superseding the earlier backend/ml/data/raw/
# copy used during initial research. Never committed — see .gitignore.
RAW_DATASET_PATH = (
    Path(__file__).resolve().parent.parent.parent
    / "data" / "EMASENS_ML" / "extracted" / "OlgaPerski-EMASENS_ML-85a23e3"
    / "data" / "analytic_sample_1.rds"
)


def load_analytic_sample_1() -> pd.DataFrame:
    """Loads the EMA-only analytic sample (6,124 rows x 98 columns) exactly
    as shipped by the dataset — read-only, no mutation of the source file."""
    if not RAW_DATASET_PATH.exists():
        raise FileNotFoundError(
            f"Dataset not found at {RAW_DATASET_PATH}. See ml/README.md for "
            "how to download EMASENS_ML from Zenodo (DOI 10.5281/zenodo.10472386)."
        )
    result = pyreadr.read_r(str(RAW_DATASET_PATH))
    df = result[None]
    return df
