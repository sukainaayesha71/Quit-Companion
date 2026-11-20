"""Leakage-controlled candidate selection; never changes production scoring.

Fixes the legacy pipeline's test-set threshold selection and reconstructs the
next-observed-EMA outcome within each participant, excluding censored last EMAs.
PATH cohort outcomes must be evaluated separately: they are not EMA labels.
"""
import json
from datetime import datetime, timezone
from pathlib import Path
import joblib
import numpy as np
from sklearn.base import clone
from sklearn.dummy import DummyClassifier
from sklearn.ensemble import RandomForestClassifier
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import average_precision_score, brier_score_loss, precision_score, recall_score, roc_auc_score
from sklearn.model_selection import StratifiedGroupKFold
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from xgboost import XGBClassifier

from .pipeline.feature_mapping import CRAVINGLOG_COMPATIBLE_FEATURES
from .pipeline.load_data import load_analytic_sample_1
from .train import derive_risk_thresholds

EXTRA_FEATURES = ["motivation_imp", "confidence_imp", "pain_imp", "cigarette_availability_imp"]


def build_outcomes(frame):
    ordered = frame.sort_values(["id", "EMA_date_time", "EMA_number"]).copy()
    ordered["next_lapse"] = ordered.groupby("id", observed=True)["lapse_event_imp"].shift(-1)
    # Last observations have no observed next-EMA outcome, not a negative label.
    return ordered.dropna(subset=["next_lapse"])


def metrics(y, probabilities, threshold):
    predicted = probabilities >= threshold
    return {"roc_auc": float(roc_auc_score(y, probabilities)),
            "average_precision": float(average_precision_score(y, probabilities)),
            "brier_score": float(brier_score_loss(y, probabilities)),
            "recall": float(recall_score(y, predicted, zero_division=0)),
            "precision": float(precision_score(y, predicted, zero_division=0)),
            "high_risk_fraction": float(predicted.mean()), "prevalence": float(np.mean(y))}


def participant_bootstrap(y, probability, groups, repeats=500):
    rng = np.random.default_rng(555)
    unique = np.unique(groups)
    scores = []
    for _ in range(repeats):
        chosen = rng.choice(unique, len(unique), replace=True)
        indices = np.concatenate([np.flatnonzero(groups == participant) for participant in chosen])
        if len(np.unique(y[indices])) == 2:
            scores.append(roc_auc_score(y[indices], probability[indices]))
    return [float(v) for v in np.quantile(scores, [.025, .975])] if scores else None


def main():
    frame = build_outcomes(load_analytic_sample_1())
    y = frame["next_lapse"].astype(int).to_numpy()
    groups = frame["id"].astype(str).to_numpy()
    train, test = next(StratifiedGroupKFold(n_splits=5, shuffle=True, random_state=555).split(frame, y, groups))
    assert set(groups[train]).isdisjoint(groups[test])
    models = {
        "logistic": make_pipeline(SimpleImputer(strategy="median"), StandardScaler(), LogisticRegression(max_iter=1000, C=.1)),
        "random_forest": make_pipeline(SimpleImputer(strategy="median"), RandomForestClassifier(n_estimators=200,
            min_samples_leaf=15, max_depth=8, random_state=555, n_jobs=-1)),
        "xgboost": make_pipeline(SimpleImputer(strategy="median"), XGBClassifier(n_estimators=200,
            max_depth=2, learning_rate=.03, reg_lambda=10, random_state=555, n_jobs=-1, eval_metric="logloss")),
    }
    candidates = []
    for feature_set, columns in {"current_app": CRAVINGLOG_COMPATIBLE_FEATURES,
                                 "extended_app": CRAVINGLOG_COMPATIBLE_FEATURES + EXTRA_FEATURES}.items():
        x = frame[columns].astype(float).to_numpy()
        for name, estimator in models.items():
            oof = np.zeros(len(train))
            folds = []
            for inner_train, validation in StratifiedGroupKFold(n_splits=3, shuffle=True, random_state=556).split(x[train], y[train], groups[train]):
                assert set(groups[train][inner_train]).isdisjoint(groups[train][validation])
                fitted = clone(estimator).fit(x[train][inner_train], y[train][inner_train])
                oof[validation] = fitted.predict_proba(x[train][validation])[:, 1]
                folds.append(float(roc_auc_score(y[train][validation], oof[validation])))
            thresholds = derive_risk_thresholds(y[train], oof)
            row = {"feature_set": feature_set, "model": name, "columns": columns,
                   "development": metrics(y[train], oof, thresholds["high_threshold"]),
                   "fold_roc_auc": folds, "thresholds": thresholds}
            print(json.dumps(row), flush=True)
            candidates.append(row)
    # All choices and thresholds are fixed from development data before test scoring.
    selected = max(candidates, key=lambda row: row["development"]["average_precision"])
    columns = selected["columns"]
    x = frame[columns].astype(float).to_numpy()
    fitted = clone(models[selected["model"]]).fit(x[train], y[train])
    probability = fitted.predict_proba(x[test])[:, 1]
    baseline = DummyClassifier(strategy="prior").fit(x[train], y[train]).predict_proba(x[test])[:, 1]
    result = metrics(y[test], probability, selected["thresholds"]["high_threshold"])
    report = {"generated_at": datetime.now(timezone.utc).isoformat(),
        "outcome": "lapse at the next observed EMA within the same participant; last EMAs excluded",
        "dataset": "EMASENS_ML v2.0.0", "selection": "development grouped CV average precision; thresholds from development OOF predictions",
        "train_participants": sorted(set(groups[train])), "test_participants": sorted(set(groups[test])),
        "candidates": candidates, "selected": selected, "heldout": result,
        "heldout_roc_auc_95_percent_participant_bootstrap": participant_bootstrap(y[test], probability, groups[test]),
        "dummy_baseline": metrics(y[test], baseline, .5),
        "production_approved": False,
        "remaining_validation": ["Independent prospective app cohort", "Calibration and subgroup assessment", "Clinical advisor review", "PATH cohort data access and explicit outcome harmonization"],
        "population_limit": "UK adult cigarette quit-attempt EMA study; not validated for vaping, pouches or hookah"}
    out = Path(__file__).parent / "outputs"
    out.mkdir(exist_ok=True)
    (out / "candidate_evaluation.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    joblib.dump({"estimator": fitted, "columns": columns, "thresholds": selected["thresholds"],
                 "production_approved": False}, Path(__file__).parent / "models" / "app_candidate.joblib")
    print(json.dumps({"selected": selected["feature_set"] + "/" + selected["model"], "heldout": result,
                      "production_approved": False}), flush=True)
    return report


if __name__ == "__main__": main()
