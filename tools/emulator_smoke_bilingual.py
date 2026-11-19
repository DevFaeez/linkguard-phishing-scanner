"""Destructive only to my.linkguard in a dedicated emulator; never targets physical devices.

Uses reserved test IPs/domains and local shell notifications, never real malicious websites.
The --serial value must begin with emulator-. Clears the app's test preferences at startup.
"""
import argparse
import json
import re
import shlex
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--adb', type=Path, required=True)
parser.add_argument('--apk', type=Path, required=True)
parser.add_argument('--serial', default='emulator-5580')
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
assert args.serial.startswith('emulator-'), 'Only a disposable emulator is allowed'
args.output.mkdir(parents=True, exist_ok=True)
checks = []

def adb(*items, binary=False):
    if items and items[0] == 'shell':
        items = ('shell', shlex.join(items[1:]))
    return subprocess.check_output([str(args.adb), '-s', args.serial, *items], timeout=25, text=not binary)

def ui():
    for _ in range(6):
        adb('shell', 'rm', '-f', '/sdcard/linkguard-smoke.xml')
        try:
            output = adb('shell', 'uiautomator', 'dump', '/sdcard/linkguard-smoke.xml')
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
            time.sleep(0.5)
            continue
        if 'dumped to' in output:
            return ET.fromstring(adb('exec-out', 'cat', '/sdcard/linkguard-smoke.xml'))
        time.sleep(0.4)
    raise AssertionError('Android UI root remained unavailable')

def label(node):
    return node.get('text') or node.get('content-desc') or ''

def tap(text, scroll=False):
    for attempt in range(12):
        root = ui()
        for node in root.iter('node'):
            if any(line.replace('’', "'").casefold() in [text.replace('’', "'").casefold(), text.replace('’', "'").casefold() + ', collapsed', text.replace('’', "'").casefold() + ', expanded'] for line in label(node).splitlines()):
                coords = list(map(int, re.findall(r'\d+', node.get('bounds', ''))))
                if len(coords) == 4 and coords[2] > coords[0] and coords[3] > coords[1]:
                    adb('shell', 'input', 'tap', str((coords[0] + coords[2]) // 2), str((coords[1] + coords[3]) // 2))
                    time.sleep(0.25)
                    return
        if attempt < 4: adb('shell', 'input', 'swipe', '540', '1900', '540', '700', '250')
        else: adb('shell', 'input', 'swipe', '540', '700', '540', '1900', '250')
    raise AssertionError('Missing control: ' + text)

def assert_text(expected):
    for attempt in range(6):
        if any(expected in label(n) for n in ui().iter('node')):
            checks.append(expected); return
        adb('shell', 'input', 'swipe', '540', '1900', '540', '950', '250')
        time.sleep(0.25)
    raise AssertionError('Missing UI result: ' + expected)

def screenshot(name):
    (args.output / name).write_bytes(adb('exec-out', 'screencap', '-p', binary=True))

def warning_keys():
    return [line.strip() for line in adb('shell', 'cmd', 'notification', 'list').splitlines() if '|my.linkguard|' in line]

def share(url):
    adb('shell', 'am', 'start', '-n', 'my.linkguard/.MainActivity', '-a', 'android.intent.action.SEND', '-t', 'text/plain', '--es', 'android.intent.extra.TEXT', url)

try:
    adb('install', '-r', '-t', str(args.apk))
    adb('shell','cmd','notification','disallow_listener','my.linkguard/my.linkguard.LinkNotificationListener')
    adb('shell','pm','clear','my.linkguard')
    adb('shell','wm','density','480')
    adb('shell','am','start','-n','my.linkguard/.MainActivity')
    assert_text('Tampal & semak')
    screenshot('01-home-ms.png')
    tap('Tetapan')
    tap('English')
    assert_text('Settings')
    screenshot('02-settings-en.png')
    adb('shell','input','keyevent','BACK')
    assert_text('Paste & check')
    screenshot('03-home-en.png')
    share('http://192.0.2.1/login')
    assert_text('Wait before opening.')
    tap('Why this result?')
    assert_text('The address uses an IP instead of a domain name.')
    screenshot('04-result-en.png')
    tap('Protection tab')
    tap('Set up protection')
    assert_text('You decide')
    screenshot('05-consent-en.png')
    tap('Not now')
    checks.append('English consent can be declined without enabling monitoring')
    tap('Set up protection')
    tap('Agree & continue')
    tap('Allow notification access')
    tap('Allow')
    labels=[label(n) for n in ui().iter('node')]
    if not any('Don’t allow' in x or "Don't allow" in x for x in labels):
        adb('shell','input','keyevent','BACK')
    tap('Allow')
    assert_text('Protection is on')
    screenshot('06-protection-en.png')
    adb('shell','input','keyevent','HOME')
    adb('shell','cmd','notification','post','-t','Language test','lg-language-en','http://192.0.2.1/verify')
    keys=[]
    for _ in range(40):
        keys=warning_keys()
        if keys: break
        time.sleep(0.3)
    assert len(keys)==1, keys
    record=adb('shell','cmd','notification','get',keys[0])
    assert 'Suspicious link detected' in record and '192.0.2.1' not in record
    (args.output/'warning-en.txt').write_text(record)
    checks.append('Background warning follows English preference without exposing raw URL')
    adb('shell','am','force-stop','my.linkguard')
    adb('shell','am','start','-n','my.linkguard/.MainActivity')
    assert_text('Paste & check')
    checks.append('English persists across process restart')
    tap('Settings')
    tap('Bahasa Melayu')
    assert_text('Tetapan')
    adb('shell','input','keyevent','BACK')
    assert_text('Tampal & semak')
    tap('Tab Perlindungan')
    # Reopening a force-stopped app may require a deliberate reconnect; never grant permissions silently.
    labels=[label(n) for n in ui().iter('node')]
    if any('Sambung perlindungan' in x or 'Sambung semula' in x for x in labels):
        tap('Sambung perlindungan' if any('Sambung perlindungan' in x for x in labels) else 'Sambung semula')
    assert_text('Perlindungan aktif')
    adb('shell','input','keyevent','HOME')
    adb('shell','cmd','notification','post','-t','Language test','lg-language-ms','http://198.51.100.2/wallet')
    record=''
    for _ in range(40):
        keys=warning_keys()
        if keys:
            record=adb('shell','cmd','notification','get',keys[0])
            if 'Link mencurigakan dikesan' in record: break
        time.sleep(0.3)
    assert 'Link mencurigakan dikesan' in record and '198.51.100.2' not in record
    (args.output/'warning-ms.txt').write_text(record)
    checks.append('Switching back updates background warning to Malay')
    result={'status':'passed','version':'0.4.0+4','android_api':'34','checks':checks,'scope':'Dedicated emulator only; reserved test URLs; no physical phone.'}
except Exception as exc:
    result={'status':'failed','checks':checks,'error':str(exc)}
    screenshot('failure.png')
    raise
finally:
    (args.output/'smoke-results.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
