/// 计时器页（FR-14~20）：睡眠/休息双模式、四档 + 自定义、环形进度运行态
/// E-01 空混音启动倒计时 → 提示自动播放联动方案；E-08 冲突 → 替换/取消。
/// UI 依据设计稿 v1.2：环形进度 + 模式胶囊 + 档位胶囊 + 主色大按钮 + 联动方案行。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../audio/playback_controller.dart';
import '../../audio/timer_controller.dart';
import '../../data/preset_controller.dart';
import '../../data/settings_repository.dart';
import '../../theme/app_tokens.dart';
import '../widgets/mixer_entry.dart';
import '../widgets/settings_entry.dart';

class TimerPage extends StatefulWidget {
  const TimerPage({super.key});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  TimerType _mode = TimerType.sleep;
  int _selected = 30; // 当前选中档位（分钟），切换模式时重置为该模式常用档

  static const _sleepDurations = [15, 30, 45, 60];
  static const _restDurations = [5, 10, 15, 20];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final timer = context.watch<TimerController>();
    final durations = _mode == TimerType.sleep ? _sleepDurations : _restDurations;
    final accent = _mode == TimerType.sleep ? t.amber : t.teal; // 模式色（设计稿 v1.1）

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('计时器', style: TextStyle(color: t.text, fontSize: 22, fontWeight: FontWeight.w600)),
        actions: const [MixerEntryButton(), SettingsEntryButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          // ---- 模式切换（设计稿：左上两枚胶囊）----
          Row(mainAxisSize: MainAxisSize.min, children: [
            for (final m in TimerType.values) ...[
              _ModePill(
                label: m == TimerType.sleep ? '睡眠' : '休息',
                selected: _mode == m,
                accent: m == TimerType.sleep ? t.amber : t.teal,
                onTap: timer.isRunning ? null : () => setState(() {
                  _mode = m;
                  _selected = m == TimerType.sleep ? 30 : 5;
                }),
              ),
              if (m == TimerType.sleep) const SizedBox(width: 10),
            ],
          ]),
          const SizedBox(height: 20),
          // ---- 环形进度 + 剩余/选定时间 ----
          Center(
            child: _RingTimer(
              accent: accent,
              track: t.surface2,
              progress: timer.isRunning ? timer.progress.clamp(0.0, 1.0) : 0.94,
              timeText: _ringTime(timer, durations),
              label: _ringLabel(timer),
            ),
          ),
          const SizedBox(height: 24),
          if (timer.isRunning) ...[
            // 运行态：只保留取消（FR-17/20 播放继续、无提示音）
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                backgroundColor: t.surface,
                foregroundColor: t.text,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => timer.cancel(),
              child: const Text('取消倒计时', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ] else ...[
            // ---- 档位胶囊（单行横滑，窄屏不换行）----
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(children: [
                for (final d in durations) ...[
                  _DurationPill(
                    label: '$d',
                    selected: _selected == d,
                    accent: accent,
                    onTap: () => setState(() => _selected = d),
                  ),
                  const SizedBox(width: 10),
                ],
                _DurationPill(
                  label: '自定义',
                  selected: false,
                  accent: accent,
                  onTap: () => _customDialog(context),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            // ---- 主色大按钮 ----
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                backgroundColor: t.primary,
                foregroundColor: t.bg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => _launch(context, Duration(minutes: _selected)),
              child: Text(
                _mode == TimerType.sleep ? '启动睡眠倒计时' : '启动休息倒计时',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1),
              ),
            ),
            const SizedBox(height: 16),
            // ---- 联动方案行 + 说明（一张卡）----
            _LinkedPresetCard(mode: _mode, onPick: () => _pickLinkedPreset(context)),
          ],
        ],
      ),
    );
  }

  // ---- 环内文案 ----
  String _ringTime(TimerController timer, List<int> durations) {
    if (timer.isRunning) {
      final r = timer.remaining;
      return '${r.inMinutes.toString().padLeft(2, '0')}:${(r.inSeconds % 60).toString().padLeft(2, '0')}';
    }
    return '${_selected.toString().padLeft(2, '0')}:00';
  }

  String _ringLabel(TimerController timer) {
    if (!timer.isRunning) return _mode == TimerType.sleep ? '睡眠 渐弱' : '休息中';
    if (timer.phase == TimerPhase.fading) return '渐弱中';
    return _mode == TimerType.sleep ? '睡眠渐弱' : '休息中';
  }

  /// 自定义时长输入（E-11：非法输入标红提示，禁止提交）；确认后仅选中不直接启动
  Future<void> _customDialog(BuildContext context) async {
    final max = _mode == TimerType.sleep ? 480 : 60;
    final controller = TextEditingController();
    String? error;
    final minutes = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('自定义时长（1-$max 分钟）'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(errorText: error, hintText: '分钟'),
            onChanged: (v) => setState(() => error = _validate(v, max)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: error != null || controller.text.isEmpty
                  ? null
                  : () => Navigator.pop(ctx, int.parse(controller.text)),
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
    if (minutes != null && mounted) setState(() => _selected = minutes);
  }

  /// 联动方案选择：睡眠 → 启动默认方案（FR-25）；休息 → 休息联动方案（FR-19）
  Future<void> _pickLinkedPreset(BuildContext context) async {
    final pc = context.read<PresetController>();
    final settings = context.read<AppSettings>();
    final current =
        _mode == TimerType.sleep ? settings.defaultPresetId : settings.restLinkedPresetId;
    final id = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(_mode == TimerType.sleep ? '选择启动默认方案' : '选择休息联动方案'),
        children: [
          for (final p in pc.presets)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, p.id),
              child: Row(children: [
                Icon(
                  p.id == current ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 18,
                  color: p.id == current ? context.tokens.primary : context.tokens.textSub,
                ),
                const SizedBox(width: 10),
                Text(p.name, style: TextStyle(color: context.tokens.text, fontSize: 14)),
              ]),
            ),
        ],
      ),
    );
    if (id == null) return;
    if (_mode == TimerType.sleep) {
      settings.defaultPresetId = id;
    } else {
      settings.restLinkedPresetId = id;
    }
    await context.read<SettingsRepository>().save(settings);
    settings.notifyChanged();
  }

  String? _validate(String input, int max) {
    final v = int.tryParse(input);
    if (v == null || v.toString() != input.trim()) return '请输入整数';
    if (v < 1 || v > max) return '允许范围 1-$max 分钟';
    return null;
  }

  /// 启动入口：E-01 空混音提示 / E-08 冲突弹窗（替换或取消）
  Future<void> _launch(BuildContext context, Duration duration) async {
    final pb = context.read<PlaybackController>();
    final timer = context.read<TimerController>();
    final settings = context.read<AppSettings>();

    if (!pb.isBusy || pb.channels.isEmpty) {
      // E-01：空混音 → 提示自动播放联动方案
      final play = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('当前未在播放'),
          content: const Text('是否自动播放联动方案后启动倒计时？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('自动播放')),
          ],
        ),
      );
      if (play != true) return;
      final presetId =
          _mode == TimerType.sleep ? settings.defaultPresetId : settings.restLinkedPresetId;
      final pc = context.read<PresetController>();
      final preset = pc.presets.where((p) => p.id == presetId).firstOrNull;
      if (preset == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('尚未设置联动方案，请先点击下方「联动方案」选择')));
        }
        return;
      }
      await pb.loadPreset(preset);
    }

    final conflict = await timer.start(timerType: _mode, duration: duration,
        onRestNotify: () => timer.playRestChime());
    if (conflict != null && context.mounted) {
      // E-08：已有计时进行中 → 替换 / 取消
      final replace = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('已有计时进行中'),
          content: const Text('是否取消旧倒计时并启动新的？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('替换')),
          ],
        ),
      );
      if (replace == true) {
        await timer.replace(timerType: _mode, duration: duration,
            onRestNotify: () => timer.playRestChime());
      }
    }
    if (context.mounted) setState(() {});
  }
}

