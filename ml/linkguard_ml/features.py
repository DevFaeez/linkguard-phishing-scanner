"""Feature contract v1. No DNS requests or page fetching are performed."""
import math
import re
from collections import Counter
from urllib.parse import urlsplit

SCHEMA_VERSION = 1
MAX_URL_LENGTH = 4096
FEATURE_NAMES = [
    'url_length', 'host_length', 'path_length', 'query_length', 'digit_ratio',
    'dot_count', 'hyphen_count', 'at_count', 'percent_count', 'subdomain_count',
    'is_ip', 'is_https', 'has_punycode', 'has_unicode', 'query_count',
    'slash_count', 'entropy', 'suspicious_token_count',
]
TOKENS = ['login', 'verify', 'secure', 'account', 'update', 'password', 'wallet', 'confirm']

def parse_url(value: str):
    raw = value.strip()
    if not raw or len(raw) > MAX_URL_LENGTH:
        raise ValueError('URL kosong atau terlalu panjang (maksimum 4096 aksara).')
    if any(c.isspace() or ord(c) < 32 or ord(c) == 127 for c in raw) or '\\' in raw:
        raise ValueError('URL mengandungi ruang atau aksara tidak dibenarkan.')
    if re.search(r'%(?![0-9a-fA-F]{2})', raw):
        raise ValueError('Percent encoding tidak sah.')
    candidate = raw if '://' in raw else 'https://' + raw
    try:
        parts = urlsplit(candidate)
        host = (parts.hostname or '').lower().rstrip('.')
        port = parts.port
        if parts.scheme.lower() not in ('http', 'https') or not host:
            raise ValueError('Hanya URL HTTP atau HTTPS diterima.')
        if port is not None and not 1 <= port <= 65535:
            raise ValueError('Port tidak sah.')
        if ':' in host:
            import ipaddress
            ipaddress.IPv6Address(host)
        else:
            ascii_host = host.encode('idna').decode('ascii')
            if len(ascii_host) > 253 or any(not re.fullmatch(r'[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?', label) for label in ascii_host.split('.')):
                raise ValueError('Domain tidak sah.')
    except (ValueError, UnicodeError) as exc:
        raise ValueError('URL atau domain tidak sah.') from exc
    return candidate, host, parts

def extract_features(value: str) -> list[float]:
    url, host, parts = parse_url(value)
    length = len(url)
    counts = Counter(url)
    entropy = -sum((n / length) * math.log2(n / length) for n in counts.values())
    # Contract deliberately uses syntactic IP shape in both Python and Kotlin.
    is_ip = ':' in host or bool(re.fullmatch(r'[0-9]+(?:\.[0-9]+){3}', host))
    return [float(v) for v in [
        length, len(host), len(parts.path), len(parts.query),
        sum('0' <= c <= '9' for c in url) / length,
        url.count('.'), url.count('-'), url.count('@'), url.count('%'),
        max(0, len(host.split('.')) - 2), is_ip, parts.scheme.lower() == 'https',
        any(label.startswith('xn--') for label in host.split('.')),
        any(ord(c) > 127 for c in url), 0 if not parts.query else parts.query.count('&') + 1,
        url.count('/'), entropy, sum(token in url.lower() for token in TOKENS),
    ]]

def score_export(model: dict, url: str) -> float:
    values = extract_features(url)
    z = model['intercept'] + sum(
        ((v - mean) / scale) * coef
        for v, mean, scale, coef in zip(values, model['mean'], model['scale'], model['coefficients'], strict=True)
    )
    return 1 / (1 + math.exp(-max(-700, min(700, z))))
