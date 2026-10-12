"""Send a normal WM_CLOSE to this probe's own Godot window and retain teardown output."""
import argparse
import ctypes
from ctypes import wintypes
import json
import os
from pathlib import Path
import subprocess
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--driver', choices=['Dummy', 'WASAPI'], default='Dummy')
    parser.add_argument('--mode', choices=['normal', 'menu', 'playing', 'paused', 'background', 'muted'], default='normal')
    args = parser.parse_args()
    if os.name != 'nt':
        parser.error('This probe uses Windows WM_CLOSE')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    root = Path(__file__).resolve().parents[1]
    env = os.environ.copy()
    env['APPDATA'] = str(output/'user-data')
    env['BOMB_IT_CLOSE_MODE'] = args.mode
    # Godot's console executable starts a separate GUI child process. Launch
    # the actual engine directly so the enumerated window belongs to our PID.
    engine = args.godot.replace('_console.exe', '.exe')
    command = [engine, '--path', str(root/'godot'), '--audio-driver', args.driver]
    if args.mode != 'normal':
        command += ['--script', 'res://tests/audio_close_check.gd']
    user32 = ctypes.WinDLL('user32', use_last_error=True)
    callback_type = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    user32.PostMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
    windows = []
    with (output/'stdout.log').open('w', encoding='utf-8') as log:
        process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, env=env)
        def visit(hwnd, _):
            pid = wintypes.DWORD()
            user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
            if pid.value == process.pid and user32.IsWindowVisible(hwnd):
                windows.append(hwnd)
            return True
        for _ in range(100):
            user32.EnumWindows(callback_type(visit), 0)
            if windows or process.poll() is not None:
                break
            time.sleep(0.1)
        if not windows:
            raise RuntimeError('Owned visible Godot window was not found')
        time.sleep(3)
        if args.mode != 'normal' and 'AUDIO_CLOSE_READY' not in (output/'stdout.log').read_text():
            raise RuntimeError('Close fixture did not reach its observable state')
        closing = time.monotonic()
        posted = bool(user32.PostMessageW(windows[0], 0x0010, 0, 0))  # WM_CLOSE
        # A normal user may repeat a close request during asynchronous draining.
        repeated = [bool(user32.PostMessageW(windows[0], 0x0010, 0, 0)) for _ in range(2)]
        code = process.wait(timeout=20)
    report = {'command':command,'pid':process.pid,'window':windows[0],
              'normal_WM_CLOSE_posted':posted,'exit_code':code,
              'repeated_close_posted':repeated,'close_seconds':round(time.monotonic()-closing,4),
              'mode':args.mode,'stdout_has_error':any(word in (output/'stdout.log').read_text() for word in ['ERROR:', 'WARNING:'])}
    (output/'report.json').write_text(json.dumps(report, indent=2))
    print(json.dumps(report))
    return 0 if posted and code == 0 and not report['stdout_has_error'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
