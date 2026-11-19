"""Train only on URL-derived features, with disjoint registered-domain groups."""
import argparse
import hashlib
import json
import platform
import zipfile
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import pandas as pd
import sklearn
import tldextract
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import average_precision_score, confusion_matrix, precision_score, recall_score, roc_auc_score
from sklearn.model_selection import GroupShuffleSplit
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

from .features import FEATURE_NAMES, SCHEMA_VERSION, extract_features, parse_url, score_export

ROOT = Path(__file__).resolve().parents[2]
# Use the packaged PSL snapshot: no hidden network calls during training.
PSL = tldextract.TLDExtract(suffix_list_urls=(), include_psl_private_domains=True, cache_dir=None)

def group_for(url):
    _, host, _ = parse_url(url)
    result = PSL(host)
    return result.top_domain_under_public_suffix or host

def metrics(y, scores, threshold):
    predicted = scores >= threshold
    tn, fp, fn, tp = confusion_matrix(y, predicted, labels=[0, 1]).ravel()
    return {
        'threshold': float(threshold), 'samples': len(y),
        'phishing_count': int(sum(y)), 'precision': float(precision_score(y, predicted, zero_division=0)),
        'recall': float(recall_score(y, predicted, zero_division=0)),
        'false_positive_rate': float(fp / max(1, tn + fp)),
        'roc_auc': float(roc_auc_score(y, scores)), 'pr_auc': float(average_precision_score(y, scores)),
        'confusion': {'tn': int(tn), 'fp': int(fp), 'fn': int(fn), 'tp': int(tp)},
    }

