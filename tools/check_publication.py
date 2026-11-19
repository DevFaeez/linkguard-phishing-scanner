#!/usr/bin/env python3
"""Check the staged snapshot without printing potential secret values."""
import re
import subprocess
import sys
from pathlib import PurePosixPath


def git(*args):
    return subprocess.check_output(['git', *args])


def inspect(path, content):
    parts = PurePosixPath(path).parts
    name = parts[-1]
    problems = []
    forbidden_parts = {'.venv', 'venv', '__pycache__', '.pytest_cache', '.dart_tool',
                       '.gradle', '.kotlin', '.idea', 'build', 'legacy', 'releases'}
    if any(part in forbidden_parts or part.startswith('._') for part in parts):
        problems.append('generated/private directory or macOS metadata')
    if name in {'.DS_Store', 'local.properties', 'key.properties', '.flutter-plugins-dependencies'}:
        problems.append('machine-specific file')
    if name.startswith('.env') and not name.endswith(('.example', '.sample')):
        problems.append('environment/credential file')
    if PurePosixPath(path).suffix.lower() in {'.pem', '.key', '.jks', '.keystore', '.p12',
                                             '.pfx', '.apk', '.aab', '.ipa', '.log', '.iml', '.db', '.sqlite'}:
        problems.append('private key, local database, log or build artifact')
    if len(parts) >= 2 and parts[0] == 'data' and parts[1] in {'raw', 'processed'} and path != 'data/raw/.gitkeep':
        problems.append('raw dataset or split manifest')
    if parts[0] == 'reports' and path not in {'reports/training.json', 'reports/verification.json'}:
        problems.append('unreviewed local report')
    if parts[0] == 'tools' and len(parts) > 1 and parts[1].startswith('jdk'):
        problems.append('downloaded local toolchain')
    if path.startswith('.github/modernize/'):
        problems.append('editor session tooling')
    if len(content) > 5 * 1024 * 1024:
        problems.append('file larger than 5 MiB')
    try:
        text = content.decode('utf-8')
    except UnicodeDecodeError:
        return problems
    rules = {
        'private key material': r'-----BEGIN (?:[A-Z ]+ )?PRIVATE KEY-----',
        'GitHub token': r'\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})',
        'AWS access key': r'\b(?:AKIA|ASIA)[A-Z0-9]{16}\b',
        'Google API key': r'\bAIza[0-9A-Za-z_-]{30,}',
        'API token': r'\bsk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{32,}',
        'Slack token': r'\bxox[baprs]-[A-Za-z0-9-]{20,}',
        'local user path': r'/(?:Users|home)/' + r'[^/\s]+/',
    }
    for label, pattern in rules.items():
        if re.search(pattern, text):
            problems.append(label)
    return problems


def main():
    names = git('diff', '--cached', '--name-only', '--diff-filter=ACMR', '-z').decode().split('\0')
    failed = []
    for path in filter(None, names):
        # Inspect staged blobs, not potentially different working-tree files.
        content = git('show', ':' + path)
        for reason in inspect(path, content):
            failed.append(f'{path}: {reason}')
    if failed:
        print('Publication check blocked these staged files:', file=sys.stderr)
        for finding in failed:
            print('  ' + finding, file=sys.stderr)
        return 1
    print('Staged-file privacy check passed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
