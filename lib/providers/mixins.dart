import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

mixin SleepTimerMixin on ChangeNotifier {
  Timer? _sleepTimer;
  Duration? _sleepTimerRemaining;

  Duration? get sleepTimerRemaining => _sleepTimerRemaining;

  void setSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _sleepTimerRemaining = duration;
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_sleepTimerRemaining != null) {
        _sleepTimerRemaining =
            _sleepTimerRemaining! - const Duration(seconds: 1);
        _checkSleepTimer();
        // 避免每秒 notifyListeners 导致全量 rebuild：
        // 最后 5 秒实时更新 UI，其余每 5 秒更新一次。
        final seconds = _sleepTimerRemaining!.inSeconds;
        if (seconds <= 5 || seconds % 5 == 0) {
          notifyListeners();
        }
      }
    });
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimerRemaining = null;
    notifyListeners();
  }

  void disposeSleepTimer() {
    _sleepTimer?.cancel();
  }

  void _checkSleepTimer() {
    if (_sleepTimerRemaining != null &&
        _sleepTimerRemaining!.inSeconds <= 0) {
      onSleepTimerExpired();
      _sleepTimer?.cancel();
      _sleepTimerRemaining = null;
      notifyListeners();
    }
  }

  void onSleepTimerExpired();
}

mixin KeepScreenOnMixin on ChangeNotifier {
  bool _isKeepScreenOn = false;

  bool get isKeepScreenOn => _isKeepScreenOn;

  Future<void> setKeepScreenOn(bool on) async {
    _isKeepScreenOn = on;
    if (on) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
    notifyListeners();
  }

  Future<void> disposeKeepScreenOn() async {
    await WakelockPlus.disable();
  }
}
