import json
import pytest
from fastapi.testclient import TestClient
from backend.main import ROOT, app

client = TestClient(app)

def test_health_and_model_metadata():
    assert client.get('/health').json()['status'] == 'ok'
    assert client.get('/v1/model').json()['research_only'] is True

@pytest.mark.parametrize('url,verdict', [('https://example.com', 'NO_THREAT_DETECTED'), ('http://192.0.2.1/login', 'SUSPICIOUS'), ('javascript:alert(1)', 'UNABLE_TO_SCAN')])
def test_scan(url, verdict):
    result = client.post('/v1/scan', json={'url': url})
    assert result.status_code == 200
    assert result.json()['verdict'] == verdict
    assert result.json()['research_only'] is True

def test_golden_scores_match_training():
    for record in json.loads((ROOT / 'contracts/golden_vectors.json').read_text()):
        actual = client.post('/v1/scan', json={'url': record['url']}).json()
        assert actual['score'] == pytest.approx(record['score'], abs=1e-12)

@pytest.mark.parametrize('body', [{'url': 7}, {'url': ''}, {'url': 'x' * 4097}, {'url': 'https://example.com', 'message': 'private'}])
def test_validation_rejects_without_echo(body):
    response = client.post('/v1/scan', json=body)
    assert response.status_code == 422
    assert 'input' not in response.text
    assert 'private' not in response.text

def test_oversize_body_rejected():
    assert client.post('/v1/scan', content=b'x' * 65537).status_code == 413

def test_private_url_not_logged(caplog):
    marker = 'private-reset-token-unique-12345'
    response = client.post('/v1/scan', json={'url': f'https://example.com/?token={marker}'})
    assert response.status_code == 200
    assert marker not in response.text
    assert marker not in caplog.text
