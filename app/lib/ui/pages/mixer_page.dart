/// 混音台页（FR-04~09）：播放/暂停 + 音轨卡（音量/静音/移除）+ 总音量 + 保存方案
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../audio/playback_controller.dart';
import '../../core/constants.dart';
import '../../data/models.dart';
import '../../data/preset_controller.dart';
import '../../theme/app_tokens.dart';
import '../icons/sound_glyph.dart';
import '../widgets/sound_icon.dart';

const double _kRadius = 14;

class MixerPage extends StatelessWidget {
  const MixerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pb = context.watch<PlaybackController>();
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('混音台', style: TextStyle(color: t.text, fontSize: 22, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: pb.channels.isEmpty ? null : () => _saveDialog(context),
            child: Text('保存方案',
                style: TextStyle(
                  color: pb.channels.isEmpty ? t.textSub : t.primary,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ],
      ),
      body: pb.channels.isEmpty
          ? _empty(context)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
              children: [
                _transport(context, pb),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Row(children: [
                    Container(
                      width: 3,
                      height: 13,
                      decoration: BoxDecoration(
                        color: t.primary.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('音轨 ${pb.channels.length}',
                        style: TextStyle(
                            color: t.text, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    Text('最多 $kMaxChannels 轨',
                        style: TextStyle(color: t.textSub, fontSize: 11.5)),
                  ]),
                ),
                for (final ch in pb.channels) _ChannelCard(key: ValueKey(ch.id), ch: ch),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _confirmClear(context, pb),
                    icon: Icon(Icons.delete_sweep_outlined, size: 18, color: t.textSub),
                    label: Text('清空混音', style: TextStyle(color: t.textSub, fontSize: 13)),
                  ),
                ),
              ],
            ),
    );
  }

  /// 播放控制区：主播放/暂停 + 状态 + 总音量
  Widget _transport(BuildContext context, PlaybackController pb) {
    final t = context.tokens;
    final playing = pb.isPlaying;
    final status = playing ? '播放中' : '已暂停';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kRadius + 2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(t.primary.withValues(alpha: playing ? 0.20 : 0.10), t.surface),
            t.surface,
          ],
        ),
        border: Border.all(
          color: playing ? t.primary.withValues(alpha: 0.45) : t.line,
          width: playing ? 1.4 : 1,
        ),
        boxShadow: playing
            ? [BoxShadow(color: t.primary.withValues(alpha: 0.14), blurRadius: 18, offset: const Offset(0, 6))]
            : null,
      ),
      child: Column(children: [
        Row(children: [
          _PlayButton(
            key: const ValueKey('mixer-play-toggle'),
            playing: playing,
            onTap: pb.togglePlayPause,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status,
                    style: TextStyle(color: t.text, fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text('${pb.channels.length} 轨混音 · 总音量 ${(pb.masterVolume * 100).round()}',
                    style: TextStyle(color: t.textSub, fontSize: 12)),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Icon(Icons.graphic_eq_rounded, size: 16, color: t.textSub),
          const SizedBox(width: 6),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: pb.masterVolume.clamp(0.0, 1.0),
                activeColor: t.primary,
                inactiveColor: t.surface2,
                onChanged: pb.setMasterVolume, // FR-09：0 也不停止播放
              ),
            ),
          ),
          SizedBox(
            width: 30,
            child: Text('${(pb.masterVolume * 100).round()}',
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: t.textSub,
                    fontSize: 12,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ),
        ]),
      ]),
    );
  }

  Widget _empty(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: t.line),
            ),
            child: Icon(Icons.graphic_eq, size: 32, color: t.textSub.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 16),
          Text('还没有音轨', style: TextStyle(color: t.text, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('在声音库勾选右上角方框，即可加入混音',
              textAlign: TextAlign.center, style: TextStyle(color: t.textSub, fontSize: 13)),
          const SizedBox(height: 4),
          Text('最多可叠 $kMaxChannels 轨', style: TextStyle(color: t.textSub, fontSize: 12)),
        ]),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, PlaybackController pb) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空混音'),
        content: const Text('将移除全部音轨并停止播放，是否继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ctx.tokens.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok == true) await pb.clearMix();
  }

  Future<void> _saveDialog(BuildContext context) async {
    final pb = context.read<PlaybackController>();
    final pc = context.read<PresetController>();
    final controller = TextEditingController(text: '我的方案 ${pc.custom.length + 1}');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('保存当前混音'),
        content: TextField(controller: controller, autofocus: true, maxLength: 20),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('保存')),
        ],
      ),
    );
    if (name == null) return;
    final err = await pc.saveCurrent(pb.channels, name: name);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err ?? '已保存「${name.trim()}」')));
    }
  }
}

