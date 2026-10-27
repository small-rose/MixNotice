// 完整启动冒烟测试：复刻 main() 在 Android 上的启动链路，
// 用真实 MixNoticeApp + 真实控制器/仓库（仅 mock 平台通道），确保首帧可渲染。
//
// 背景：真机（Redmi K80 Pro）反馈启动白屏。白屏 = main() 在 runApp 之前
// 抛异常/挂起，或首帧构建抛异常。本测试用于捕获 Dart 层原因。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixnotice/data/preset_repository.dart';
import 'package:mixnotice/data/settings_repository.dart';
import 'package:mixnotice/main.dart';
import 'package:mixnotice/audio/audio_engine.dart';
import 'package:mixnotice/audio/playback_controller.dart';
import 'package:mixnotice/audio/timer_controller.dart';
import 'package:mixnotice/data/preset_controller.dart';
import 'package:mixnotice/ui/pages/mixer_page.dart';
import 'package:mixnotice/theme/app_tokens.dart';
import 'package:mixnotice/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<MixNoticeApp> buildApp() async {
    // ---- 平台通道 mock（等同真机插件返回值）----
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, (call) async {
      switch (call.method) {
        case 'getApplicationSupportDirectory': // path_provider 实际方法名
        case 'getApplicationDocumentsDirectory':
        case 'getTemporaryDirectory':
          return '/tmp/mixnotice-test';
        default:
          return null;
      }
    });

    // ---- 与 main() 相同的装配顺序 ----
    final engine = AudioEngine();
    final playback = PlaybackController(engine);
    final timer = TimerController(playback, engine);
    final presetRepo = PresetRepository();
    final presetCtrl = PresetController(presetRepo);
    final settingsRepo = SettingsRepository();
    final settings = await settingsRepo.load();
    final themeCtrl = AppThemeController();
    await themeCtrl.load();
    await presetCtrl.load();

    return MixNoticeApp(
      playback: playback,
      timer: timer,
      presetCtrl: presetCtrl,
      settings: settings,
      settingsRepo: settingsRepo,
      themeCtrl: themeCtrl,
    );
  }

  testWidgets('完整启动：首帧渲染出声音库，无异常', (tester) async {
    final app = await buildApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('声音库'), findsWidgets); // Tab 标签 + AppBar 标题
  });

  testWidgets('完整启动：主题控制器 tokens 可通过 context 取到', (tester) async {
    final app = await buildApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    final ctx = tester.element(find.byType(Navigator).first);
    final theme = Theme.of(ctx);
    expect(theme.extension<AppTokens>(), isNotNull); // AppTokens 已注入
    expect(tester.takeException(), isNull);
  });

  testWidgets('从首页进入设置页不崩溃（真机反馈回归）', (tester) async {
    final app = await buildApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('外观'), findsOneWidget);
  });

  testWidgets('静默态也有混音台入口（无需先播放声音）', (tester) async {
    final app = await buildApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    // 空混音时迷你播放条不可见，但 AppBar 必须提供混音台入口
    expect(find.byIcon(Icons.tune), findsWidgets);
    await tester.tap(find.byIcon(Icons.tune).first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(MixerPage), findsOneWidget);
  });

  testWidgets('三个 Tab 页都有设置入口且都能进设置页（真机反馈回归）', (tester) async {
    final app = await buildApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    const tabIcons = [Icons.graphic_eq_outlined, Icons.playlist_play_outlined, Icons.timer_outlined];
    for (var i = 0; i < tabIcons.length; i++) {
      await tester.tap(find.byIcon(tabIcons[i]));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.settings_outlined), findsOneWidget, reason: '第 ${i + 1} 个 Tab 页缺少设置按钮');
      expect(find.byIcon(Icons.tune), findsOneWidget, reason: '第 ${i + 1} 个 Tab 页缺少混音台按钮');

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('外观'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });
}
