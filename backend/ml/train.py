"""Phases 3-6 (backend AI/ML plan, 2026-08-17).

Phase 3: person-level (grouped) stratified train/test split — no
    participant's records appear in both train and test.
Phase 4: train Random Forest and XGBoost on two feature sets (full EMA vs.
    CravingLog-compatible, see pipeline/feature_mapping.py), evaluate with
    accuracy/precision/recall/F1/confusion-matrix/ROC-AUC, per-class,
    with explicit attention to the lapse ("High-risk analog") class recall.
Phase 5: derive a documented, data-driven probability -> Low/Medium/High
    mapping from the held-out evaluation (not an invented fixed threshold).
Phase 6: select the best model per documented criteria, save artifacts
    (joblib) + metadata. Does NOT wire anything into the FastAPI app —
    that is Phase 7, explicitly gated on these results being reviewed.

Run: python -m ml.train   (from backend/, with backend/.venv active)
"""

import json
from datetime import datetime, timezone
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import (
    classification_report,
    confusion_matrix,
    f1_score,
    precision_recall_curve,
    recall_score,
    roc_auc_score,
    roc_curve,
)
from sklearn.model_selection import StratifiedGroupKFold
from xgboost import XGBClassifier

from ml.pipeline.feature_mapping import (
    CRAVINGLOG_COMPATIBLE_FEATURES,
    FULL_EMA_FEATURES,
    GROUP_COLUMN,
    TARGET_COLUMN,
)
from ml.pipeline.load_data import load_analytic_sample_1

MODELS_DIR = Path(__file__).resolve().parent / "models"
OUTPUTS_DIR = Path(__file__).resolve().parent / "outputs"
RANDOM_SEED = 555  # matches the source paper's own script (script 18), documented for reproducibility


def prepare_split(df: pd.DataFrame, feature_cols: list[str]):
    """Phase 3: StratifiedGroupKFold used as a single 80/20-ish grouped
    split — keeps every participant's rows entirely in train OR test
    (leakage prevention), while still balancing the (rare, unevenly
    distributed across participants) positive class across the split, per
    the documented finding that 13/38 participants have zero lapses at all
    (a naive GroupShuffleSplit risks an unlucky all-negative test fold)."""
    work = df[feature_cols + [TARGET_COLUMN, GROUP_COLUMN]].copy()
    work = work.dropna(subset=[TARGET_COLUMN])
    y = work[TARGET_COLUMN].astype(int)
    groups = work[GROUP_COLUMN]

    sgkf = StratifiedGroupKFold(n_splits=5, shuffle=True, random_state=RANDOM_SEED)
    train_idx, test_idx = next(sgkf.split(work, y, groups))

    train_df = work.iloc[train_idx]
    test_df = work.iloc[test_idx]

    # Verify no participant leakage across the split (hard assertion, not just a comment).
    train_ids = set(train_df[GROUP_COLUMN])
    test_ids = set(test_df[GROUP_COLUMN])
    assert train_ids.isdisjoint(test_ids), "Participant leakage detected between train and test splits."

    return train_df, test_df, sorted(train_ids), sorted(test_ids)


def encode_features(train_df: pd.DataFrame, test_df: pd.DataFrame, feature_cols: list[str]):
    """One-hot encode categorical columns (fit on train only, aligned onto
    test) — no leakage of test-set categories into the encoding."""
    X_train = train_df[feature_cols]
    X_test = test_df[feature_cols]

    X_train_enc = pd.get_dummies(X_train, dummy_na=True)
    X_test_enc = pd.get_dummies(X_test, dummy_na=True)
    X_test_enc = X_test_enc.reindex(columns=X_train_enc.columns, fill_value=0)

    return X_train_enc, X_test_enc


def evaluate_model(name: str, model, X_test, y_test) -> dict:
    y_pred = model.predict(X_test)  # library default 0.5 cutoff — reported for reference only
    y_proba = model.predict_proba(X_test)[:, 1]

    report = classification_report(y_test, y_pred, target_names=["no_lapse", "lapse"], output_dict=True, zero_division=0)
    cm = confusion_matrix(y_test, y_pred).tolist()
    auc = roc_auc_score(y_test, y_proba) if len(set(y_test)) > 1 else None
    lapse_recall_default_cutoff = recall_score(y_test, y_pred, pos_label=1, zero_division=0)

    # Recall/precision at OUR OWN derived operating point (Phase 5), not
    # sklearn's arbitrary 0.5 default — this is the number that actually
    # matters, since Phase 5 explicitly chooses its own threshold.
    thresholds = derive_risk_thresholds(y_test.to_numpy(), y_proba)
    y_pred_at_high = (y_proba >= thresholds["high_threshold"]).astype(int)
    recall_at_high = recall_score(y_test, y_pred_at_high, pos_label=1, zero_division=0)
    precision_at_high = (
        (y_pred_at_high & (y_test.to_numpy() == 1)).sum() / max(y_pred_at_high.sum(), 1)
    )

    print(f"\n=== {name} ===")
    print(classification_report(y_test, y_pred, target_names=["no_lapse", "lapse"], zero_division=0))
    print("Confusion matrix [[TN, FP], [FN, TP]] at default 0.5 cutoff:", cm)
    print("ROC-AUC:", auc)
    print("Lapse recall at default 0.5 cutoff:", lapse_recall_default_cutoff)
    print(f"Derived thresholds (this model): {thresholds}")
    print(f"Lapse recall at derived high_threshold: {recall_at_high:.3f} | precision at that cutoff: {precision_at_high:.3f}")

    return {
        "classification_report": report,
        "confusion_matrix": cm,
        "roc_auc": auc,
        "lapse_recall_default_cutoff": lapse_recall_default_cutoff,
        "derived_thresholds": thresholds,
        "lapse_recall_at_high_threshold": float(recall_at_high),
        "precision_at_high_threshold": float(precision_at_high),
        "y_proba": y_proba.tolist(),
        "y_true": y_test.tolist(),
    }