/// 主播放/暂停按钮（56px，主色实心 + 投影）
class _PlayButton extends StatelessWidget {
  final bool playing;
  final VoidCallback onTap;
  const _PlayButton({super.key, required this.playing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: t.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: t.primary.withValues(alpha: 0.32),
                blurRadius: 16,
                offset: const Offset(0, 5)),
          ],
        ),
        child: Icon(
          playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 30,
          color: t.bg,
        ),
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  final Channel ch;
  const _ChannelCard({super.key, required this.ch});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pb = context.read<PlaybackController>();
    final source = soundById(ch.sourceId);
    final tint = soundTint(source?.colorIndex ?? 6);
    final playing = pb.isPlaying && !ch.muted;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 11, 10, 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(tint.withValues(alpha: ch.muted ? 0.10 : 0.30), t.surface),
            t.surface,
          ],
          stops: const [0.0, 0.9],
        ),
        border: Border.all(
          color: playing ? t.primary.withValues(alpha: 0.28) : t.line,
        ),
      ),
      child: Column(children: [
        Row(children: [
          // 图标：音源淡色 + 圆角（与声音库卡片同语言，圆角收小到 11）
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Color.alphaBlend(tint.withValues(alpha: 0.36), t.surface2),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: tint.withValues(alpha: 0.40)),
            ),
            alignment: Alignment.center,
            child: SoundGlyph(
              ch.sourceId,
              size: 22,
              color: ch.muted ? t.textSub : t.text.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(source?.name ?? ch.sourceId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: ch.muted ? t.textSub : t.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(ch.muted ? '已静音' : '音量 ${ch.volume}',
                    style: TextStyle(color: t.textSub, fontSize: 11.5)),
              ],
            ),
          ),
          // 静音（FR-06）
          _IconAction(
            icon: ch.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            tooltip: ch.muted ? '取消静音' : '静音',
            active: ch.muted,
            onTap: () => pb.toggleMute(ch),
          ),
          _IconAction(
            icon: Icons.close_rounded,
            tooltip: '移除',
            onTap: () => pb.removeChannel(ch),
          ),
        ]),
        Row(children: [
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                // FR-05：0-100 独立音量（必须显式给 max，否则默认 1.0 触发断言）
                value: ch.volume.toDouble().clamp(0.0, 100.0),
                min: 0,
                max: 100,
                divisions: 100,
                label: '${ch.volume}',
                activeColor: ch.muted ? t.textSub : t.primary,
                inactiveColor: t.surface2,
                onChanged: (v) => pb.setChannelVolume(ch, v.round()),
              ),
            ),
          ),
          Container(
            width: 34,
            padding: const EdgeInsets.symmetric(vertical: 3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.surface2.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${ch.volume}',
                style: TextStyle(
                    color: t.textSub,
                    fontSize: 11.5,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ),
        ]),
      ]),
    );
  }
}

/// 小方角图标按钮（34px 触控区 / 30px 视觉）
class _IconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Center(
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: active ? t.primary.withValues(alpha: 0.16) : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon,
                  size: 18, color: active ? t.primary : t.textSub),
            ),
          ),
        ),
      ),
    );
  }
}
