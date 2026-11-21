/// 系统级播放信息（FR-21 息屏续播 / FR-22 通知栏与锁屏控制）
///
/// 播放器后台卡片由 Android 原生 MediaNotificationService 直接发 MediaStyle 通知：
/// 本文件只负责把"当前混音 + 倒计时 + 进度"推给原生，并接收通知按钮的播放/暂停/停止回调。
/// 不再依赖 audio_service 的通知状态机（在部分 ROM 上它不会 push 通知）。
/// 音频本身仍由 audioplayers 多实例输出。
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../audio/playback_controller.dart';
import '../audio/timer_controller.dart';
import '../core/analytics.dart';
import '../core/constants.dart';
import '../data/preset_controller.dart';

/// 通知链路桥：Dart -> Native 推状态，Native -> Dart 收控制
class NowPlaying {
  NowPlaying._();

  static const MethodChannel _media = MethodChannel('soughmix/media');

  static bool _initialized = false;
  static PlaybackController? _boundPb;
  static TimerController? _boundTimer;
  static PresetController? _boundPresets;
  static VoidCallback? _listener;
  static String? _lastKey;

  /// 是否可用（桌面端无媒体通知，直接跳过）
  static bool get isActive => _initialized && Platform.isAndroid;

  /// 诊断用：反映原生通知服务的真实状态
  static Map<String, String> diagnose() {
    if (!_initialized) return {'service': '未初始化'};
    final pb = _boundPb;
    final timer = _boundTimer;
    return {
      'service': '已启动',
      'playing': '${pb?.isPlaying ?? false}',
      'processingState': (pb?.channels.isEmpty ?? true) ? 'idle' : 'ready',
      'mediaItem': (pb != null ? _title(pb) : null) ?? '(空)',
      'countdown': (timer != null && timer.isRunning) ? _fmt(timer.remaining) : '-',
    };
  }

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  /// 启动时调用一次。任何异常只记埋点，不影响播放。
  static Future<void> init(
    PlaybackController pb,
    TimerController timer,
    PresetController presets,
  ) async {
    if (!_supported || _initialized) return;
    try {
      _boundPb = pb;
      _boundTimer = timer;
      _boundPresets = presets;

      // 通知按钮回调：播放/暂停、上一首/下一首切方案、退出都落到同一个控制器
      _media.setMethodCallHandler((call) async {
        if (call.method != 'control') return;
        final action = (call.arguments as Map?)?['action'] as String?;
        switch (action) {
          case 'play':
            await pb.ensurePlaying();
            break;
          case 'pause':
            await pb.pause();
            break;
          case 'toggle':
            await pb.togglePlayPause();
            break;
          case 'stop':
            await pb.stopAll();
            break;
          case 'next':
            await _switchPreset(pb, presets, next: true);
            break;
          case 'prev':
            await _switchPreset(pb, presets, next: false);
            break;
        }
      });

      void sync() {
        try {
          final key = _syncKey(pb, timer);
          if (key == _lastKey) return; // 去重：同一秒不重复推
          _lastKey = key;
          _push(pb, timer);
        } catch (e) {
          Analytics.instance.log('now_playing_error', {'error': '$e'});
        }
      }

      _listener = sync;
      pb.addListener(sync);
      timer.addListener(sync);
      _initialized = true;
      sync();
    } catch (e) {
      Analytics.instance.log('startup_error', {'stage': 'now_playing', 'error': '$e'});
    }
  }

  /// 通知栏上/下一首：在方案列表里循环切换并载入。
  /// 手动混音（无 currentPresetId）时 next 从第一个开始、prev 从最后一个开始。
  static Future<void> _switchPreset(
    PlaybackController pb,
    PresetController presets, {
    required bool next,
  }) async {
    final list = presets.presets;
    if (list.isEmpty) return;
    int idx = list.indexWhere((p) => p.id == pb.currentPresetId);
    if (next) {
      idx = (idx + 1) % list.length;
    } else {
      idx = idx <= 0 ? list.length - 1 : idx - 1;
    }
    await pb.loadPreset(list[idx]);
  }

  /// 把倒计时剩余秒数纳入去重键，TimerController 每 500ms notify 一次，
  /// 秒数变化那次会真正推给原生，卡片上的倒计时才会每秒刷新。
  static String _syncKey(PlaybackController pb, TimerController timer) {
    final ids = pb.channels.map((c) => c.sourceId).join(',');
    final sec = timer.isRunning ? timer.remaining.inSeconds : -1;
    return '${pb.isPlaying}|${timer.phase.name}|${timer.type?.name}|$ids|$sec|${pb.currentPresetId}';
  }

  static String _fmt(Duration d) {
    final s = d.inSeconds;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = (s % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$sec' : '$m:$sec';
  }

  static String? _title(PlaybackController pb) {
    final names = pb.channels
        .map((c) => soundById(c.sourceId)?.name ?? c.sourceId)
        .join(' · ');
    return names.isEmpty ? null : names;
  }

  static void _push(PlaybackController pb, TimerController timer) {
    final playing = pb.isPlaying;
    final tracks = pb.channels.length;

    // 完全没有音轨：撤掉通知服务
    if (tracks == 0) {
      unawaited(_media.invokeMethod('stop').catchError((_) {}));
      return;
    }

    // 载入的是方案时，副标题带上方案名，切方案后卡片上能直接看到当前是哪个方案
    final presetId = pb.currentPresetId;
    String? presetName;
    if (presetId != null) {
      for (final p in _boundPresets?.presets ?? const []) {
        if (p.id == presetId) {
          presetName = p.name;
          break;
        }
      }
    }
    final subtitle = StringBuffer(presetName != null ? '$presetName · $tracks 轨' : '$tracks 轨');
    if (timer.isRunning && timer.type != null) {
      final label = timer.type == TimerType.sleep ? '睡眠' : '休息';
      subtitle.write(' · $label ${_fmt(timer.remaining)}');
    } else if (timer.phase == TimerPhase.finished) {
      subtitle.write(' · 倒计时结束');
    }

    final elapsed = timer.isRunning && timer.total > timer.remaining
        ? timer.total - timer.remaining
        : Duration.zero;

    unawaited(_media.invokeMethod('update', <String, Object?>{
      'title': _title(pb) ?? '枕声',
      'subtitle': subtitle.toString(),
      'playing': playing,
      'position': elapsed.inMilliseconds,
      'duration': timer.isRunning ? timer.total.inMilliseconds : 0,
    }).catchError((_) {}));
  }

  /// 释放监听（测试/热重载用）
  static void dispose() {
    final l = _listener;
    final pb = _boundPb;
    if (l != null && pb != null) pb.removeListener(l);
    _boundPb = null;
    _boundTimer = null;
    _boundPresets = null;
    _listener = null;
    _lastKey = null;
    _initialized = false;
  }
}
