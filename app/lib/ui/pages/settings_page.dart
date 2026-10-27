/// 设置页（FR-24~27）：音质 / 默认方案 / 休息联动方案 / 桌面自启 / 关于与授权
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/preset_controller.dart';
import '../../data/settings_repository.dart';
import '../../theme/app_themes.dart';
import '../../theme/app_tokens.dart';
import '../../theme/mtheme.dart';
import '../../theme/theme_controller.dart';
import '../icons/mixnotice_logo.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final settings = context.watch<AppSettings>();
    final pc = context.watch<PresetController>();
    final tc = context.watch<AppThemeController>();
    final isDesktop = !kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.linux);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('设置', style: TextStyle(color: t.text, fontSize: 22, fontWeight: FontWeight.w600)),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
        _appearance(context, tc),
        _section(context, '播放'),
        _row(context, '音质', _qualityLabel(settings.quality), (ctx) async {
          final q = await _pick(ctx, '音质', const {'standard': '标准（96kbps）', 'high': '高质量（128kbps）'}, settings.quality);
          if (q != null) _update(settings..quality = q); // FR-24：下次播放生效
        }),
        _row(context, '启动默认方案', _presetName(pc, settings.defaultPresetId) ?? '不自动播放', (ctx) async {
          final id = await _pickPreset(ctx, pc, settings.defaultPresetId, allowNone: true);
          if (id != null) _update(settings..defaultPresetId = id); // FR-25
        }),
        _row(context, '休息联动方案', _presetName(pc, settings.restLinkedPresetId) ?? '溪流清晨', (ctx) async {
          final id = await _pickPreset(ctx, pc, settings.restLinkedPresetId);
          if (id != null) _update(settings..restLinkedPresetId = id); // FR-19
        }),
        if (isDesktop)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('开机自启', style: TextStyle(color: t.text, fontSize: 15)),
            subtitle: Text('关闭主窗口后最小化到系统托盘', style: TextStyle(color: t.textSub, fontSize: 12)),
            value: settings.autoStart,
            activeThumbColor: t.primary,
            onChanged: (v) => _update(settings..autoStart = v), // FR-26
          ),
        _section(context, '关于'),
        // 品牌行：三叠浪标记 + 名称 + 定位语
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            // 矢量自绘：波浪取主色 token、圆点取琥珀 token，跟随四套主题与自定义强调色
            const MixNoticeLogo(size: 30),
            const SizedBox(width: 10),
            Text('MixNotice', style: TextStyle(color: t.text, fontSize: 16.5, fontWeight: FontWeight.w600, letterSpacing: -0.2)),
            const SizedBox(width: 8),
            Text('白噪音混音 · 助眠', style: TextStyle(color: t.textSub, fontSize: 12)),
          ]),
        ),
        _row(context, '版本', '1.0.0', null),
        _row(context, '作者', '残阳丹落枫', null),
        _row(context, '开源许可', '查看', (ctx) => _showLicense(ctx)),
        _row(context, '音频素材授权', '查看清单', (ctx) => _showLicenses(ctx)),
        const SizedBox(height: 12),
        Text('数据仅保存在本机，删除 App 即全部清除。',
            style: TextStyle(color: t.textSub, fontSize: 12)),
      ]),
    );
  }

  // ---- 外观（规范第八章 8.1/8.2/8.3）----
  Widget _appearance(BuildContext context, AppThemeController tc) {
    final t = context.tokens;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section(context, '外观'),
      // 基准主题：bg + primary 双色缩略卡，点击即换、全局 300ms 过渡
      SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: kBuiltinThemes.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (ctx, i) {
            final th = kBuiltinThemes[i];
            final selected = tc.base.id == th.id;
            return GestureDetector(
              onTap: () => tc.setBase(th),
              child: Container(
                width: 104,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: selected ? t.primary : t.line, width: selected ? 2 : 1),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: th.tokens.bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: t.line),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(color: th.tokens.primary, shape: BoxShape.circle),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(th.name,
                      style: TextStyle(
                          color: selected ? t.primary : t.text,
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
                ]),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 14),
      Text('强调色', style: TextStyle(color: t.textSub, fontSize: 12)),
      const SizedBox(height: 8),
      Wrap(spacing: 12, runSpacing: 10, children: [
        _accentDot(context, tc, null, Icons.auto_awesome_outlined),
        for (final c in kAccentPalette) _accentDot(context, tc, c, null),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Text('冷暖基调', style: TextStyle(color: t.textSub, fontSize: 12)),
        Expanded(
          child: Slider(
            value: tc.warmth,
            min: -1,
            max: 1,
            divisions: 16,
            label: tc.warmth == 0
                ? '标准'
                : (tc.warmth > 0 ? '暖 +${(tc.warmth * 100).round()}' : '冷 ${(tc.warmth * 100).round()}'),
            activeColor: t.primary,
            inactiveColor: t.surface2,
            onChanged: tc.setWarmth,
          ),
        ),
      ]),
      Row(children: [
        TextButton.icon(
          onPressed: () => _exportTheme(context, tc),
          icon: Icon(Icons.ios_share_outlined, size: 16, color: t.textSub),
          label: Text('导出 .mtheme', style: TextStyle(color: t.textSub, fontSize: 13)),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: () => _importTheme(context, tc),
          icon: Icon(Icons.file_open_outlined, size: 16, color: t.textSub),
          label: Text('导入（剪贴板）', style: TextStyle(color: t.textSub, fontSize: 13)),
        ),
      ]),
    ]);
  }

  Widget _accentDot(BuildContext context, AppThemeController tc, Color? color, IconData? icon) {
    final t = context.tokens;
    final selected = tc.accent == color;
    // Tooltip 的 message 与 richMessage 不能同时为 null（Flutter 断言），
    // 此前传 null 会导致进入设置页即崩溃。
    return Tooltip(
      message: color == null ? '主题默认' : '强调色 #${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
      child: GestureDetector(
        onTap: () => tc.setAccent(color),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color ?? t.surface2,
            shape: BoxShape.circle,
            border: Border.all(color: selected ? t.text : t.line, width: selected ? 2 : 1),
          ),
          child: color == null
              ? Icon(icon, size: 16, color: t.textSub)
              : selected
                  ? Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
        ),
      ),
    );
  }

  Future<void> _exportTheme(BuildContext context, AppThemeController tc) async {
    final m = MTheme(id: tc.base.id, name: tc.base.name, isDark: tc.isDark, tokens: tc.tokens);
    await Clipboard.setData(ClipboardData(text: m.toJson()));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前主题 JSON 已复制到剪贴板，粘贴保存为 .mtheme 文件即可分享')));
    }
  }

  Future<void> _importTheme(BuildContext context, AppThemeController tc) async {
    final raw = await Clipboard.getData('text/plain');
    final text = raw?.text?.trim() ?? '';
    if (text.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('剪贴板为空，请先复制 .mtheme 主题 JSON')));
      }
      return;
    }
    try {
      final theme = MTheme.fromJson(text, fallback: tc.base);
      tc.applyImported(theme);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已应用主题「${theme.name}」')));
      }
    } on MThemeFormatException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导入失败：$e')));
      }
    }
  }

  void _update(AppSettings s) async {
    await context.read<SettingsRepository>().save(s);
    setState(() {});
  }

  String _qualityLabel(String q) => q == 'standard' ? '标准（96kbps）' : '高质量（128kbps）';

  String? _presetName(PresetController pc, String id) {
    for (final p in pc.presets) {
      if (p.id == id) return p.name;
    }
    return null;
  }

  Widget _section(BuildContext context, String label) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(label, style: TextStyle(color: context.tokens.textSub, fontSize: 13, fontWeight: FontWeight.w600)),
      );

  Widget _row(BuildContext context, String label, String value, void Function(BuildContext)? onTap) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap == null ? null : () => onTap(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(children: [
          Text(label, style: TextStyle(color: t.text, fontSize: 15)),
          const Spacer(),
          Text(value, style: TextStyle(color: t.textSub, fontSize: 14)),
          if (onTap != null) Icon(Icons.chevron_right, size: 20, color: t.textSub),
        ]),
      ),
    );
  }

  Future<String?> _pick(BuildContext context, String title, Map<String, String> options, String current) =>
      showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text(title),
          children: options.entries
              .map((e) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, e.key),
                    child: Text(e.value + (e.key == current ? ' ✓' : '')),
                  ))
              .toList(),
        ),
      );

  Future<String?> _pickPreset(BuildContext context, PresetController pc, String current, {bool allowNone = false}) {
    final options = <String, String>{
      if (allowNone) '': '不自动播放',
      for (final p in pc.presets) p.id: p.name,
    };
    return _pick(context, '选择方案', options, current);
  }

  void _showLicense(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: const [
          Text('开源许可', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          SizedBox(height: 8),
          Text('本应用使用了以下开源组件（节选）：\n\n· Flutter — BSD 3-Clause\n· audioplayers — MIT\n· provider — MIT\n· shared_preferences — BSD 3-Clause\n· path_provider — BSD 3-Clause\n· window_manager — MIT\n· system_tray — MIT\n\n完整清单见发布说明。'),
        ]),
      ),
    );
  }

  void _showLicenses(BuildContext context) {
    // FR-27：素材名 — 来源 — 授权类型随包公示
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: const [
          Text('音频素材授权清单', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          SizedBox(height: 10),
          Text(
            '素材来自 Wikimedia Commons（CC0 / 公有领域 / CC BY / CC BY-SA）与算法合成，均允许商业使用。\n\n'
            '小雨 — Gravity Sound「雨打树叶」（CC BY 4.0）\n'
            '大雨 — valvalion「落雨音效」（CC BY 3.0）\n'
            '风 — Robert EA Harvey「Wind sounds」（CC BY-SA 4.0，低通去叶噪）\n'
            '森林 — Gravity Sound（CC BY 4.0）\n'
            '雷声 — Rhumphries（CC BY 3.0）\n'
            '溪流 — jackthemurray（CC0）\n'
            '海浪 — Sea waves（CC BY-SA 4.0）\n'
            '鸟鸣 — Bourne Lincolnshire 录音（CC BY-SA 4.0）\n'
            '杜鹃 — Common Cuckoo 录音（CC BY-SA 4.0）\n'
            '麻雀 — QWerk「House Sparrows chirping」（CC BY-SA 3.0）\n'
            '夜莺 — Digweed1「Common Nightingale\'s song」（CC0）\n'
            '篝火 — Glaneur de sons（CC BY 3.0）\n'
            '夜晚虫鸣 — Night recording（CC BY-SA 4.0）\n'
            '狗叫 — Nicholas Gemini「Barking dog in Rome」（CC BY-SA 3.0）\n'
            '鸡叫 — alys「Chickens demanding food」（公有领域）\n'
            '鹅叫 — Canada Geese 录音（CC BY-SA 4.0）\n'
            '池塘 — 柏林池塘鸭群戏水环境声（CC BY-SA 4.0）\n'
            '咖啡馆 — stephan（公有领域）\n'
            '键盘敲击 — russiandoll（公有领域）\n'
            '风铃 — Koshi chimes（CC0）\n'
            '白/粉/棕噪音 — 算法合成，无版权\n\n'
            '各素材均已裁切为 60 秒循环、响度归一化处理。完整清单与来源链接见随包 docs/音频素材授权清单.csv。',
            style: TextStyle(fontSize: 13, height: 1.7),
          ),
        ]),
      ),
    );
  }
}
