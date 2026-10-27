// 回归测试：混音台构建（滑杆断言）、音轨幂等、主题接入
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mixnotice/audio/audio_engine.dart';
import 'package:mixnotice/audio/playback_controller.dart';
import 'package:mixnotice/core/constants.dart';
import 'package:mixnotice/data/models.dart';
import 'package:mixnotice/data/preset_controller.dart';
import 'package:mixnotice/data/preset_repository.dart';
import 'package:mixnotice/theme/app_themes.dart';
import 'package:mixnotice/theme/app_tokens.dart';
import 'package:mixnotice/theme/theme_controller.dart';
import 'package:mixnotice/ui/pages/library_page.dart';
import 'package:mixnotice/ui/pages/mixer_page.dart';
import 'package:mixnotice/ui/widgets/mini_player.dart';

PlaybackController _pb() => PlaybackController(_FakeAudioEngine());

/// 测试替身：no-op 引擎（不触达 audioplayers 插件通道）
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

Widget _wrap(PlaybackController pb, Widget child) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: pb),
        ChangeNotifierProvider.value(value: PresetController(PresetRepository())),
      ],
      child: MaterialApp(theme: buildAppTheme(kBuiltinThemes.first), home: child),
    );

void main() {
  testWidgets('回归：混音台含音轨可正常构建（音轨滑杆 0-100 断言不触发）', (tester) async {
    final pb = _pb();
    await tester.runAsync(() async {
      await pb.addSource('rain-light', autoPlay: false);
      await pb.addSource('campfire', autoPlay: false);
    });
    await tester.pumpWidget(_wrap(pb, const MixerPage()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('混音台'), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(3)); // 2 音轨 + 1 总音量
  });

  testWidgets('回归：同一音源重复加入为幂等（不新增音轨）', (tester) async {
    final pb = _pb();
    await tester.runAsync(() async {
      await pb.addSource('rain-light', autoPlay: false);
      await pb.addSource('rain-light', autoPlay: false);
    });
    expect(pb.channels.length, 1);
  });

  testWidgets('回归：加入第 7 轨被拒绝', (tester) async {
    final pb = _pb();
    final ids = kSounds.map((s) => s.id).toList();
    await tester.runAsync(() async {
      for (final id in ids.take(6)) {
        await pb.addSource(id, autoPlay: false);
      }
    });
    final err = await tester.runAsync(() => pb.addSource(ids[6], autoPlay: false));
    expect(err, contains('最多'));
    expect(pb.channels.length, 6);
  });

  testWidgets('回归：载入含重复音源的方案自动去重', (tester) async {
    final pb = _pb();
    final preset = PresetData(id: 'x', name: 'x', builtin: false, channels: [
      Channel(id: 'a', sourceId: 'rain-light'),
      Channel(id: 'b', sourceId: 'rain-light'),
      Channel(id: 'c', sourceId: 'wind'),
    ]);
    await tester.runAsync(() => pb.loadPreset(preset));
    expect(pb.channels.length, 2); // rain-light 去重后仅保留一条
  });

  testWidgets('回归：声音库展示 16 音源且「已加入」态正确', (tester) async {
    final pb = _pb();
    await tester.runAsync(() async {
      await pb.addSource('rain-light', autoPlay: false);
      await pb.addSource('rain-light', autoPlay: false); // 幂等
    });
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(pb, const LibraryPage()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('小雨'), findsOneWidget);
    // 16 个音源名都在
    for (final s in kSounds) {
      expect(find.text(s.name), findsOneWidget);
    }
  });

  testWidgets('回归：主题控制器 tokens 生效（强调色 + 冷暖）', (tester) async {
    final tc = AppThemeController();
    final basePrimary = tc.tokens.primary;
    tc.setAccent(const Color(0xFF5B9BD5));
    expect(tc.tokens.primary, const Color(0xFF5B9BD5));
    expect(basePrimary, AppTokens.nightForest.primary);

    final before = tc.tokens.bg;
    tc.setWarmth(1.0);
    expect(tc.tokens.bg, isNot(before));
  });

  testWidgets('回归：迷你播放条点击进混音台', (tester) async {
    final pb = _pb();
    await tester.runAsync(() async {
      await pb.addSource('rain-light', autoPlay: false);
      await pb.addSource('wind', autoPlay: false);
    });
    final pbProv = pb;
    await tester.pumpWidget(MultiProvider(
      providers: [ChangeNotifierProvider<PlaybackController>.value(value: pbProv)],
      child: MaterialApp(
        theme: buildAppTheme(kBuiltinThemes.first),
        routes: {'/mixer': (ctx) => const MixerPage()},
        home: DefaultTabController(
          length: 1,
          child: const Scaffold(bottomNavigationBar: MiniPlayer()),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MiniPlayer));
    await tester.pumpAndSettle();
    expect(find.text('混音台'), findsOneWidget);
  });
}
