/// 声音库页（FR-01~03）：三组展示、试听、加入混音（幂等）
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../audio/playback_controller.dart';
import '../../core/constants.dart';
import '../../theme/app_tokens.dart';
import '../icons/sound_glyph.dart';
import '../widgets/level_bars.dart';
import '../widgets/mixer_entry.dart';
import '../widgets/settings_entry.dart';
import '../widgets/sound_icon.dart';

/// 卡片高度 112：四角结构（图标/勾选/名称/试听）刚好排满，不再留中部空洞。
/// 12(上) + 44(图标) + 8(呼吸) + 30(底部行) + 10(下) = 104，余 8 作弹性。
const double _kCardHeight = 112;
const double _kCardMaxWidth = 190;

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pb = context.watch<PlaybackController>();
    // 迷你播放条悬浮于 Tab 栏上方：有音轨时给列表让出它的高度，避免最后一行被压住
    final bottomInset = pb.channels.isEmpty ? 28.0 : 104.0;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('声音库', style: TextStyle(color: t.text, fontSize: 22, fontWeight: FontWeight.w600)),
        actions: const [MixerEntryButton(), SettingsEntryButton()],
      ),
      body: ListView(
        padding: EdgeInsets.only(bottom: bottomInset),
        children: kSoundGroups.entries.map((g) => _group(context, g.key, g.value, pb)).toList(),
      ),
    );
  }

  Widget _group(BuildContext context, String key, String label, PlaybackController pb) {
    final sounds = kSounds.where((s) => s.group == key).toList();
    final t = context.tokens;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // 分组标题左缘 18 ≈ 卡片圆角视觉边缘，标题与卡片同一条视觉轴
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 20, 10),
        child: Row(children: [
          Text(label, style: TextStyle(color: t.text, fontSize: 15.5, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          // 计数胶囊：主色 10% 底，弱层级、可扫读
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: t.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text('${sounds.length}',
                style: TextStyle(color: t.primary, fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.3)),
          ),
        ]),
      ),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: _kCardMaxWidth,
          mainAxisExtent: _kCardHeight,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: sounds.length,
        itemBuilder: (context, i) {
          final s = sounds[i];
          // 试听态：只高亮真正在试听的那一个音源（含「已加入」不冲突）
          final previewing = pb.previewingSourceId == s.id;
          return _SoundCard(source: s, previewing: previewing);
        },
      ),
      const SizedBox(height: 18),
    ]);
  }
}

/// 卡片圆角（用户反馈 20 过于圆润，收到 14）
const double _kCardRadius = 14;
const double _kInnerRadius = 12;

