"""Local API supervision. Run from backend: python tools/local_services.py --worker

--worker processes pending assessments. Explicit --notifications also enables
opt-in push/feedback jobs; production Compose runs the full worker separately.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time


def restore_android_forwarding():
    """Restore localhost access for connected Android devices after reconnects."""
    adb = shutil.which('adb')
    if not adb:
        candidate = Path(os.environ.get('LOCALAPPDATA', '')) / 'Android/Sdk/platform-tools/adb.exe'
        if candidate.is_file(): adb = str(candidate)
    if not adb: return
    try:
        result = subprocess.run([adb, 'devices'], capture_output=True, text=True, timeout=5)
        if result.returncode: return
        for line in result.stdout.splitlines()[1:]:
            parts = line.split()
            if len(parts) != 2 or parts[1] != 'device': continue
            serial = parts[0]
            current = subprocess.run([adb, '-s', serial, 'reverse', '--list'], capture_output=True, text=True, timeout=5)
            if current.returncode or any(row.split()[-2:] == ['tcp:8000', 'tcp:8000'] for row in current.stdout.splitlines()):
                continue
            forwarded = subprocess.run([adb, '-s', serial, 'reverse', 'tcp:8000', 'tcp:8000'], capture_output=True, timeout=5)
            if not forwarded.returncode:
                print('Android backend forwarding restored on port 8000', flush=True)
    except (OSError, subprocess.TimeoutExpired):
        pass  # A disconnected device must not interrupt the API or worker.


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--worker', action='store_true')
    parser.add_argument('--notifications', action='store_true')
    parser.add_argument('--usb', action='store_true', help='Restore Android port forwarding after reconnects')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    runtime = root / '.runtime'
    runtime.mkdir(exist_ok=True)
    commands = {'api': [sys.executable, '-m', 'uvicorn', 'app.main:app', '--host', '127.0.0.1', '--port', '8000']}
    if args.worker:
        commands['worker'] = [sys.executable, '-m', 'app.worker'] + ([] if args.notifications else ['--assessments-only'])
    children = {}
    try:
        while True:
            if args.usb: restore_android_forwarding()
            for name, command in commands.items():
                if name not in children or children[name].poll() is not None:
                    children[name] = subprocess.Popen(command, cwd=root)
                    print(f'{name} started; pid={children[name].pid}', flush=True)
                    (runtime / 'services.json').write_text(json.dumps({key: child.pid for key, child in children.items()}))
            time.sleep(5)
    except KeyboardInterrupt:
        pass
    finally:
        for child in children.values():
            if child.poll() is None: child.terminate()
        for child in children.values(): child.wait(timeout=10)


if __name__ == '__main__': main()
