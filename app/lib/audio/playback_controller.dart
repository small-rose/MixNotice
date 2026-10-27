/// 播放控制器：状态机（PRD 9.1）+ 混音业务（FR-03~09, FR-10）
/// 状态单向：idle <-> playing <-> paused；禁止 paused -> idle 隐性迁移。
library;

import 'package:flutter/foundation.dart';

import '../core/analytics.dart';
import '../core/constants.dart';
import '../data/models.dart';
import 'audio_engine.dart';

enum PlaybackState { idle, playing, paused }

class PlaybackController extends ChangeNotifier {
  PlaybackController(this._engine) {
    _engine.channelLookup = (id) {
      for (final c in channels) {
        if (c.id == id) return c;
      }
      return null;
    };
  }

  final AudioEngine _engine;
  AudioEngine get engine => _engine;
  final List<Channel> channels = [];
  double masterVolume = 0.8; // 0-1
  PlaybackState state = PlaybackState.idle;
  DateTime? _sessionStart;

  /// 正在试听的音源 ID（null = 无试听）。供声音库卡片渲染试听描边态。
  String? previewingSourceId;

  bool get isPlaying => state == PlaybackState.playing;
  bool get isPaused => state == PlaybackState.paused;
  bool get isBusy => state != PlaybackState.idle; // 混音非空或播放中

  /// 该音源是否已在混音中（幂等判定 + 卡片「已加入」态）
  bool containsSource(String sourceId) => channels.any((c) => c.sourceId == sourceId);

  // ---- FR-03 加入混音（幂等 + 上限 6 轨）----
  /// 同一音源重复加入为幂等操作：不新增音轨，返回提示文案（用于 SnackBar）。
  Future<String?> addSource(String sourceId, {bool autoPlay = true}) async {
    final sound = soundById(sourceId);
    if (sound == null) return '未知音源';

    // 幂等：已存在则直接返回，不产生第二条音轨（同一音源不叠加播放）
    if (containsSource(sourceId)) {
      return '「${sound.name}」已在混音中，可在混音台调整音量';
    }
    if (channels.length >= kMaxChannels) {
      return '最多 $kMaxChannels 轨，请先移除一条音轨'; // FR-03
    }

    final ch = Channel(
      id: _newChannelId(sourceId),
      sourceId: sourceId,
    );
    channels.add(ch);
    if (autoPlay) {
      if (state == PlaybackState.idle) {
        _sessionStart = DateTime.now();
        state = PlaybackState.playing;
        Analytics.instance.log('session_play_start', {'channels': channels.length, 'fromPreset': false});
      }
      if (state == PlaybackState.playing) await _guarded(_engine.addChannel(ch));
    }
    Analytics.instance.log('track_add', {'sourceId': sourceId, 'channels': channels.length});
    notifyListeners();
    return null;
  }

  // ---- FR-05 独立音量 / FR-06 静音 / FR-07 移除 ----
  Future<void> setChannelVolume(Channel ch, int volume) async {
    ch.volume = volume.clamp(0, 100);
    await _guarded(_engine.updateChannel(ch));
    notifyListeners();
  }

  Future<void> toggleMute(Channel ch) async {
    ch.muted = !ch.muted;
    await _guarded(_engine.updateChannel(ch));
    notifyListeners();
  }

  Future<void> removeChannel(Channel ch) async {
    channels.remove(ch);
    await _guarded(_engine.removeChannel(ch.id));
    // 剩 0 轨时引擎已无实例，状态归为显式清空（PRD 9.1）
    if (channels.isEmpty) {
      state = PlaybackState.idle;
      _endSession('manual');
    }
    notifyListeners();
  }

  /// 按音源移除对应音轨（声音库卡片取消勾选 / 已加入态反选）
  Future<void> removeSource(String sourceId) async {
    final i = channels.indexWhere((c) => c.sourceId == sourceId);
    if (i < 0) return;
    await removeChannel(channels[i]);
  }

  /// 播放/暂停切换（混音台主按钮、通知栏与锁屏控制共用同一入口）
  Future<void> togglePlayPause() async {
    if (state == PlaybackState.playing) {
      await pause();
    } else {
      await ensurePlaying();
    }
  }

  /// 确保处于播放态（通知栏「播放」按钮 / 耳机按键调用；idle 且有音轨时重新起播）
  Future<void> ensurePlaying() async {
    if (state == PlaybackState.playing || channels.isEmpty) return;
    if (state == PlaybackState.paused) {
      await resume();
      return;
    }
    state = PlaybackState.playing;
    _sessionStart ??= DateTime.now();
    await _guarded(_ensureInstances());
    await _guarded(_engine.resumeAll());
    notifyListeners();
  }

