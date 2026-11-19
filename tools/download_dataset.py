"""Fetch public research data only; never visit URLs inside the archive."""
import hashlib
import json
import urllib.request
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
url = 'https://archive.ics.uci.edu/static/public/967/phiusiil+phishing+url+dataset.zip'
target = root / 'data/raw/phiusiil.zip'
if target.exists():
    raise SystemExit('Archive already exists; no file was overwritten.')
target.parent.mkdir(parents=True, exist_ok=True)
temporary = target.with_suffix('.zip.part')
try:
    with urllib.request.urlopen(url, timeout=60) as response, temporary.open('wb') as stream:
        while chunk := response.read(1024 * 1024): stream.write(chunk)
    with zipfile.ZipFile(temporary) as archive:
        assert archive.testzip() is None
        assert 'PhiUSIIL_Phishing_URL_Dataset.csv' in archive.namelist()
    digest = hashlib.sha256(temporary.read_bytes()).hexdigest()
    report_path = root / 'reports/training.json'
    if report_path.exists():
        expected = json.loads(report_path.read_text())['dataset_sha256']
        if digest != expected: raise ValueError('Archive differs from the recorded training dataset; review before retraining.')
    temporary.rename(target)
    print('Dataset archive SHA-256:', digest)
finally:
    temporary.unlink(missing_ok=True)
