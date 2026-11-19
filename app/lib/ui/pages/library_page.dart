/// 声音库页（FR-01~03）：三组展示、试听、加入混音（幂等）
/// v1.3：分组导航改为筛选胶囊（全部/自然/田园/噪音/生活，点选只显示该组）
///       + 卡片三态（默认/已加入/播放中，试听单独标注）+ 状态副行 + 新增徽标 + 晕染降淡
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

/// 卡片高度 116：顶部行(图标/徽标/勾选) + 名称/状态副行/试听 + 播放态循环进度条。
const double _kCardHeight = 116;
const double _kCardMaxWidth = 190;

/// 卡片圆角（用户反馈 20 过于圆润，收到 14）
const double _kCardRadius = 14;
const double _kInnerRadius = 12;

/// 混音/试听循环进度环的周期（秒）：表现层装饰，对应主流音源 60s 级循环
const int _kLoopSeconds = 60;

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  /// 当前筛选分组；null = 全部
  String? _selected;

  @override
  void initState() {
    super.initState();
  }

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
      // 分组筛选导航：点选只显示该组，「全部」恢复完整列表
      body: Column(children: [
        _GroupNav(selected: _selected, onTap: (g) => setState(() => _selected = g)),
        Expanded(
          child: ListView(
            padding: EdgeInsets.only(bottom: bottomInset),
            children: kSoundGroups.entries
                .where((g) => _selected == null || g.key == _selected)
                .map((g) => _group(context, g.key, g.value, pb))
                .toList(),
          ),
        ),
      ]),
    );
  }

  Widget _group(BuildContext context, String key, String label, PlaybackController pb) {
    final sounds = kSounds.where((s) => s.group == key).toList();
    final t = context.tokens;
    final newCount = sounds.where((s) => kNewSourceIds.contains(s.id)).length;
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
          // 本组含新增音源时提示数量（amber ≤5% 占比规范）
          if (newCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: t.amber.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text('$newCount 个新增',
                  style: TextStyle(color: t.amber, fontSize: 11, fontWeight: FontWeight.w600, height: 1.3)),
            ),
          ],
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
          return _SoundCard(key: ValueKey('sound-${s.id}'), source: s, previewing: previewing);
        },
      ),
      const SizedBox(height: 18),
    ]);
  }
}

/// 分组筛选胶囊：全部 / 自然 / 田园 / 噪音 / 生活（点选只显示该组）
class _GroupNav extends StatelessWidget {
  final String? selected;
  final void Function(String?) onTap;
  const _GroupNav({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget chip(String? key, String label, int count) {
      final on = selected == key;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(key),
        child: Semantics(
          button: true,
          label: on ? '「$label」筛选中' : '筛选显示「$label」分组',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
            decoration: BoxDecoration(
              color: on ? t.primary : t.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: on ? t.primary : t.line),
            ),
            child: Text.rich(TextSpan(children: [
              TextSpan(
                text: label,
                style: TextStyle(
                  color: on ? t.bg : t.textSub,
                  fontSize: 12.5,
                  fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              TextSpan(
                text: ' $count',
                style: TextStyle(
                  color: on ? t.bg.withValues(alpha: 0.8) : t.textSub.withValues(alpha: 0.7),
                  fontSize: 10.5,
                ),
              ),
            ])),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
      child: Wrap(spacing: 7, children: [
        chip(null, '全部', kSounds.length),
        for (final e in kSoundGroups.entries)
          chip(e.key, e.value, kSounds.where((s) => s.group == e.key).length),
      ]),
    );
  }
}

/// 卡片三态：
///   默认（灰边）→ 已加入（实心 ✓，主色 45% 描边）→ 播放中（主色描边 + 底部循环进度条）
/// 试听中复用播放中的描边与进度条，副行文案标明「试听中」。
class _SoundCard extends StatefulWidget {
  final SoundSource source;
  final bool previewing;
  const _SoundCard({super.key, required this.source, required this.previewing});

  @override
  State<_SoundCard> createState() => _SoundCardState();
}

class _SoundCardState extends State<_SoundCard> with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: _kLoopSeconds),
    value: 0,
  );

