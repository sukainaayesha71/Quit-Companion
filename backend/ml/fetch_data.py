"""Download the pinned EMASENS research dataset and verify it before extraction.

Source: Olga Perski et al., EMASENS_ML v2.0.0, Zenodo record 12532026.
Run from backend: python -m ml.fetch_data
"""

import hashlib
from pathlib import Path
import urllib.request
import zipfile

DATA_DIR = Path(__file__).resolve().parents[1] / "data" / "EMASENS_ML"
URL = "https://zenodo.org/api/records/12532026/files/OlgaPerski/EMASENS_ML-v2.0.0.zip/content"
EXPECTED_MD5 = "a71897ea6a8fc1f38d9c9d25edf1e48f"


def fetch_dataset() -> Path:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    archive_path = DATA_DIR / "EMASENS_ML-v2.0.0.zip"
    if not archive_path.exists():
        with urllib.request.urlopen(URL, timeout=90) as response:
            archive = response.read(10_000_001)
        if len(archive) > 10_000_000:
            raise ValueError("Dataset download exceeded the expected archive size")
        if hashlib.md5(archive).hexdigest() != EXPECTED_MD5:
            raise ValueError("Dataset checksum mismatch; download was not saved")
        archive_path.write_bytes(archive)
    if hashlib.md5(archive_path.read_bytes()).hexdigest() != EXPECTED_MD5:
        raise ValueError("Existing dataset checksum mismatch; verify the archive before retrying")
    target = (DATA_DIR / "extracted").resolve()
    with zipfile.ZipFile(archive_path) as archive:
        for member in archive.infolist():
            destination = (target / member.filename).resolve()
            if not destination.is_relative_to(target):
                raise ValueError("Dataset archive contains an unsafe member path")
        archive.extractall(target)
    print(f"Verified EMASENS_ML v2.0.0 extracted to {target}")
    return target


if __name__ == "__main__":
    fetch_dataset()
