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
        notifyListeners();
        _checkSleepTimer();
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