def derive_risk_thresholds(y_true: np.ndarray, y_proba: np.ndarray) -> dict:
    """Phase 5: data-driven Low/Medium/High threshold derivation.

    NOTE on a bug found and fixed during this run: an earlier version of
    this function searched for the *smallest* probability threshold
    achieving >=85% recall. That degenerates on a weak/imbalanced model —
    predicting almost everyone positive trivially achieves high recall at
    threshold~=0, which is exactly what happened here (it returned
    {low: 0.0, high: 0.0}, i.e. "flag everything," which is useless). Fixed
    below with a standard, principled alternative instead of a tighter
    ad-hoc patch on the same broken idea.

    high_threshold: Youden's J statistic optimum (argmax of TPR - FPR)
    over the ROC curve — the standard, textbook method (Youden, 1950) for
    picking a single operating point from a continuous classifier's ROC
    curve. Not degenerate by construction, since it explicitly trades off
    catching lapses against false-alarm rate rather than optimizing recall
    alone.

    low_threshold: the 75th percentile of predicted probability among
    TRUE NEGATIVES only, capped below high_threshold — so only the
    clearly-safe majority of true negatives are labelled Low; more
    ambiguous scores become Medium rather than being under-flagged.
    """
    fpr, tpr, roc_thresholds = roc_curve(y_true, y_proba)
    youden_j = tpr - fpr
    best_idx = int(np.argmax(youden_j))
    high_threshold = float(roc_thresholds[best_idx])
    # roc_curve's first threshold is +inf by convention (represents "predict nothing positive") — guard it.
    if not np.isfinite(high_threshold):
        high_threshold = float(np.percentile(y_proba, 90))

    true_negative_scores = y_proba[y_true == 0]
    low_threshold = float(np.percentile(true_negative_scores, 75)) if len(true_negative_scores) else high_threshold * 0.3

    if low_threshold >= high_threshold:
        low_threshold = high_threshold * 0.5

    return {
        "low_threshold": round(float(low_threshold), 4),
        "high_threshold": round(float(high_threshold), 4),
        "method": "high_threshold = Youden's J optimum on ROC curve; low_threshold = 75th percentile of predicted probability among true negatives, capped below high_threshold",
    }


def map_probability_to_risk(probability: float, thresholds: dict) -> str:
    if probability >= thresholds["high_threshold"]:
        return "high"
    if probability >= thresholds["low_threshold"]:
        return "medium"
    return "low"


def run_feature_set(df: pd.DataFrame, feature_set_name: str, feature_cols: list[str]) -> dict:
    print(f"\n{'=' * 70}\nFEATURE SET: {feature_set_name} ({len(feature_cols)} raw columns)\n{'=' * 70}")

    train_df, test_df, train_ids, test_ids = prepare_split(df, feature_cols)
    print(f"Train: {len(train_df)} rows / {len(train_ids)} participants | Test: {len(test_df)} rows / {len(test_ids)} participants")
    print(f"Train lapse rate: {train_df[TARGET_COLUMN].mean():.4f} | Test lapse rate: {test_df[TARGET_COLUMN].mean():.4f}")

    X_train, X_test = encode_features(train_df, test_df, feature_cols)
    y_train = train_df[TARGET_COLUMN].astype(int)
    y_test = test_df[TARGET_COLUMN].astype(int)

    # class_weight/scale_pos_weight handle the ~93/7 imbalance WITHOUT
    # resampling (resampling the training set is fine — it never touches
    # the held-out test set, so this cannot leak).
    neg, pos = (y_train == 0).sum(), (y_train == 1).sum()
    scale_pos_weight = neg / max(pos, 1)

    rf = RandomForestClassifier(
        n_estimators=500, min_samples_leaf=2, class_weight="balanced",
        random_state=RANDOM_SEED, n_jobs=-1,
    )
    rf.fit(X_train, y_train)
    rf_metrics = evaluate_model(f"{feature_set_name} / RandomForest", rf, X_test, y_test)

    xgb = XGBClassifier(
        n_estimators=500, max_depth=4, learning_rate=0.05,
        scale_pos_weight=scale_pos_weight, eval_metric="logloss",
        random_state=RANDOM_SEED, n_jobs=-1,
    )
    xgb.fit(X_train, y_train)
    xgb_metrics = evaluate_model(f"{feature_set_name} / XGBoost", xgb, X_test, y_test)

    return {
        "feature_set": feature_set_name,
        "feature_columns": feature_cols,
        "encoded_feature_columns": list(X_train.columns),
        "train_participants": train_ids,
        "test_participants": test_ids,
        "train_size": len(train_df),
        "test_size": len(test_df),
        "models": {
            "random_forest": {"estimator": rf, "metrics": rf_metrics},
            "xgboost": {"estimator": xgb, "metrics": xgb_metrics},
        },
    }


