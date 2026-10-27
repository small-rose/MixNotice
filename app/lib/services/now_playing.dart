/// 系统级播放信息（FR-21 息屏续播 / FR-22 通知栏与锁屏控制）
///
/// 由 audio_service 提供 Android 前台服务 + MediaSession：
/// 应用退到后台/息屏后继续播放，通知栏与锁屏显示「当前混音 + 播放/暂停/停止」。
/// 音频本身仍由 audioplayers 多实例输出，这里只负责媒体会话与通知同步。
library;

import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

import '../audio/playback_controller.dart';
import '../audio/timer_controller.dart';
import '../core/analytics.dart';
import '../core/constants.dart';

/// 媒体会话回调：通知栏/耳机按键/锁屏的播放控制都落到 PlaybackController
class MixAudioHandler extends BaseAudioHandler {
  MixAudioHandler(this.pb);
  final PlaybackController pb;

  @override
  Future<void> play() => pb.ensurePlaying();

  @override
  Future<void> pause() => pb.pause();

  @override
  Future<void> stop() async {
    await pb.stopAll();
    await super.stop();
  }
}

/// 通知栏/锁屏信息桥：监听播放状态，推送到系统媒体会话
class NowPlaying {
  NowPlaying._();

  static BaseAudioHandler? _handler;
  static VoidCallback? _listener;

  /// 是否可用（桌面端无 audio_service 原生实现，直接跳过）
  static bool get isActive => _handler != null;

  static bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// 启动时调用一次。任何异常（缺插件/权限异常）都只记埋点，不影响播放。
  static Future<void> init(PlaybackController pb, TimerController timer) async {
    if (!_supported || _handler != null) return;
    try {
      final BaseAudioHandler handler = await AudioService.init(
        builder: () => MixAudioHandler(pb),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.mixnotice.mixnotice.playback',
          androidNotificationChannelName: '混音播放',
          androidNotificationChannelDescription: '在通知栏与锁屏控制 MixNotice 的混音播放',
          androidNotificationOngoing: true, // 播放中常驻，避免误划掉
          androidStopForegroundOnPause: true, // 暂停后退出前台，可划掉
          androidResumeOnClick: true,
        ),
      );
      _handler = handler;

      String? lastKey;
      void sync() {
        try {
          final key = _syncKey(pb, timer);
          if (key == lastKey) return; // 去重：拖动音量等高频通知不重复推系统
          lastKey = key;
          _push(handler, pb, timer);
        } catch (e) {
          Analytics.instance.log('now_playing_error', {'error': '$e'});
        }
      }

      _listener = sync;
      _bound = pb;
      pb.addListener(sync);
      timer.addListener(sync);
      sync();
    } catch (e) {
      Analytics.instance.log('startup_error', {'stage': 'now_playing', 'error': '$e'});
    }
  }

  /// 只让真正影响通知内容的字段参与去重
  static String _syncKey(PlaybackController pb, TimerController timer) {
    final ids = pb.channels.map((c) => c.sourceId).join(',');
    return '${pb.isPlaying}|${timer.isRunning}|${timer.type?.name}|$ids';
  }

  static void _push(BaseAudioHandler handler, PlaybackController pb, TimerController timer) {
    final names = pb.channels
        .map((c) => soundById(c.sourceId)?.name ?? c.sourceId)
        .join(' · ');
    final playing = pb.isPlaying;
    final tracks = pb.channels.length;

    final subtitle = StringBuffer('$tracks 轨');
    if (timer.isRunning && timer.type != null) {
      subtitle.write(timer.type == TimerType.sleep ? ' · 睡眠倒计时' : ' · 休息倒计时');
    }

    handler.mediaItem.add(MediaItem(
      id: 'mixnotice-mix',
      title: names.isEmpty ? 'MixNotice' : names,
      artist: subtitle.toString(),
      album: 'MixNotice',
    ));

    handler.playbackState.add(handler.playbackState.value.copyWith(
      controls: [
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
      ],
      systemActions: const {MediaAction.stop},
      androidCompactActionIndices: const [0, 1],
      processingState:
          tracks == 0 ? AudioProcessingState.idle : AudioProcessingState.ready,
      playing: playing,
      updatePosition: Duration.zero,
      bufferedPosition: Duration.zero,
      speed: 1.0,
    ));
  }

  /// 释放监听（测试/热重载用）
  static void dispose() {
    final l = _listener;
    final pb = _bound;
    if (l != null && pb != null) pb.removeListener(l);
    _bound = null;
    _listener = null;
  }

  static PlaybackController? _bound;
}