// ================= 视觉组件 =================

/// 模式胶囊（设计稿 1.x：睡眠=琥珀 / 休息=青碧）
class _ModePill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback? onTap;
  const _ModePill({required this.label, required this.selected, required this.accent, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? accent : t.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? accent : t.line),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? t.bg : t.textSub,
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              height: 1.0,
            )),
      ),
    );
  }
}

/// 档位胶囊
class _DurationPill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  const _DurationPill({required this.label, required this.selected, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accent : t.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? accent : t.line),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? t.bg : t.textSub,
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              height: 1.0,
            )),
      ),
    );
  }
}

/// 环形进度（闲置时为装饰性接近满环，运行时按剩余时间推进）
class _RingTimer extends StatelessWidget {
  final Color accent;
  final Color track;
  final double progress; // 0~1，已流逝
  final String timeText;
  final String label;
  const _RingTimer({
    required this.accent,
    required this.track,
    required this.progress,
    required this.timeText,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      width: 236,
      height: 236,
      child: CustomPaint(
        painter: _RingPainter(accent: accent, track: track, progress: progress),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(timeText,
                style: TextStyle(
                    fontSize: 54, fontWeight: FontWeight.w300, color: t.text, height: 1.1,
                    letterSpacing: 1)),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12, letterSpacing: 2, color: accent, fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final Color accent;
  final Color track;
  final double progress;
  const _RingPainter({required this.accent, required this.track, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 5.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - stroke;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 轨道
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );

    // 进度弧：圆头，自 12 点方向顺时针；进度环与轨道端部留出圆头半径的间隙更精致
    const gap = 2 * math.pi * 0.012; // 装饰性小缺口（设计稿端部留白）
    final sweep = 2 * math.pi * progress;
    if (sweep <= gap * 2) return;
    canvas.drawArc(
      rect,
      -math.pi / 2 + gap,
      sweep - gap * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = accent,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.accent != accent || old.track != track;
}

/// 联动方案卡（设计稿：方案名 + 说明文案同卡）
class _LinkedPresetCard extends StatelessWidget {
  final TimerType mode;
  final VoidCallback onPick;
  const _LinkedPresetCard({required this.mode, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pc = context.watch<PresetController>();
    final settings = context.watch<AppSettings>();
    final id = mode == TimerType.sleep ? settings.defaultPresetId : settings.restLinkedPresetId;
    String? name;
    for (final p in pc.presets) {
      if (p.id == id) name = p.name;
    }
    final label = mode == TimerType.sleep ? '启动默认方案' : '休息联动方案';
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          onTap: onPick,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
            child: Row(children: [
              Text(label,
                  style: TextStyle(color: t.textSub, fontSize: 13.5)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(name ?? '未设置',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: t.text, fontSize: 14.5, fontWeight: FontWeight.w600)),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: t.textSub),
            ]),
          ),
        ),
        Divider(height: 1, thickness: 1, color: t.line, indent: 16, endIndent: 16),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 11, 16, 13),
          child: Text(
            mode == TimerType.sleep
                ? '结束前 5 分钟音量渐弱至静音，不发出提示音'
                : '到点轻声渐强提醒一次，不停止播放',
            style: TextStyle(color: t.textSub, fontSize: 12.5, height: 1.5),
          ),
        ),
      ]),
    );
  }
}
