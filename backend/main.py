"""Run from repository root: python -m backend.run. Loopback-only development server."""
import json
import math
from pathlib import Path

from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict, Field, StrictStr

from ml.linkguard_ml.features import FEATURE_NAMES, extract_features, parse_url, score_export

ROOT = Path(__file__).resolve().parents[1]
MODEL = json.loads((ROOT / 'models/model.json').read_text())
if MODEL['schema_version'] != 1 or MODEL['feature_names'] != FEATURE_NAMES or MODEL['research_only'] is not True:
    raise ValueError('Unsupported model contract')
for key in ['mean', 'scale', 'coefficients']:
    if len(MODEL[key]) != len(FEATURE_NAMES) or not all(math.isfinite(v) for v in MODEL[key]):
        raise ValueError('Corrupt model')
if not all(v > 0 for v in MODEL['scale']) or not math.isfinite(MODEL['intercept']) or not 0 <= MODEL['threshold'] <= 1.000001:
    raise ValueError('Corrupt model values')

app = FastAPI(title='LinkGuard Research API', version='0.2.0', docs_url='/docs', redoc_url=None)

class BodyLimit:
    def __init__(self, app): self.app = app
    async def __call__(self, scope, receive, send):
        if scope['type'] != 'http' or scope['method'] != 'POST':
            return await self.app(scope, receive, send)
        data = bytearray()
        while True:
            message = await receive()
            if message['type'] == 'http.disconnect': return
            data.extend(message.get('body', b''))
            if len(data) > 65536:
                return await JSONResponse({'error': 'request_too_large'}, status_code=413)(scope, receive, send)
            if not message.get('more_body', False): break
        delivered = False
        async def replay():
            nonlocal delivered
            if not delivered:
                delivered = True
                return {'type': 'http.request', 'body': bytes(data), 'more_body': False}
            return await receive()
        return await self.app(scope, replay, send)

app.add_middleware(BodyLimit)

@app.exception_handler(RequestValidationError)
async def validation_error(_request, _error):
    # Never echo Pydantic's input field, which can contain credentials or private URL tokens.
    return JSONResponse({'error': 'invalid_request', 'message': 'Expected one URL string, maximum 4096 characters.'}, status_code=422)

class ScanRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')
    url: StrictStr = Field(min_length=1, max_length=4096)

@app.get('/health')
def health():
    return {'status': 'ok', 'service': 'linkguard', 'research_only': True}

@app.get('/v1/model')
def model_info():
    return {key: MODEL[key] for key in ['model_version', 'schema_version', 'research_only', 'dataset_sha256']}

@app.post('/v1/scan')
def scan(request: ScanRequest):
    try:
        _, host, parts = parse_url(request.url)
        values = extract_features(request.url)
        score = score_export(MODEL, request.url)
    except (ValueError, UnicodeError):
        return {'verdict': 'UNABLE_TO_SCAN', 'domain': '', 'score': None, 'reasons': ['URL tidak sah atau tidak disokong. Hanya HTTP/HTTPS sehingga 4096 aksara diterima.'], 'research_only': True, 'model_version': MODEL['model_version']}
    reasons = []
    if score >= MODEL['threshold']: reasons.append('Gabungan ciri URL melepasi ambang model eksperimen.')
    if values[10] == 1: reasons.append('Alamat menggunakan IP, bukan nama domain.')
    if parts.username is not None: reasons.append('URL mengandungi bahagian pengguna sebelum domain (@).')
    if values[12] == 1 or values[13] == 1: reasons.append('URL menggunakan punycode atau aksara bukan ASCII; semak ejaan domain.')
    if values[11] == 0: reasons.append('Sambungan HTTP tidak disulitkan.')
    if not reasons: reasons.append('Tiada petunjuk khusus daripada semakan URL setempat.')
    return {'verdict': 'SUSPICIOUS' if score >= MODEL['threshold'] else 'NO_THREAT_DETECTED', 'domain': host, 'score': score, 'reasons': reasons, 'research_only': True, 'model_version': MODEL['model_version']}
