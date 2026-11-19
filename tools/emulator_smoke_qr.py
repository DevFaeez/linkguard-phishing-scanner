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

def pick_photo():
    for node in ui().iter('node'):
        if label(node).startswith('Photo taken'):
            c=list(map(int,re.findall(r'\d+',node.get('bounds',''))))
            adb('shell','input','tap',str((c[0]+c[2])//2),str((c[1]+c[3])//2))
            return
    raise AssertionError('Missing synthetic test photo')

photo_name = ''
def replace_photo(name):
    global photo_name
    # A new media URI avoids Android Photo Picker caching overwritten file contents.
    photo_name = 'lg-smoke-' + str(time.time_ns()) + '-' + name
    destination = '/sdcard/Pictures/LinkGuardTests/' + photo_name
    adb('push',str(args.output/'fixtures'/name),destination)
    adb('shell','am','broadcast','-a','android.intent.action.MEDIA_SCANNER_SCAN_FILE','-d','file://' + destination)
    time.sleep(0.4)

try:
    adb('install','-r','-t',str(args.apk))
    adb('shell','pm','clear','my.linkguard')
    adb('shell','wm','density','480')
    adb('shell','svc','wifi','disable')
    adb('shell','svc','data','disable')
    adb('shell','mkdir','-p','/sdcard/Pictures/LinkGuardTests')
    replace_photo('02-suspicious.png')
    adb('shell','am','start','-n','my.linkguard/.MainActivity')
    assert_text('Kamera QR')
    screenshot('01-home.png')
    tap('Kamera QR')
    tap('Don’t allow')
    assert_text('Kebenaran kamera diperlukan')
    screenshot('05-camera-denied.png')
    tap('Cuba lagi')
    tap('While using the app')
    assert_text('Semak link QR')
    assert_text('http://192.0.2.1/login')
    screenshot('07-camera-confirm.png')
    checks.append('Camera imagefile feed decoded a reserved QR; denial then retry recovers')
    tap('Semak link ini')
    assert_text('Jangan buka dahulu.')
    screenshot('08-camera-result.png')
    checks.append('Camera result needs confirmation and uses local URL checker')
    tap('QR galeri')
    assert_text('This app can only access the photos you select')
    screenshot('02-photo-picker.png')
    pick_photo()
    assert_text('Semak link QR')
    screenshot('03-gallery-confirm.png')
    tap('Batal')
    checks.append('Gallery confirmation can be cancelled')
    tap('QR galeri')
    pick_photo()
    tap('Semak link ini')
    assert_text('Jangan buka dahulu.')
    screenshot('04-gallery-result.png')
    checks.append('Gallery QR reaches the same suspicious verdict offline')
    cache=adb('shell','run-as','my.linkguard','find','cache','-maxdepth','2','-type','f')
    assert not any('scaled_' in line or re.search(r'/[0-9a-f-]{36}/',line) for line in cache.splitlines()),cache
    (args.output/'cache-check.txt').write_text(cache)
    checks.append('Image-picker temporary copies removed; gallery original remains')
    assert photo_name in adb('shell','ls','/sdcard/Pictures/LinkGuardTests')
    replace_photo('03-non-web.png')
    tap('QR galeri')
    pick_photo()
    assert_text('QR ini tidak mengandungi')
    screenshot('09-non-web.png')
    checks.append('Wi-Fi QR is not executed or labelled safe')
    replace_photo('04-no-qr.png')
    tap('QR galeri')
    pick_photo()
    assert_text('Tiada QR ditemui.')
    screenshot('10-no-qr.png')
    checks.append('Image with no QR gets a clear message')
    tap('Tetapan')
    tap('English')
    assert_text('Settings')
    adb('shell','input','keyevent','BACK')
    assert_text('QR gallery')
    replace_photo('01-example.png')
    tap('QR gallery')
    pick_photo()
    assert_text('Check QR link')
    tap('Check this link')
    assert_text('No warning signs')
    screenshot('11-gallery-en.png')
    checks.append('English QR controls, confirmation and result verified')
    result={'status':'passed','version':'0.5.0+5','android_api':'34','network':'Device Wi-Fi and data disabled during QR checks','camera':'Android CameraX imagefile camera feed; synthetic reserved QR','checks':checks,'scope':'Disposable emulator only; no physical camera/device validation.'}
except Exception as exc:
    result={'status':'failed','checks':checks,'error':str(exc)}
    screenshot('failure.png')
    raise
finally:
    (args.output/'smoke-results.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
