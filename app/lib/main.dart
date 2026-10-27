/// MixNoticeApp V1.0 入口
/// 免登录/免费/本地存储；桌面端关闭最小化到托盘（FR-23）。
///
/// 启动时序（白屏防护，2026-10-26 修复）：
/// 1. 同步装配所有控制器（纯内存，无 IO）→ 立即 runApp 出首帧；
/// 2. 存储/主题/窗口等异步初始化全部放到 bootstrap，逐项 try/catch，
///    任何一项失败只记埋点不阻塞 UI —— main() 里 runApp 之前禁止任何 await。
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'audio/audio_engine.dart';
import 'audio/playback_controller.dart';
import 'audio/timer_controller.dart';
import 'core/analytics.dart';
import 'data/preset_controller.dart';
import 'data/preset_repository.dart';
import 'data/settings_repository.dart';
import 'services/now_playing.dart';
import 'services/tray_service.dart';
import 'theme/app_themes.dart' show buildThemeFromTokens;
import 'theme/app_tokens.dart';
import 'theme/theme_controller.dart';
import 'ui/app.dart';
import 'ui/pages/mixer_page.dart';
import 'ui/pages/settings_page.dart';

void main() {
  _installErrorHandlers(); // 任何启动期/运行期异常都落埋点，不再静默白屏
  WidgetsFlutterBinding.ensureInitialized();

  // ---- 同步装配（纯内存，绝不抛异常）----
  final engine = AudioEngine();
  final playback = PlaybackController(engine);
  final timer = TimerController(playback, engine);
  final presetRepo = PresetRepository();
  final presetCtrl = PresetController(presetRepo);
  final settingsRepo = SettingsRepository();
  final settings = AppSettings(); // 默认值，bootstrap 完成后被真实值覆盖
  final themeCtrl = AppThemeController();

  // ---- 先出首帧 ----
  runApp(MixNoticeApp(
    playback: playback,
    timer: timer,
    presetCtrl: presetCtrl,
    settings: settings,
    settingsRepo: settingsRepo,
    themeCtrl: themeCtrl,
  ));

  // ---- 后补装：存储状态 / 桌面窗口与托盘 ----
  unawaited(_bootstrap(playback, timer, presetCtrl, settingsRepo, settings, themeCtrl));
}

Future<void> _bootstrap(
  PlaybackController playback,
  TimerController timer,
  PresetController presetCtrl,
  SettingsRepository settingsRepo,
  AppSettings settings,
  AppThemeController themeCtrl,
) async {
  for (final step in <String, Future<void> Function()>{
    // 系统播放信息（通知栏/锁屏/后台续播）优先：失败也只是少了通知，不影响播放
    'nowPlaying': () async => NowPlaying.init(playback, timer),
    'theme': () async => themeCtrl.load(),
    'presets': () async => presetCtrl.load(),
    'settings': () async => settings.updateFrom(await settingsRepo.load()),
  }.entries) {
    try {
      await step.value();
    } catch (e, s) {
      // 存储层损坏/插件异常不阻塞启动（E-06 精神：降级为默认值）
      Analytics.instance.log('startup_error', {
        'stage': step.key,
        'error': '$e',
        'stack': s.toString().length > 300 ? s.toString().substring(0, 300) : s.toString(),
      });
    }
  }

  final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
  if (isDesktop) {
    try {
      await windowManager.ensureInitialized();
      await windowManager.waitUntilReadyToShow(
        const WindowOptions(minimumSize: Size(560, 480), size: Size(960, 640), title: 'MixNoticeApp'),
        () async {
          await windowManager.show();
        },
      );
      await TrayService.instance.init(playback, presetCtrl);
    } catch (e) {
      Analytics.instance.log('startup_error', {'stage': 'desktop', 'error': '$e'});
    }
  }
}

/// 系统栏（状态栏/导航栏）配色跟随当前主题。
/// 浅色主题下若仍是浅色图标，状态栏会"消失"在 #F5F4EF 底色里。
void _syncSystemBars(AppTokens tokens, bool isDark) {
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    // Android 语义：iconBrightness = 图标本身的明度
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    // iOS 语义：statusBarBrightness 是背景明度（与 Android 相反）
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: tokens.bg,
    systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
  ));
}

/// 全局错误捕获：Flutter 框架异常 + 未捕获的平台异常 → 埋点（本地队列，上报失败静默）
void _installErrorHandlers() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    final msg = details.exceptionAsString();
    Analytics.instance.log('flutter_error', {
      'summary': msg.length > 200 ? msg.substring(0, 200) : msg,
      'library': details.library ?? '',
    });
  };
  PlatformDispatcher.instance.onError = (e, stack) {
    final msg = '$e';
    Analytics.instance.log('platform_error', {
      'summary': msg.length > 200 ? msg.substring(0, 200) : msg,
    });
    return false; // 不吞异常，交给默认处理
  };
}

class MixNoticeApp extends StatelessWidget {
  const MixNoticeApp({
    super.key,
    required this.playback,
    required this.timer,
    required this.presetCtrl,
    required this.settings,
    required this.settingsRepo,
    required this.themeCtrl,
  });

  final PlaybackController playback;
  final TimerController timer;
  final PresetController presetCtrl;
  final AppSettings settings;
  final SettingsRepository settingsRepo;
  final AppThemeController themeCtrl;

  @override
  Widget build(BuildContext context) {
    // ---- 依赖注入（2026-10-26 修复白屏：此前重写时丢失 MultiProvider，
    //      HomeShell 下所有 context.watch 首帧即抛 ProviderNotFoundException）----
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<PlaybackController>.value(value: playback),
        ChangeNotifierProvider<TimerController>.value(value: timer),
        ChangeNotifierProvider<PresetController>.value(value: presetCtrl),
        ChangeNotifierProvider<AppThemeController>.value(value: themeCtrl),
        ChangeNotifierProvider<AppSettings>.value(value: settings),
        Provider<SettingsRepository>.value(value: settingsRepo),
      ],
      child: ListenableBuilder(
        listenable: themeCtrl,
        builder: (context, _) {
          final data = buildThemeFromTokens(themeCtrl.tokens, isDark: themeCtrl.isDark);
          return MaterialApp(
            title: 'MixNotice',
            debugShowCheckedModeBanner: false,
            theme: data,
            darkTheme: data,
            themeMode: ThemeMode.system,
            initialRoute: '/',
            routes: {
              '/': (ctx) => DefaultTabController(length: 3, child: const HomeShell()),
              '/mixer': (ctx) => const MixerPage(),
              '/settings': (ctx) => const SettingsPage(),
            },
            builder: (ctx, child) {
              // 系统栏跟随主题：默认浅色主题下状态栏必须是深色图标，否则白字看不见
              _syncSystemBars(themeCtrl.tokens, themeCtrl.isDark);
              return AnimatedTheme(
                data: data,
                duration: const Duration(milliseconds: 300),
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}