def choose_threshold(y, scores, max_fpr=0.01):
    # Validation labels only. Prefer recall under the FPR budget; allow abstention.
    candidates = np.unique(np.r_[np.linspace(0, 1, 1001), scores, 1.0000001])
    negative = np.sort(scores[y == 0]); positive = np.sort(scores[y == 1])
    fprs = (len(negative) - np.searchsorted(negative, candidates, side='left')) / len(negative)
    recalls = (len(positive) - np.searchsorted(positive, candidates, side='left')) / len(positive)
    valid = np.flatnonzero(fprs <= max_fpr)
    best = valid[np.argmax(recalls[valid])]
    return float(candidates[best])

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--zip', type=Path, default=ROOT / 'data/raw/phiusiil.zip')
    args = parser.parse_args()
    archive_hash = hashlib.sha256(args.zip.read_bytes()).hexdigest()
    with zipfile.ZipFile(args.zip) as archive:
        names = [n for n in archive.namelist() if n.endswith('.csv')]
        if len(names) != 1:
            raise ValueError('Expected exactly one UCI CSV')
        with archive.open(names[0]) as stream:
            raw = pd.read_csv(stream, usecols=['URL', 'label'])
    if not set(raw.label.unique()) <= {0, 1} or raw.label.isna().any():
        raise ValueError('Unexpected UCI labels')
    # PhiUSIIL original encoding: 1 legitimate, 0 phishing. In this project 1 phishing.
    raw['target'] = 1 - raw['label'].astype(int)
    raw['URL'] = raw.URL.astype(str).str.strip()
    conflicting = set(raw.groupby('URL').target.nunique().loc[lambda x: x > 1].index)
    data = raw[~raw.URL.isin(conflicting)].drop_duplicates('URL').copy()
    records, rejected = [], 0
    for row in data.itertuples():
        try:
            records.append((row.URL, row.target, group_for(row.URL), extract_features(row.URL)))
        except ValueError:
            rejected += 1
    urls, targets, groups, features = zip(*records)
    X, y, groups = np.asarray(features), np.asarray(targets), np.asarray(groups)
    # Stable seed and groups, no test-driven selection.
    train, rest = next(GroupShuffleSplit(n_splits=1, train_size=0.70, random_state=42).split(X, y, groups))
    val_rel, test_rel = next(GroupShuffleSplit(n_splits=1, train_size=0.5, random_state=43).split(X[rest], y[rest], groups[rest]))
    val, test = rest[val_rel], rest[test_rel]
    assert not set(groups[train]) & set(groups[val])
    assert not set(groups[train]) & set(groups[test])
    assert not set(groups[val]) & set(groups[test])
    model = make_pipeline(StandardScaler(), LogisticRegression(max_iter=2000, random_state=42))
    model.fit(X[train], y[train])
    validation_scores = model.predict_proba(X[val])[:, 1]
    threshold = choose_threshold(y[val], validation_scores)
    scaler, classifier = model.steps[0][1], model.steps[1][1]
    export = {
        'schema_version': SCHEMA_VERSION, 'model_version': 'phiusiil-url-lr-v1',
        'research_only': True, 'feature_names': FEATURE_NAMES,
        'mean': scaler.mean_.tolist(), 'scale': scaler.scale_.tolist(),
        'coefficients': classifier.coef_[0].tolist(), 'intercept': float(classifier.intercept_[0]),
        'threshold': threshold, 'label': 'phishing', 'dataset_sha256': archive_hash,
        'score_note': 'Model output is not a calibrated real-world probability.',
    }
    test_scores = model.predict_proba(X[test])[:, 1]
    report = {
        'created_utc': datetime.now(timezone.utc).isoformat(), 'source': 'UCI PhiUSIIL #967',
        'source_url': 'https://archive.ics.uci.edu/dataset/967/phiusiil+phishing+url+dataset',
        'license': 'CC BY 4.0', 'original_labels': {'0': 'phishing', '1': 'legitimate'},
        'dataset_sha256': archive_hash, 'raw_rows': len(raw), 'unique_nonconflicting_rows': len(data),
        'conflicting_urls_removed': len(conflicting), 'invalid_rows_removed': rejected,
        'accepted_rows': len(records), 'features': FEATURE_NAMES,
        'splits': {name: {'rows': len(idx), 'domains': len(set(groups[idx])), 'phishing': int(sum(y[idx]))} for name, idx in [('train', train), ('validation', val), ('test', test)]},
        'domain_overlap': 0, 'validation': metrics(y[val], validation_scores, threshold),
        'test': metrics(y[test], test_scores, threshold),
        'versions': {'python': platform.python_version(), 'sklearn': sklearn.__version__, 'numpy': np.__version__, 'pandas': pd.__version__, 'tldextract': tldextract.__version__},
        'limitations': [
            'Single-source historical dataset; no future-time or Malaysian field evaluation.',
            'Only URL lexical features; cannot inspect page content or short-link destinations.',
            'Validation FPR budget is 1%; it is not guaranteed on test or live traffic.',
            'Dataset class balance differs from real notifications; precision will differ.',
            'No model comparison or calibrated probabilities yet. Not production qualified.',
        ],
    }
    for folder in ['models', 'reports', 'data/processed', 'contracts']:
        (ROOT / folder).mkdir(exist_ok=True, parents=True)
    (ROOT / 'models/model.json').write_text(json.dumps(export, indent=2) + '\n')
    (ROOT / 'reports/training.json').write_text(json.dumps(report, indent=2) + '\n')
    split_names = np.empty(len(y), dtype=object)
    for name, idx in [('train', train), ('validation', val), ('test', test)]: split_names[idx] = name
    pd.DataFrame({'url': urls, 'target': y, 'domain_group': groups, 'split': split_names}).to_csv(ROOT / 'data/processed/splits.csv', index=False)
    examples = ['https://example.com', 'example.org/path?a=1&b=2', 'http://192.0.2.1/login', 'https://user:pass@example.com:8443/a%20b?q=%40', 'https://googlé.com/verify', 'https://xn--googl-fsa.com', 'https://[2001:db8::1]/a', 'HTTPS://EXAMPLE.COM/path#part', 'https://example.co.uk/💳']
    golden = [{'url': u, 'features': extract_features(u), 'score': score_export(export, u)} for u in examples]
    (ROOT / 'contracts/golden_vectors.json').write_text(json.dumps(golden, indent=2, ensure_ascii=False) + '\n')
    parity = max(abs(score_export(export, urls[i]) - test_scores[n]) for n, i in enumerate(test[:100]))
    assert parity < 1e-12, parity
    print(json.dumps({'test': report['test'], 'accepted_rows': len(records), 'export_max_score_error': parity}, indent=2))

if __name__ == '__main__':
    main()
