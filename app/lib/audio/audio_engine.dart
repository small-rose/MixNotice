/// 音频引擎：多轨叠放（audioplayers 多实例）
/// FR-04~09：每轨独立音量/静音/循环；FR-09 总音量作用于最终输出且为 0 不停止播放。
library;

import 'package:audioplayers/audioplayers.dart';

import '../core/constants.dart';
import '../data/models.dart';

class AudioEngine {
  final Map<String, AudioPlayer> _players = {}; // channel.id -> player
  AudioPlayer? _preview;
  double _master = 1.0;
  double _fadeFactor = 1.0; // 睡眠渐弱系数（TimerController 驱动）

  /// 多轨共存的关键音频上下文（2026-10-26 修复「只能播放一种声音」）：
  /// audioplayers 安卓端默认 audioFocus = AUDIOFOCUS_GAIN，每个实例都独占焦点，
  /// 第二轨一播放就会让第一轨收到焦点丢失回调并 pause()。
  /// 设为 none 后各实例互不抢占，最多 6 轨可同时发声；stayAwake 兼顾息屏续播。
  static final AudioContext _multiTrackContext = AudioContext(
    android: AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: true,
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.none,
    ),
  );

  double get master => _master;

  Future<AudioPlayer> _newPlayer() async {
    final p = AudioPlayer();
    await p.setAudioContext(_multiTrackContext);
    return p;
  }

  void setMaster(double v) {
    _master = v.clamp(0.0, 1.0);
    _applyAll();
  }

  /// 睡眠渐弱：作用于全部音轨输出（FR-15），由倒计时按帧调用
  void setFadeFactor(double f) {
    _fadeFactor = f.clamp(0.0, 1.0);
    _applyAll();
  }

  Future<void> addChannel(Channel ch) async {
    final player = await _newPlayer();
    await player.setReleaseMode(ReleaseMode.loop); // 循环播放（无缝循环素材）
    await player.setSource(AssetSource(_assetRelative(ch.sourceId)));
    await player.setVolume(_gain(ch));
    await player.resume();
    _players[ch.id] = player;
  }

  Future<void> removeChannel(String channelId) async {
    final p = _players.remove(channelId);
    await p?.stop();
    await p?.dispose();
  }

  Future<void> updateChannel(Channel ch) async {
    await _players[ch.id]?.setVolume(_gain(ch));
  }

  Future<void> pauseAll() async {
    for (final p in _players.values) {
      await p.pause();
    }
  }

  Future<void> resumeAll() async {
    for (final p in _players.values) {
      await p.resume();
    }
  }

  Future<void> stopAll() async {
    for (final p in List.of(_players.values)) {
      await p.stop();
      await p.dispose();
    }
    _players.clear();
  }

  /// 试听（FR-02）：独立实例，不影响混音中的同源音轨
  Future<void> startPreview(String sourceId) async {
    await stopPreview();
    final p = await _newPlayer();
    await p.setReleaseMode(ReleaseMode.loop);
    await p.setSource(AssetSource(_assetRelative(sourceId)));
    await p.setVolume(0.5 * _master); // 默认音量 50%
    await p.resume();
    _preview = p;
  }

  Future<void> stopPreview() async {
    final p = _preview;
    _preview = null;
    await p?.stop();
    await p?.dispose();
  }

  bool get hasPreview => _preview != null;

  bool hasInstance(String channelId) => _players.containsKey(channelId);

  /// 最终音量 = 轨音量 × 总音量 × 渐弱系数；总音量为 0 不停止播放（FR-09）
  double _gain(Channel ch) => ch.effective * _master * _fadeFactor;

  void _applyAll() {
    for (final entry in _players.entries) {
      final ch = _channelOf(entry.key);
      if (ch != null) entry.value.setVolume(_gain(ch));
    }
  }

  // 由 PlaybackController 注入当前音轨状态，避免引擎持有业务模型
  Channel? Function(String channelId)? _channelLookup;
  Channel? _channelOf(String id) => _channelLookup?.call(id);
  set channelLookup(Channel? Function(String) f) => _channelLookup = f;

  String _assetRelative(String sourceId) {
    final s = soundById(sourceId);
    return s == null ? 'audio/rain-light.m4a' : s.asset.replaceFirst('assets/', '');
  }

  Future<void> dispose() async {
    await stopAll();
    await stopPreview();
  }
}
