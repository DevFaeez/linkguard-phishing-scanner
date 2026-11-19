"""Create an internal-disk build mirror to avoid ESSD AppleDouble resource files.

Source of truth remains mobile/ on ESSD. Only an explicitly owned /tmp/linkguard-flutter-work
directory may be replaced; never deletes source or arbitrary user directories.
"""
from pathlib import Path
import os
import shutil

root = Path(__file__).resolve().parents[1]
work = Path('/tmp/linkguard-flutter-work')
if work.is_symlink():
    raise SystemExit('Refusing symlink build directory')
if work.exists(): shutil.rmtree(work)
shutil.copytree(root / 'mobile', work, ignore=shutil.ignore_patterns('._*', '.dart_tool', 'build', '.gradle', '.kotlin', '.git', 'local.properties'))
flutter_command = os.environ.get('FLUTTER_BIN') or shutil.which('flutter')
if not flutter_command:
    raise SystemExit('Flutter was not found. Put flutter on PATH or set FLUTTER_BIN.')
flutter = Path(flutter_command).resolve().parents[1]
default_sdk = Path.home() / ('Library/Android/sdk' if os.uname().sysname == 'Darwin' else 'Android/Sdk')
sdk = Path(os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT') or default_sdk)
(work / 'android/local.properties').write_text(f'flutter.sdk={flutter}\nsdk.dir={sdk}\n')
print(work)