  @override
  void initState() {
    super.initState();
    // 进入页面时可能已在播放（从其他页返回），首帧同步一次动画状态
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncLoop());
  }

  void _syncLoop() {
    if (!mounted) return;
    final pb = context.read<PlaybackController>();
    final animate =
        (pb.containsSource(widget.source.id) && pb.isPlaying) || widget.previewing;
    if (animate && !_loop.isAnimating) {
      _loop.repeat();
    } else if (!animate && _loop.isAnimating) {
      _loop.stop();
    }
  }

  @override
  void didUpdateWidget(_SoundCard old) {
    super.didUpdateWidget(old);
    _syncLoop();
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  Future<void> _toggle(BuildContext context, PlaybackController pb, bool inMix, bool previewing) async {
    if (inMix) {
      await pb.removeSource(widget.source.id);
      if (context.mounted) _toast(context, '已从混音台移除「${widget.source.name}」');
      return;
    }
    if (previewing) await pb.stopPreview(); // 加入前先停试听，避免同源双声
    final err = await pb.addSource(widget.source.id);
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

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pb = context.watch<PlaybackController>();
    final source = widget.source;
    final previewing = widget.previewing;
    final inMix = pb.containsSource(source.id);
    final tint = soundTint(source.colorIndex);
    final active = inMix && pb.isPlaying; // 真正发声中（试听另标文案）
    final isNew = kNewSourceIds.contains(source.id);
    final looping = active || previewing;

    // 卡面：左上角径向晕染（0.30 → 0.22），四条边视觉均匀，不再出现"半张卡"割裂
    final wash = Color.alphaBlend(tint.withValues(alpha: 0.22), t.surface);

    final child = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(_kCardRadius),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_kCardRadius),
          gradient: RadialGradient(
            center: const Alignment(-1.0, -1.1),
            radius: 1.55,
            colors: [wash, Color.alphaBlend(tint.withValues(alpha: 0.04), t.surface), t.surface],
            stops: const [0.0, 0.62, 1.0],
          ),
          border: Border.all(
            color: looping
                ? t.primary.withValues(alpha: 0.65)
                : (inMix ? t.primary.withValues(alpha: 0.45) : t.line.withValues(alpha: 0.20)),
            width: looping ? 1.6 : 1,
          ),
          boxShadow: looping
              ? [BoxShadow(color: t.primary.withValues(alpha: 0.20), blurRadius: 16, offset: const Offset(0, 5))]
              : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(_kCardRadius),
          onTap: () => _toggle(context, pb, inMix, previewing),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 6, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部：图标 + (播放电平条) + 新增徽标 + 勾选
                Row(children: [
                  _GlyphTile(
                    sourceId: source.id,
                    tint: tint,
                    previewing: previewing,
                    t: t,
                  ),
                  const Spacer(),
                  if (isNew) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: t.amber,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('新增',
                          style: TextStyle(
                              color: t.bg, fontSize: 9.5, fontWeight: FontWeight.w700, height: 1.3)),
                    ),
                    const SizedBox(width: 5),
                  ],
                  if (looping) ...[
                    // 声音波浪电平条：播放中 / 试听中都跳动（v1.1 恢复）
                    LevelBars(color: t.primary, active: true, height: 12),
                    const SizedBox(width: 6),
                  ],
                  // 勾选 = 加入混音台；再点一次取消（移除音轨）
                  _CheckToggle(
                    key: ValueKey('mix-toggle-${source.id}'),
                    checked: inMix,
                    onTap: () => _toggle(context, pb, inMix, previewing),
                    label: inMix ? '从混音台移除「${source.name}」' : '将「${source.name}」加入混音台',
                  ),
                ]),
                const Spacer(),
                // 底部：名称 + 状态副行，与试听钮对齐
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            source.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: t.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _subtitle(inMix, active, previewing, pb),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: t.textSub, fontSize: 10.5, height: 1.25),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    _PreviewButton(
                      onTap: () => pb.togglePreview(source.id),
                      active: previewing,
                      t: t,
                      label: previewing ? '停止试听「${source.name}」' : '试听「${source.name}」',
                    ),
                  ],
                ),
                // 底部循环进度条：仅在发声/试听时显示
                if (looping) ...[
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: SizedBox(
                      height: 2.5,
                      child: Stack(children: [
                        Container(color: t.surface2),
                        AnimatedBuilder(
                          animation: _loop,
                          builder: (_, __) => FractionallySizedBox(
                            widthFactor: _loop.isAnimating ? _loop.value : 0,
                            child: Container(color: t.primary),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return child;
  }

  /// 状态副行：试听中 > 播放中 > 已加入混音 > 音源描述
  String _subtitle(bool inMix, bool active, bool previewing, PlaybackController pb) {
    if (previewing) return '试听中';
    if (active) return '播放中';
    if (inMix) return pb.isPlaying ? '播放中' : '已加入混音';
    return kSoundDesc[widget.source.id] ?? '';
  }
}

/// 音源图标块（播放态由卡片描边 + 底部循环进度条表达，图标本身不加环）
class _GlyphTile extends StatelessWidget {
  final String sourceId;
  final Color tint;
  final bool previewing;
  final AppTokens t;
  const _GlyphTile({
    required this.sourceId,
    required this.tint,
    required this.previewing,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
        sourceId,
        color: previewing ? t.primary : t.text.withValues(alpha: 0.90),
        size: 24,
      ),
    );
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
