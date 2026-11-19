"""Update Flutter assets and parity vectors; no URL is fetched or executed."""
import csv
import json
import shutil
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'ml'))
from linkguard_ml.features import extract_features, score_export

model_path = root / 'models/model.json'
model = json.loads(model_path.read_text())
assert model['schema_version'] == 1 and model['research_only'] is True
target = root / 'mobile/assets/model.json'
target.parent.mkdir(parents=True, exist_ok=True)
shutil.copyfile(model_path, target)
vectors = json.loads((root / 'contracts/golden_vectors.json').read_text())
with (root / 'data/processed/splits.csv').open() as stream:
    for row in csv.DictReader(stream):
        if row['split'] == 'test':
            url = row['url']
            vectors.append({'url': url, 'features': extract_features(url), 'score': score_export(model, url)})
            if len(vectors) >= 259: break
fixture = root / 'mobile/test/fixtures/parity_vectors.json'
fixture.parent.mkdir(parents=True, exist_ok=True)
fixture.write_text(json.dumps(vectors, indent=2, ensure_ascii=False) + '\n')
print('Synced Flutter model and', len(vectors), 'parity vectors. Re-run Flutter tests before release.')
