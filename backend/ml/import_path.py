"""Validate an explicitly mapped, authorized PATH extract without mixing EMA labels.

Usage: python -m ml.import_path approved-mapping.json
No restricted dataset is downloaded, credentials guessed or labels invented.
"""
import argparse
import json
from pathlib import Path
import pandas as pd


def import_path(manifest_path: Path) -> dict:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    required = {"access_approved", "source_file", "participant_column", "outcome_column",
                "outcome_horizon_days", "feature_mapping", "license_reference", "waves"}
    if required - manifest.keys() or manifest["access_approved"] is not True:
        raise ValueError("An approved access/mapping manifest with all required fields is required")
    if not manifest["license_reference"] or not manifest["waves"] or manifest["outcome_horizon_days"] <= 0:
        raise ValueError("Document license, waves and a positive longitudinal outcome horizon")
    source = (manifest_path.parent / manifest["source_file"]).resolve()
    data = pd.read_csv(source)
    mapping = manifest["feature_mapping"]
    columns = [manifest["participant_column"], manifest["outcome_column"], *mapping.values()]
    if set(columns) - set(data.columns): raise ValueError("Mapped PATH columns are missing")
    if data[manifest["participant_column"]].isna().any(): raise ValueError("Participant IDs must be present")
    labels = data[manifest["outcome_column"]]
    if not labels.dropna().isin([0, 1]).all(): raise ValueError("Explicitly harmonize outcomes to 0/1 before import")
    result = data[columns].rename(columns={manifest["participant_column"]: "participant_id",
        manifest["outcome_column"]: "path_longitudinal_lapse", **{source: target for target, source in mapping.items()}})
    output = Path(__file__).parent / "data/path"
    output.mkdir(parents=True, exist_ok=True)
    result.to_csv(output / "validated_path.csv", index=False)
    report = {"source": "PATH", "rows": len(result), "participants": result["participant_id"].nunique(),
              "outcome_horizon_days": manifest["outcome_horizon_days"], "waves": manifest["waves"],
              "pooled_with_emasens": False, "mapping": mapping, "license_reference": manifest["license_reference"]}
    (output / "manifest.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", type=Path)
    print(json.dumps(import_path(parser.parse_args().manifest), indent=2))
