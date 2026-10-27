/// 倒计时控制器（FR-14~20, E-01/E-08/E-11）
/// 计时基于墙钟绝对到期时间（DateTime.now 差值），锁屏/休眠唤醒后自动校正（PRD 9.2）。
/// 同一时刻仅允许一个倒计时：启动新倒计时前必须处理已有计时（E-08）。
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../core/analytics.dart';
import 'audio_engine.dart';
import 'playback_controller.dart';

enum TimerType { sleep, rest }

enum TimerPhase { idle, running, fading, finished, cancelled }

class RestTimerResult {
  final TimerPhase phase;
  final TimerType type;
  RestTimerResult(this.phase, this.type);
}

class TimerController extends ChangeNotifier {
  TimerController(this._playback, this._engine);

  final PlaybackController _playback;
  final AudioEngine _engine;

  TimerType? type;
  TimerPhase phase = TimerPhase.idle;
  DateTime _endTime = DateTime.now();
  Duration _total = Duration.zero;
  Duration _fadeWindow = const Duration(minutes: 5); // FR-15 结束前 5 分钟渐弱
  Timer? _tick;
  double _lastFade = 1.0;

  Duration get remaining {
    final r = _endTime.difference(DateTime.now());
    return r.isNegative ? Duration.zero : r;
  }

  /// 本次倒计时的总时长（进度环分母；idle 时为 0）
  Duration get total => _total;

  /// 进度 0~1（已流逝比例；idle 为 0）
  double get progress =>
      _total == Duration.zero ? 0 : 1 - remaining.inMilliseconds / _total.inMilliseconds;

  bool get isRunning => phase == TimerPhase.running || phase == TimerPhase.fading;

  /// 启动倒计时。返回错误信息（E-01 空混音 / E-08 冲突由调用方 UI 处理）。
  Future<RestTimerResult?> start({
    required TimerType timerType,
    required Duration duration,
    VoidCallback? onRestNotify,
  }) async {
    if (isRunning) return RestTimerResult(phase, timerType); // E-08：由 UI 弹「替换/取消」
    type = timerType;
    _fadeWindow = timerType == TimerType.sleep && duration < const Duration(minutes: 6)
        ? const Duration(minutes: 1) // FR-15：自定义 <6 分钟改为结束前 1 分钟
        : const Duration(minutes: 5);
    _endTime = DateTime.now().add(duration); // 墙钟：绝对到期点
    _total = duration;
    phase = TimerPhase.running;
    _lastFade = 1.0;
    Analytics.instance.log('timer_start', {'type': timerType.name, 'minutes': duration.inMinutes});
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) => _onTick(onRestNotify));
    notifyListeners();
    return null;
  }

  /// E-08 替换：取消旧计时后启动新计时
  Future<void> replace({
    required TimerType timerType,
    required Duration duration,
    VoidCallback? onRestNotify,
  }) async {
    cancel(silent: true);
    await start(timerType: timerType, duration: duration, onRestNotify: onRestNotify);
  }

  /// FR-17/FR-20 取消：播放状态保持不变，无提示音
  void cancel({bool silent = false}) {
    _tick?.cancel();
    _tick = null;
    if (isRunning || phase == TimerPhase.fading) {
      phase = TimerPhase.cancelled;
      _engine.setFadeFactor(1.0); // 渐弱恢复
    }
    if (!silent) notifyListeners();
  }

  void _onTick(VoidCallback? onRestNotify) {
    final remain = remaining;
    switch (type) {
      case TimerType.sleep:
        // FR-15：最后 fadeWindow 线性渐弱至 0
        if (remain <= _fadeWindow && remain > Duration.zero) {
          phase = TimerPhase.fading;
          final f = remain.inMilliseconds / _fadeWindow.inMilliseconds;
          if ((f - _lastFade).abs() > 0.01) {
            _lastFade = f;
            _engine.setFadeFactor(f);
          }
        }
        if (remain == Duration.zero) {
          _tick?.cancel();
          _tick = null;
          phase = TimerPhase.finished;
          _engine.setFadeFactor(1.0);
          // FR-16：停止全部播放，无提示音
          _playback.stopBySleepTimer();
        }
      case TimerType.rest:
        if (remain == Duration.zero) {
          _tick?.cancel();
          _tick = null;
          phase = TimerPhase.finished;
          onRestNotify?.call(); // FR-18：渐强提示音一次，不停止播放
        }
      case null:
        break;
    }
    notifyListeners();
  }

  /// FR-18 渐强提示音：3 秒 20% -> 80%，之后恢复常规音量（独立于混音输出）
  Future<void> playRestChime() async {
    final p = AudioPlayer();
    try {
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setSource(AssetSource('audio/chimes.wav'));
      const steps = 30;
      for (var i = 0; i <= steps; i++) {
        await p.setVolume(0.2 + (0.6 * i / steps)); // 20% -> 80%
        await Future.delayed(const Duration(milliseconds: 100)); // 3s 总长
      }
    } catch (_) {/* 素材异常静默（E-02 降级） */} finally {
      await p.dispose();
      _engine.setFadeFactor(1.0); // 恢复常规音量，禁止重复提醒
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }
}
