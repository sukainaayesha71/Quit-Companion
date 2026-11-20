from subprocess import CompletedProcess, TimeoutExpired
from unittest.mock import patch

from tools.local_services import restore_android_forwarding


def test_reconnect_restores_missing_forwarding_only_for_authorized_devices():
    with patch('tools.local_services.shutil.which', return_value='adb'), patch(
        'tools.local_services.subprocess.run', side_effect=[
            CompletedProcess([], 0, 'List of devices attached\nphone\tdevice\nlocked\tunauthorized\n'),
            CompletedProcess([], 0, ''),
            CompletedProcess([], 0, b'8000'),
        ],
    ) as run:
        restore_android_forwarding()
    assert run.call_count == 3
    assert run.call_args.args[0] == ['adb', '-s', 'phone', 'reverse', 'tcp:8000', 'tcp:8000']


def test_existing_forwarding_does_not_issue_duplicate_command():
    with patch('tools.local_services.shutil.which', return_value='adb'), patch(
        'tools.local_services.subprocess.run', side_effect=[
            CompletedProcess([], 0, 'List of devices attached\nphone\tdevice\n'),
            CompletedProcess([], 0, 'UsbFfs tcp:8000 tcp:8000\n'),
        ],
    ) as run:
        restore_android_forwarding()
    assert run.call_count == 2


def test_adb_timeout_does_not_stop_backend_supervision():
    with patch('tools.local_services.shutil.which', return_value='adb'), patch(
        'tools.local_services.subprocess.run', side_effect=TimeoutExpired('adb', 5),
    ):
        restore_android_forwarding()
