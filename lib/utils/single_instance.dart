import 'dart:io';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

// Manually bind CreateMutexW since win32 package 5.x removed it
final _kernel32 = DynamicLibrary.open('kernel32.dll');
final _CreateMutexW = _kernel32.lookupFunction<
    IntPtr Function(Pointer<Void>, Int32, Pointer<Utf16>),
    int Function(Pointer<Void>, int, Pointer<Utf16>)>('CreateMutexW');

class SingleInstance {
  static void enforce() {
    if (!Platform.isWindows) return;

    final mutexName = 'Global\\NGS_KG_PLUS_MUTEX'.toNativeUtf16();
    // 0 means FALSE in win32 package.
    final hMutex = _CreateMutexW(nullptr, 0, mutexName);
    if (GetLastError() == ERROR_ALREADY_EXISTS) {
      // Find existing window
      final windowTitle = 'NGS-KG+ / NGS-KG Plus'.toNativeUtf16();
      final hWnd = FindWindow(nullptr, windowTitle);
      if (hWnd != 0) {
        ShowWindow(hWnd, SW_RESTORE);
        SetForegroundWindow(hWnd);
      }
      free(mutexName);
      free(windowTitle);
      exit(0);
    }
    // We don't free mutexName here because we want to hold the handle
    // while the app is alive. It will be released automatically by the OS on exit.
  }
}
