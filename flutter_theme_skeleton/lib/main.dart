import 'package:flutter/material.dart';

import 'theme/app_themes.dart';
import 'theme/app_tokens.dart';
import 'theme/theme_controller.dart';

/// ============================================================
/// 使用示例：ThemeData / ThemeExtension 接线方式
/// 复制到 Flutter 工程入口即可运行（依赖仅 Flutter SDK 本体）。
/// ============================================================

/// 音源图标映射位：V1.0 开发期用 emoji 占位，上线前整表替换为
/// 1.8pt 描边线性图标（SVG/字体图标），组件与数据层零改动。
/// 规范来源：《UI设计规范 v1.1》——音源 8 色淡底（icon 底色随音源组）。
const Map<String, String> kSoundEmojiPlaceholder = {
  'rain-light': '🌧',
  'rain-heavy': '🌧',
  'thunder': '⛈',
  'wind': '🍃',
  'stream': '🏞',
  'waves': '🌊',
  'birds': '🐦',
  'campfire': '🔥',
  'forest': '🌲',
  'night-crickets': '🦗',
  'noise-white': '●',
  'noise-pink': '◍',
  'noise-brown': '◉',
  'cafe': '☕',
  'keyboard': '⌨',
  'chimes': '🎐',
};

void main() {
  runApp(const MixNoticeApp());
}

class MixNoticeApp extends StatefulWidget {
  const MixNoticeApp({super.key});

  @override
  State<MixNoticeApp> createState() => _MixNoticeAppState();
}

class _MixNoticeAppState extends State<MixNoticeApp> {
  final AppThemeController _themeController = AppThemeController();

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _themeController,
      builder: (context, _) {
        // 最终 tokens（含自定义强调色/冷暖）注入 extensions；主题切换 300ms 过渡（规范 4.4）
        return AnimatedTheme(
          duration: const Duration(milliseconds: 300),
          data: buildAppTheme(_themeController.base)
              .copyWith(extensions: <ThemeExtension<dynamic>>[_themeController.tokens]),
          child: DefaultValues(
            controller: _themeController,
            child: MaterialApp(
              title: 'MixNoticeApp',
              debugShowCheckedModeBanner: false,
              themeMode: _themeController.base.isDark ? ThemeMode.dark : ThemeMode.light,
              theme: buildAppTheme(kBuiltinThemes[2]), // 浅色基准（跟随系统时用）
              darkTheme: buildAppTheme(kBuiltinThemes[0]), // 深色基准
              home: const ThemeDemoPage(),
            ),
          ),
        );
      },
    );
  }
}

class ThemeDemoPage extends StatelessWidget {
  const ThemeDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens; // ← 组件只从这里取色
    return Scaffold(
      appBar: AppBar(
        title: const Text('主题骨架自检'),
        backgroundColor: t.bg,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _row(context, 'bg / surface / surface2', [
            Container(color: t.bg),
            Container(color: t.surface),
            Container(color: t.surface2),
          ]),
          const SizedBox(height: 16),
          _row(context, 'primary / press / amber / teal', [
            Container(color: t.primary),
            Container(color: t.primaryPress),
            Container(color: t.amber),
            Container(color: t.teal),
          ]),
          const SizedBox(height: 16),
          _row(context, 'text / textSub / danger / line', [
            Container(color: t.text),
            Container(color: t.textSub),
            Container(color: t.danger),
            Container(color: t.line),
          ]),
          const SizedBox(height: 24),
          // 倒计时大数字：displayLarge 已内置 tabular-nums
          Center(
            child: Text('30:00', style: Theme.of(context).textTheme.displayLarge),
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: t.primary,
              foregroundColor: t.bg,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _cycleTheme(context),
            child: const Text('切换下一套内置主题'),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, List<Widget> swatches) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Row(
          children: swatches
              .map((s) => Expanded(
                    child: Container(
                      height: 44,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: (s as Container).color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).extension<AppTokens>()!.line),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  void _cycleTheme(BuildContext context) {
    // 演示用：真实控制器见 AppThemeController.setBase / setAccent / setWarmth
    final current = Theme.of(context).extension<AppTokens>()!;
    final order = [
      AppTokens.nightForest,
      AppTokens.deepSpace,
      AppTokens.morningMist,
      AppTokens.warmSand,
    ];
    final next = order[(order.indexOf(current) + 1) % order.length];
    final match = kBuiltinThemes.firstWhere((b) => b.tokens == next);
    DefaultValues.of(context).controller.setBase(match);
  }
}

/// 演示用依赖注入；真实工程可用 provider / riverpod 替代
class DefaultValues extends InheritedWidget {
  final AppThemeController controller;
  const DefaultValues({super.key, required this.controller, required super.child});

  static DefaultValues of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DefaultValues>()!;

  @override
  bool updateShouldNotify(DefaultValues oldWidget) => controller != oldWidget.controller;
}
