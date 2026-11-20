import hashlib
import io
import zipfile

import pytest

from ml import fetch_data


def _archive(name: str) -> bytes:
    stream = io.BytesIO()
    with zipfile.ZipFile(stream, "w") as archive:
        archive.writestr(name, b"fixture dataset")
    return stream.getvalue()


def test_checksum_mismatch_is_rejected_without_saving(tmp_path, monkeypatch):
    monkeypatch.setattr(fetch_data, "DATA_DIR", tmp_path)
    monkeypatch.setattr(fetch_data.urllib.request, "urlopen", lambda *a, **kw: io.BytesIO(b"bad response"))
    with pytest.raises(ValueError, match="checksum mismatch"):
        fetch_data.fetch_dataset()
    assert list(tmp_path.iterdir()) == []


def test_verified_archive_extracts_and_reuses_the_cached_download(tmp_path, monkeypatch):
    archive = _archive("source/data/sample.rds")
    monkeypatch.setattr(fetch_data, "DATA_DIR", tmp_path)
    monkeypatch.setattr(fetch_data, "EXPECTED_MD5", hashlib.md5(archive).hexdigest())
    monkeypatch.setattr(fetch_data.urllib.request, "urlopen", lambda *a, **kw: io.BytesIO(archive))
    extracted = fetch_data.fetch_dataset()
    assert (extracted / "source/data/sample.rds").read_bytes() == b"fixture dataset"

    def no_network(*args, **kwargs):
        raise AssertionError("Verified cache should avoid the network")

    monkeypatch.setattr(fetch_data.urllib.request, "urlopen", no_network)
    assert fetch_data.fetch_dataset() == extracted


def test_archive_paths_cannot_escape_the_extraction_directory(tmp_path, monkeypatch):
    archive = _archive("../escape.rds")
    monkeypatch.setattr(fetch_data, "DATA_DIR", tmp_path)
    monkeypatch.setattr(fetch_data, "EXPECTED_MD5", hashlib.md5(archive).hexdigest())
    monkeypatch.setattr(fetch_data.urllib.request, "urlopen", lambda *a, **kw: io.BytesIO(archive))
    with pytest.raises(ValueError, match="unsafe member path"):
        fetch_data.fetch_dataset()
    assert not (tmp_path / "escape.rds").exists()
