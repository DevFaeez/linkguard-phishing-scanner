#!/bin/sh
set -eu
project_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
if [ -z "${JAVA_HOME:-}" ] && [ -d '/Applications/Android Studio.app/Contents/jbr/Contents/Home' ]; then
    JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home'
    export JAVA_HOME
fi
python3 "$project_dir/tools/prepare_flutter_work.py"
cd /tmp/linkguard-flutter-work
flutter --suppress-analytics pub get
flutter --suppress-analytics analyze
flutter --suppress-analytics test
flutter --suppress-analytics build apk --debug --target-platform android-arm64
mkdir -p "$project_dir/releases"
cp build/app/outputs/flutter-apk/app-debug.apk "$project_dir/releases/LinkGuard-0.5.0-research-debug.apk"
python3 - "$project_dir" <<'PY'
from pathlib import Path
import hashlib,sys
folder=Path(sys.argv[1])/'releases'
(folder/'SHA256SUMS').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.name+'\n' for p in sorted(folder.glob('*.apk'))))
PY
