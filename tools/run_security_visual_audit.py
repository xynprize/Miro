"""Render game-owned QA screenshots on a separate Windows desktop, without switching it."""
import ctypes
import subprocess
from ctypes import wintypes as W
from pathlib import Path

root = Path(__file__).resolve().parents[1]
u = ctypes.WinDLL('user32', use_last_error=True)
k = ctypes.WinDLL('kernel32', use_last_error=True)
class SI(ctypes.Structure):
    _fields_ = [('cb', W.DWORD), ('lpReserved', W.LPWSTR), ('lpDesktop', W.LPWSTR), ('lpTitle', W.LPWSTR), ('dwX', W.DWORD), ('dwY', W.DWORD), ('dwXSize', W.DWORD), ('dwYSize', W.DWORD), ('dwXCountChars', W.DWORD), ('dwYCountChars', W.DWORD), ('dwFillAttribute', W.DWORD), ('dwFlags', W.DWORD), ('wShowWindow', W.WORD), ('cbReserved2', W.WORD), ('lpReserved2', ctypes.POINTER(ctypes.c_byte)), ('hStdInput', W.HANDLE), ('hStdOutput', W.HANDLE), ('hStdError', W.HANDLE)]
class PI(ctypes.Structure):
    _fields_ = [('hProcess', W.HANDLE), ('hThread', W.HANDLE), ('dwProcessId', W.DWORD), ('dwThreadId', W.DWORD)]
u.CreateDesktopW.argtypes = [W.LPCWSTR, W.LPCWSTR, ctypes.c_void_p, W.DWORD, W.DWORD, ctypes.c_void_p]
u.CreateDesktopW.restype = W.HANDLE
u.CloseDesktop.argtypes = [W.HANDLE]
k.CreateProcessW.argtypes = [W.LPCWSTR, W.LPWSTR, ctypes.c_void_p, ctypes.c_void_p, W.BOOL, W.DWORD, ctypes.c_void_p, W.LPCWSTR, ctypes.POINTER(SI), ctypes.POINTER(PI)]
k.WaitForSingleObject.argtypes = [W.HANDLE, W.DWORD]
k.CloseHandle.argtypes = [W.HANDLE]
k.TerminateProcess.argtypes = [W.HANDLE, W.UINT]
desktop = u.CreateDesktopW('MiroSecurityQA', None, None, 0, 0x1FF, None)
if not desktop:
    raise ctypes.WinError(ctypes.get_last_error())
exe = r'C:\towerdefense\tools\godot\Godot_v4.7.2-stable_win64.exe'
args = [exe, '--path', str(root), '--rendering-method', 'gl_compatibility', '--windowed', '--log-file', str(root/'tmp/security-layout-capture.log'), '--script', 'res://tools/capture_security_layout.gd']
si = SI()
si.cb = ctypes.sizeof(si)
si.lpDesktop = 'WinSta0\\MiroSecurityQA'
pi = PI()
try:
    if not k.CreateProcessW(exe, ctypes.create_unicode_buffer(subprocess.list2cmdline(args)), None, None, False, 0, None, str(root), ctypes.byref(si), ctypes.byref(pi)):
        raise ctypes.WinError(ctypes.get_last_error())
    k.CloseHandle(pi.hThread)
    if k.WaitForSingleObject(pi.hProcess, 60000) == 258:
        k.TerminateProcess(pi.hProcess, 1)
        raise TimeoutError('Visual QA exceeded 60 seconds')
    k.CloseHandle(pi.hProcess)
finally:
    u.CloseDesktop(desktop)
print((root/'tmp/security-layout-capture.log').read_text(errors='replace')[-1500:])
