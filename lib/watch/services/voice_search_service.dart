// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// Wear OS 语音搜索服务 — 利用 speech_to_text 实现离线语音识别

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// 语音搜索服务，封装 speech_to_text 的初始化、监听和结果回调。
class VoiceSearchService {
  static final VoiceSearchService _instance = VoiceSearchService._();
  factory VoiceSearchService() => _instance;
  VoiceSearchService._();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;
  bool _isListening = false;

  /// 是否已初始化
  bool get isAvailable => _initialized;

  /// 是否正在监听
  bool get isListening => _isListening;

  /// 初始化语音识别引擎
  Future<bool> initialize() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onStatus: (status) => debugPrint('VoiceSearch status: $status'),
      onError: (error) => debugPrint('VoiceSearch error: $error'),
    );
    return _initialized;
  }

  /// 开始一次语音识别，返回识别到的文本（超时或静音后自动结束）
  Future<String?> listenOnce({
    Duration listenFor = const Duration(seconds: 6),
    Duration pauseFor = const Duration(seconds: 6),
  }) async {
    if (!_initialized && !(await initialize())) return null;
    if (_isListening) return null;

    _isListening = true;
    String? result;

    await _speech.listen(
      onResult: (val) {
        if (val.finalResult) {
          result = val.recognizedWords;
        }
      },
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.search, // 搜索模式
        onDevice: true,                    // 仅本地识别（API 31+）
        autoPunctuation: false,
        listenFor: listenFor,
        pauseFor: pauseFor,
      ),
    );

    // 等待完成
    await _speech.stop();
    _isListening = false;
    return result?.trim().isNotEmpty == true ? result!.trim() : null;
  }

  /// 停止当前监听
  Future<void> stop() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
  }

  void dispose() {
    _speech.stop();
    _initialized = false;
  }
}