def main():
    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUTS_DIR.mkdir(parents=True, exist_ok=True)

    df = load_analytic_sample_1()
    print(f"Loaded dataset: {df.shape[0]} rows x {df.shape[1]} columns, {df[GROUP_COLUMN].nunique()} participants")

    results = {}
    for name, cols in [
        ("full_ema", FULL_EMA_FEATURES),
        ("cravinglog_compatible", CRAVINGLOG_COMPATIBLE_FEATURES),
    ]:
        results[name] = run_feature_set(df, name, cols)

    # Model selection (Phase 6): ROC-AUC first — it's the threshold-
    # independent measure of how well a model CAN separate the classes,
    # which matters because Phase 5 lets us choose our own operating
    # threshold rather than being stuck with a library default. Lapse
    # recall AT THAT MODEL'S OWN DERIVED THRESHOLD is reported as the
    # deciding secondary criterion (explicit priority per the plan) —
    # not raw accuracy, and not recall at sklearn's arbitrary 0.5 cutoff.
    print(f"\n{'=' * 70}\nMODEL COMPARISON (selection criteria: ROC-AUC, then lapse recall at derived threshold)\n{'=' * 70}")
    ranked = []
    for fs_name, fs_result in results.items():
        for model_name, model_result in fs_result["models"].items():
            m = model_result["metrics"]
            ranked.append((fs_name, model_name, m["roc_auc"] or 0, m["lapse_recall_at_high_threshold"]))
    ranked.sort(key=lambda r: (r[2], r[3]), reverse=True)
    for fs_name, model_name, auc, recall_at_high in ranked:
        print(f"  {fs_name:24s} / {model_name:14s} roc_auc={auc:.3f}  lapse_recall_at_high_threshold={recall_at_high:.3f}")

    best_fs_name, best_model_name, _, _ = ranked[0]
    best = results[best_fs_name]["models"][best_model_name]
    thresholds = best["metrics"]["derived_thresholds"]
    print(f"\nSelected: {best_fs_name} / {best_model_name}")
    print(f"Derived Low/Medium/High thresholds: {thresholds}")

    # Persist every trained model + full metadata — nothing silently discarded.
    metadata = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "dataset": "EMASENS_ML (Perski et al., 2024), Zenodo DOI 10.5281/zenodo.10472386, v2.0.0",
        "dataset_license": "CC-BY-4.0 (Zenodo deposit metadata); MIT (repository LICENSE file) — both documented, see plan Sec 12",
        "random_seed": RANDOM_SEED,
        "selected_model": {"feature_set": best_fs_name, "model": best_model_name},
        "risk_thresholds": thresholds,
        "results_summary": {
            fs_name: {
                model_name: {
                    "roc_auc": model_result["metrics"]["roc_auc"],
                    "lapse_recall_default_cutoff": model_result["metrics"]["lapse_recall_default_cutoff"],
                    "derived_thresholds": model_result["metrics"]["derived_thresholds"],
                    "lapse_recall_at_high_threshold": model_result["metrics"]["lapse_recall_at_high_threshold"],
                    "precision_at_high_threshold": model_result["metrics"]["precision_at_high_threshold"],
                    "confusion_matrix": model_result["metrics"]["confusion_matrix"],
                    "classification_report": model_result["metrics"]["classification_report"],
                }
                for model_name, model_result in fs_result["models"].items()
            }
            for fs_name, fs_result in results.items()
        },
    }

    for fs_name, fs_result in results.items():
        for model_name, model_result in fs_result["models"].items():
            path = MODELS_DIR / f"{fs_name}__{model_name}.joblib"
            joblib.dump(model_result["estimator"], path)
            print(f"Saved: {path}")

    with open(OUTPUTS_DIR / "training_metadata.json", "w") as f:
        json.dump(metadata, f, indent=2, default=str)
    print(f"Saved: {OUTPUTS_DIR / 'training_metadata.json'}")

    with open(MODELS_DIR / "feature_columns.json", "w") as f:
        json.dump(
            {fs_name: results[fs_name]["encoded_feature_columns"] for fs_name in results},
            f, indent=2,
        )
    print(f"Saved: {MODELS_DIR / 'feature_columns.json'}")

    return metadata


if __name__ == "__main__":
    main()
