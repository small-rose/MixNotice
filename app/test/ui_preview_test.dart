// UI 预览导出（设计校验用）：把声音库卡片与迷你播放条渲染成 PNG，便于目视检查版式
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mixnotice/audio/audio_engine.dart';
import 'package:mixnotice/audio/playback_controller.dart';
import 'package:mixnotice/audio/timer_controller.dart';
import 'package:mixnotice/data/models.dart';
import 'package:mixnotice/data/preset_controller.dart';
import 'package:mixnotice/data/preset_repository.dart';
import 'package:mixnotice/data/settings_repository.dart';
import 'package:mixnotice/ui/pages/timer_page.dart';
import 'package:mixnotice/theme/app_themes.dart';
import 'package:mixnotice/ui/pages/library_page.dart';
import 'package:mixnotice/ui/pages/mixer_page.dart';
import 'package:mixnotice/ui/widgets/mini_player.dart';

class _FakeAudioEngine implements AudioEngine {
  @override
  double get master => 1.0;
  @override
  void setMaster(double v) {}
  @override
  void setFadeFactor(double f) {}
  @override
  Future<void> addChannel(Channel ch) async {}
  @override
  Future<void> removeChannel(String channelId) async {}
  @override
  Future<void> updateChannel(Channel ch) async {}
  @override
  Future<void> pauseAll() async {}
  @override
  Future<void> resumeAll() async {}
  @override
  Future<void> stopAll() async {}
  @override
  Future<void> startPreview(String sourceId) async {}
  @override
  Future<void> stopPreview() async {}
  @override
  bool get hasPreview => false;
  @override
  bool hasInstance(String channelId) => true;
  @override
  set channelLookup(Channel? Function(String channelId) f) {}
  @override
  Future<void> dispose() async {}
}

Future<void> _dump(WidgetTester tester, GlobalKey key, String name) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final img = await boundary.toImage(pixelRatio: 2);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }) as Uint8List;
  Directory('build').createSync(recursive: true);
  File('build/$name.png').writeAsBytesSync(bytes);
}

void main() {
  testWidgets('导出声音库 + 迷你播放条预览图', (tester) async {
    final pb = PlaybackController(_FakeAudioEngine());
    await tester.runAsync(() async {
      await pb.addSource('rain-light');
      await pb.addSource('campfire');
      await pb.addSource('waves');
    });
    pb.previewingSourceId = 'birds';

    final libKey = GlobalKey();
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(RepaintBoundary(
      key: libKey,
      child: ChangeNotifierProvider.value(
        value: pb,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(kBuiltinThemes.first),
          home: const LibraryPage(),
        ),
      ),
    ));
    // 播放态含循环动画（LevelBars），不能用 pumpAndSettle
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _dump(tester, libKey, 'ui_library_preview');

    // 浅色主题（晨雾）对照：验证淡色渐变在亮底上的层次
    final lightKey = GlobalKey();
    tester.view.physicalSize = const Size(430, 900);
    await tester.pumpWidget(RepaintBoundary(
      key: lightKey,
      child: ChangeNotifierProvider.value(
        value: pb,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(kBuiltinThemes[2]),
          home: const LibraryPage(),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _dump(tester, lightKey, 'ui_library_light_preview');

    // 计时器页（深色，睡眠态）
    final timerKey = GlobalKey();
    final timerCtrl = TimerController(pb, _FakeAudioEngine());
    tester.view.physicalSize = const Size(430, 900);
    await tester.pumpWidget(RepaintBoundary(
      key: timerKey,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<PlaybackController>.value(value: pb),
          ChangeNotifierProvider<TimerController>.value(value: timerCtrl),
          ChangeNotifierProvider<PresetController>.value(value: PresetController(PresetRepository())),
          ChangeNotifierProvider<AppSettings>.value(value: AppSettings()),
          Provider<SettingsRepository>.value(value: SettingsRepository()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(kBuiltinThemes.first),
          home: const TimerPage(),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _dump(tester, timerKey, 'ui_timer_preview');

    // 混音台页（深色，4 轨播放中）
    final mixerKey = GlobalKey();
    final mixerPb = PlaybackController(_FakeAudioEngine());
    await tester.runAsync(() async {
      for (final id in ['rain-light', 'campfire', 'waves', 'dog-bark']) {
        await mixerPb.addSource(id);
      }
      await mixerPb.setChannelVolume(mixerPb.channels[1], 65);
      await mixerPb.toggleMute(mixerPb.channels[3]);
    });
    tester.view.physicalSize = const Size(430, 900);
    await tester.pumpWidget(RepaintBoundary(
      key: mixerKey,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<PlaybackController>.value(value: mixerPb),
          ChangeNotifierProvider<PresetController>.value(value: PresetController(PresetRepository())),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(kBuiltinThemes.first),
          home: const MixerPage(),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _dump(tester, mixerKey, 'ui_mixer_preview');

    // 迷你播放条：1 / 2 / 3 / 4 轨四种态并排看
    final variants = <List<String>>[
      ['rain-light'],
      ['rain-light', 'campfire'],
      ['rain-light', 'campfire', 'waves'],
      ['rain-light', 'campfire', 'waves', 'birds', 'chimes', 'cafe'],
    ];
    final pbs = <PlaybackController>[];
    await tester.runAsync(() async {
      for (final ids in variants) {
        final p = PlaybackController(_FakeAudioEngine());
        for (final id in ids) {
          await p.addSource(id);
        }
        pbs.add(p);
      }
    });

    final miniKey = GlobalKey();
    tester.view.physicalSize = const Size(430, 330);
    await tester.pumpWidget(RepaintBoundary(
      key: miniKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(kBuiltinThemes.first),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final p in pbs)
                ChangeNotifierProvider<PlaybackController>.value(value: p, child: const MiniPlayer()),
            ]),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _dump(tester, miniKey, 'ui_mini_player_preview');

    expect(File('build/ui_mixer_preview.png').existsSync(), isTrue);
    expect(File('build/ui_timer_preview.png').existsSync(), isTrue);
    expect(File('build/ui_library_preview.png').existsSync(), isTrue);
    expect(File('build/ui_mini_player_preview.png').existsSync(), isTrue);
  });
}
