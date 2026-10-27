/// 迷你播放条（设计稿 5.x）：堆叠音轨图标 + 轨数摘要 + 播放/暂停，点击进混音台
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../audio/playback_controller.dart';
import '../../core/constants.dart';
import '../../theme/app_tokens.dart';
import '../icons/sound_glyph.dart';
import 'level_bars.dart';
import 'sound_icon.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pb = context.watch<PlaybackController>();
    if (pb.channels.isEmpty) return const SizedBox.shrink();

    final playing = pb.isPlaying;
    final first = pb.channels.first.sourceId;
    final tint = soundTint(soundById(first)?.colorIndex ?? 6);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            // 底色随首轨音源淡色轻微着色，与声音库卡片同一语言
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(tint.withValues(alpha: 0.26), t.surface2),
                t.surface,
              ],
            ),
            border: Border.all(color: t.line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            onTap: () => Navigator.of(context).pushNamed('/mixer'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 10, 7),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // 顶部把手：暗示「上滑/点击进混音台」
                Container(
                  width: 30,
                  height: 3,
                  decoration: BoxDecoration(
                    color: t.textSub.withValues(alpha: 0.38),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  _MixBadge(pb),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _title(pb),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: t.text, fontSize: 14, fontWeight: FontWeight.w600, height: 1.2),
                        ),
                        const SizedBox(height: 3),
                        Row(children: [
                          LevelBars(color: t.primary, active: playing, height: 12),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              '${pb.channels.length} 轨 · ${playing ? '播放中' : '已暂停'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: t.textSub, fontSize: 11.5, height: 1.2),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _PlayButton(
                    playing: playing,
                    primary: t.primary,
                    onBg: t.bg,
                    onTap: () => playing ? pb.pause() : pb.resume(),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  String _title(PlaybackController pb) {
    final names = pb.channels.take(2).map((c) => soundById(c.sourceId)?.name ?? '未知').join(' + ');
    return pb.channels.length > 2 ? '$names 等' : names;
  }
}

/// 混音缩略块：1 轨显示单图标，2 轨并排，3-4 轨显示 2×2 小图标拼块
/// （比「图标堆叠」更清晰：不重叠、不切边，一眼看出是几条声音叠起来的）
class _MixBadge extends StatelessWidget {
  final PlaybackController pb;
  const _MixBadge(this.pb);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ids = pb.channels.take(4).map((c) => c.sourceId).toList();
    final tint = soundTint(soundById(ids.first)?.colorIndex ?? 6);
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(tint.withValues(alpha: 0.55), t.surface2),
            Color.alphaBlend(tint.withValues(alpha: 0.16), t.surface2),
          ],
        ),
        border: Border.all(color: t.line),
      ),
      child: ids.length == 1
          ? SoundGlyph(ids.first, size: 24, color: t.text.withValues(alpha: 0.92))
          : _glyphGrid(t, ids),
    );
  }

  Widget _glyphGrid(AppTokens t, List<String> ids) {
    Widget cell(String id) => SoundGlyph(id, size: 13, color: t.text.withValues(alpha: 0.9));
    final rows = ids.length <= 2
        ? [ids]
        : [ids.sublist(0, 2), ids.sublist(2, ids.length)];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var j = 0; j < rows[i].length; j++) ...[
                if (j > 0) const SizedBox(width: 4),
                cell(rows[i][j]),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _PlayButton extends StatelessWidget {
  final bool playing;
  final Color primary;
  final Color onBg;
  final VoidCallback onTap;
  const _PlayButton({required this.playing, required this.primary, required this.onBg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: primary,
          borderRadius: BorderRadius.circular(21),
          boxShadow: [
            BoxShadow(color: primary.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 3)),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 24, color: onBg),
      ),
    );
  }
}