  Future<void> clearMix() async {
    channels.clear();
    await _guarded(_engine.stopAll());
    state = PlaybackState.idle;
    _endSession('manual');
    notifyListeners();
  }

  // ---- FR-09 总音量：0 不停止播放 ----
  Future<void> setMasterVolume(double v) async {
    masterVolume = v.clamp(0.0, 1.0);
    _engine.setMaster(masterVolume);
    notifyListeners();
  }

  // ---- 播放/暂停/恢复 ----
  Future<void> pause() async {
    if (state != PlaybackState.playing) return;
    state = PlaybackState.paused;
    await _guarded(_engine.pauseAll());
    await stopPreview();
    notifyListeners();
  }

  Future<void> resume() async {
    if (state != PlaybackState.paused) return;
    if (channels.isEmpty) return; // 恢复必须校验混音非空（PRD 9.1）
    state = PlaybackState.playing;
    await _guarded(_ensureInstances());
    await _guarded(_engine.resumeAll());
    notifyListeners();
  }

  Future<void> stopAll() async {
    channels.clear();
    await _guarded(_engine.stopAll());
    state = PlaybackState.idle;
    _endSession('manual');
    notifyListeners();
  }

  /// 载入方案（FR-10）：替换当前混音并播放
  Future<void> loadPreset(PresetData preset) async {
    channels.clear();
    await _guarded(_engine.stopAll());
    final seen = <String>{};
    for (final c in preset.channels) {
      // 方案数据兜底去重：同一音源只保留首条（防历史脏数据产生重复音轨）
      if (!seen.add(c.sourceId)) continue;
      channels.add(Channel(
        id: _newChannelId(c.sourceId),
        sourceId: c.sourceId,
        volume: c.volume,
        muted: false,
      ));
    }
    state = PlaybackState.playing;
    if (_sessionStart == null) {
      _sessionStart = DateTime.now();
      Analytics.instance.log('session_play_start', {'channels': channels.length, 'fromPreset': true});
    }
    await _guarded(_ensureInstances());
    if (preset.builtin) {
      Analytics.instance.log('preset_use', {'presetId': preset.id});
    }
    notifyListeners();
  }

  /// 供暂停后再次播放 / 状态恢复时补建实例（pause 不销毁实例，stopAll 会）
  Future<void> _ensureInstances() async {
    for (final ch in channels) {
      if (!_engine.hasInstance(ch.id)) await _engine.addChannel(ch);
    }
  }

  // ---- 试听（FR-02）----
  Future<void> togglePreview(String sourceId) async {
    if (previewingSourceId == sourceId) {
      await stopPreview();
    } else {
      try {
        await _engine.startPreview(sourceId);
        previewingSourceId = sourceId;
      } catch (e) {
        // 插件通道异常不击穿 UI（真机音频设备占用等场景）
        Analytics.instance.log('engine_error', {'op': 'startPreview', 'error': '$e'});
      }
    }
    notifyListeners();
  }

  Future<void> stopPreview() async {
    previewingSourceId = null;
    await _guarded(_engine.stopPreview());
    notifyListeners();
  }

  // ---- 渐弱结束（睡眠倒计时归零，FR-16）----
  Future<void> stopBySleepTimer() async {
    channels.clear();
    await _guarded(_engine.stopAll());
    state = PlaybackState.idle;
    _endSession('sleep_fade');
    notifyListeners();
  }

  /// 引擎调用兜底：插件通道异常（设备占用/初始化失败等）记录埋点而不击穿 UI
  Future<void> _guarded(Future<void> f) async {
    try {
      await f;
    } catch (e) {
      Analytics.instance.log('engine_error', {'error': '$e'});
    }
  }

  /// 通道 ID 唯一：时间戳 + 序号，避免同一毫秒内多次添加产生重复 ID
  static int _seq = 0;
  String _newChannelId(String sourceId) =>
      'ch_${DateTime.now().microsecondsSinceEpoch}_${_seq++}_$sourceId';

  void _endSession(String endType) {
    final start = _sessionStart;
    _sessionStart = null;
    if (start != null) {
      Analytics.instance.log('session_play_end', {
        'durationSec': DateTime.now().difference(start).inSeconds,
        'endType': endType,
      });
    }
  }
}
