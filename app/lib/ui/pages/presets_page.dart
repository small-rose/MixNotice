/// 方案库页（FR-10~13）：预设一键载入；自定义保存/重命名/删除（删除二次确认）
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../audio/playback_controller.dart';
import '../../core/constants.dart';
import '../../data/models.dart';
import '../../data/preset_controller.dart';
import '../../theme/app_tokens.dart';
import '../widgets/mixer_entry.dart';
import '../widgets/settings_entry.dart';
import '../widgets/sound_icon.dart';

class PresetsPage extends StatelessWidget {
  const PresetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pc = context.watch<PresetController>();
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('方案库', style: TextStyle(color: t.text, fontSize: 22, fontWeight: FontWeight.w600)),
        actions: const [MixerEntryButton(), SettingsEntryButton()],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
        _sectionTitle(context, '预设方案', '${pc.builtin.length} 个'),
        for (final p in pc.builtin) _PresetCard(preset: p),
        const SizedBox(height: 8),
        _sectionTitle(context, '我的方案', '${pc.custom.length} / 20'),
        if (pc.custom.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('在混音台保存当前混音即可创建', style: TextStyle(color: t.textSub, fontSize: 13))),
          ),
        for (final p in pc.custom)
          _PresetCard(preset: p, onRename: () => _rename(context, p), onDelete: () => _delete(context, p)),
      ]),
    );
  }

  Widget _sectionTitle(BuildContext context, String label, String count) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const Spacer(),
        Text(count, style: TextStyle(color: t.textSub, fontSize: 13)),
      ]),
    );
  }

  Future<void> _rename(BuildContext context, PresetData p) async {
    final pc = context.read<PresetController>();
    final controller = TextEditingController(text: p.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(controller: controller, autofocus: true, maxLength: 20),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('确定')),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    final err = await pc.rename(p, name);
    if (context.mounted && err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  /// 删除二次确认（FR-12）
  Future<void> _delete(BuildContext context, PresetData p) async {
    final pc = context.read<PresetController>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除方案'),
        content: Text('确定删除「${p.name}」？此操作不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.tokens.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final err = await pc.delete(p);
    if (context.mounted && err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }
}

class _PresetCard extends StatelessWidget {
  final PresetData preset;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  const _PresetCard({required this.preset, this.onRename, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pb = context.read<PlaybackController>();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.line),
      ),
      child: Row(children: [
        if (preset.channels.isNotEmpty)
          SoundIcon(preset.channels.first.sourceId,
              soundById(preset.channels.first.sourceId)?.colorIndex ?? 6, size: 56),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(preset.name,
                style: TextStyle(color: t.text, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              preset.channels
                  .map((c) => '${soundById(c.sourceId)?.name ?? c.sourceId} ${c.volume}')
                  .join(' · '),
              style: TextStyle(color: t.textSub, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
        if (!preset.builtin) ...[
          IconButton(icon: Icon(Icons.edit_outlined, size: 20, color: t.textSub), onPressed: onRename),
          IconButton(icon: Icon(Icons.delete_outline, size: 20, color: t.textSub), onPressed: onDelete),
        ],
        // FR-10 一键载入：替换混音并播放
        IconButton.filled(
          style: IconButton.styleFrom(backgroundColor: t.primary, foregroundColor: t.bg),
          onPressed: () => pb.loadPreset(preset),
          icon: const Icon(Icons.play_arrow, size: 22),
        ),
      ]),
    );
  }
}
