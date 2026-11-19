import math
import numpy as np
import pytest
from linkguard_ml.features import FEATURE_NAMES, extract_features, parse_url
from linkguard_ml.train import choose_threshold, group_for

@pytest.mark.parametrize('url', ['', 'javascript:alert(1)', 'https://', 'https://example.com/a b', 'https://example.com/%ZZ', 'https://example.com:99999', 'https://example.com\\evil', 'https://exa_mple.com', 'https://-bad.com'])
def test_reject_invalid_url(url):
    with pytest.raises(ValueError): parse_url(url)

@pytest.mark.parametrize('url', ['example.com', 'https://[2001:db8::1]/', 'https://user@example.com/a?q=x', 'https://googlé.com', 'https://example.com/💳'])
def test_features_finite(url):
    values = extract_features(url)
    assert len(values) == len(FEATURE_NAMES)
    assert all(math.isfinite(x) for x in values)

def test_domain_groups_use_registered_and_private_suffixes():
    assert group_for('https://a.bank.co.uk') == group_for('https://b.bank.co.uk')
    assert group_for('https://a.github.io') != group_for('https://b.github.io')

def test_threshold_uses_budget_and_handles_ties():
    y = np.array([0, 0, 1, 1]); scores = np.array([0.1, 0.8, 0.8, 0.9])
    threshold = choose_threshold(y, scores, max_fpr=0)
    assert threshold > 0.8
    assert sum(scores[y == 0] >= threshold) == 0
    assert sum(scores[y == 1] >= threshold) == 1