/// 卡片四角结构：
///   左上 图标 44 ······ 右上 勾选 26（播放中则在勾选左侧显示电平条）
///   左下 名称 16 ······ 右下 试听 30 圆形钮
/// 名称与操作同基线，视线沿对角线流动，卡片不留空洞。
class _SoundCard extends StatelessWidget {
  final SoundSource source;
  final bool previewing;
  const _SoundCard({required this.source, required this.previewing});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pb = context.read<PlaybackController>();
    final inMix = pb.containsSource(source.id);
    final tint = soundTint(source.colorIndex);
    final active = inMix && pb.isPlaying;
    // 卡面：左上角径向晕染（0.30 → 卡面本色），四条边视觉均匀，不会出现"半张卡"的明暗割裂
    final wash = Color.alphaBlend(tint.withValues(alpha: 0.30), t.surface);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(_kCardRadius),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_kCardRadius),
          gradient: RadialGradient(
            center: const Alignment(-1.0, -1.1),
            radius: 1.55,
            colors: [wash, Color.alphaBlend(tint.withValues(alpha: 0.05), t.surface), t.surface],
            stops: const [0.0, 0.62, 1.0],
          ),
          border: Border.all(
            color: previewing || active
                ? t.primary.withValues(alpha: 0.65)
                : (inMix ? t.primary.withValues(alpha: 0.45) : t.line.withValues(alpha: 0.20)),
            width: previewing || active ? 1.6 : 1,
          ),
          boxShadow: previewing || active
              ? [BoxShadow(color: t.primary.withValues(alpha: 0.20), blurRadius: 16, offset: const Offset(0, 5))]
              : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(_kCardRadius),
          onTap: () => _toggle(context, pb, inMix),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 6, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部：图标 + （播放中电平条）+ 勾选
                Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(tint.withValues(alpha: 0.46), t.surface2),
                      borderRadius: BorderRadius.circular(_kInnerRadius),
                      border: Border.all(
                        color: previewing ? t.primary.withValues(alpha: 0.55) : tint.withValues(alpha: 0.50),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: SoundGlyph(
                      source.id,
                      color: previewing ? t.primary : t.text.withValues(alpha: 0.90),
                      size: 24,
                    ),
                  ),
                  const Spacer(),
                  if (active) ...[
                    LevelBars(color: t.primary, active: true, height: 12),
                    const SizedBox(width: 6),
                  ],
                  // 勾选 = 加入混音台；再点一次取消（移除音轨）
                  _CheckToggle(
                    key: ValueKey('mix-toggle-${source.id}'),
                    checked: inMix,
                    onTap: () => _toggle(context, pb, inMix),
                    label: inMix ? '从混音台移除「${source.name}」' : '将「${source.name}」加入混音台',
                  ),
                ]),
                const Spacer(),
                // 底部：名称与试听同基线
                Row(children: [
                  Expanded(
                    child: Text(
                      source.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: t.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _PreviewButton(
                    onTap: () => pb.togglePreview(source.id),
                    active: previewing,
                    t: t,
                    label: previewing ? '停止试听「${source.name}」' : '试听「${source.name}」',
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 勾选/反选：加入混音台 ↔ 从混音台移除（幂等，最多 6 轨）
  Future<void> _toggle(BuildContext context, PlaybackController pb, bool inMix) async {
    if (inMix) {
      await pb.removeSource(source.id);
      if (context.mounted) _toast(context, '已从混音台移除「${source.name}」');
      return;
    }
    if (previewing) await pb.stopPreview(); // 加入前先停试听，避免同源双声
    final err = await pb.addSource(source.id);
    if (err != null && context.mounted) _toast(context, err);
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 90),
      ));
  }
}

/// 右上角勾选：空态「+」（可加入）、选中「✓」（已在混音台），再点取消
class _CheckToggle extends StatelessWidget {
  final bool checked;
  final VoidCallback onTap;
  final String label;
  const _CheckToggle({
    super.key,
    required this.checked,
    required this.onTap,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      checked: checked,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // 视觉 26px / 触控 40px
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: checked ? t.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: checked ? t.primary : t.textSub.withValues(alpha: 0.35),
                  width: checked ? 1 : 1.3,
                ),
              ),
              child: checked
                  ? Icon(Icons.check_rounded, size: 17, color: t.bg)
                  : Icon(Icons.add_rounded, size: 16, color: t.textSub.withValues(alpha: 0.92)),
            ),
          ),
        ),
      ),
    );
  }
}

/// 圆形试听钮（播放 / 停止）：视觉 30px、触控 40px，图标即语义，读屏走 label
class _PreviewButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool active;
  final AppTokens t;
  final String label;
  const _PreviewButton({
    required this.onTap,
    required this.active,
    required this.t,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 34,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: active ? t.primary.withValues(alpha: 0.20) : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: active ? t.primary.withValues(alpha: 0.60) : t.textSub.withValues(alpha: 0.32),
                  width: active ? 1.5 : 1.2,
                ),
              ),
              child: Icon(
                active ? Icons.stop_rounded : Icons.play_arrow_rounded,
                size: 17,
                color: active ? t.primary : t.text.withValues(alpha: 0.66),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
