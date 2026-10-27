// 布局回归测试：声音库卡片/迷你播放条在窄屏与宽屏下不得溢出
//
// 背景：真机（Redmi K80 Pro）声音库卡片出现「BOTTOM OVERFLOWED BY 15 PIXELS」。
// 旧实现用 childAspectRatio 1.55，360dp 宽屏算出的卡高仅 99px，
// 而卡内固定内容约 114px（图标 38 + 名称 + 操作行），必然溢出。
// 现改为固定卡高 + 最大宽度自适应列数，本测试锁定该行为。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mixnotice/audio/audio_engine.dart';
import 'package:mixnotice/audio/playback_controller.dart';
import 'package:mixnotice/data/models.dart';
import 'package:mixnotice/theme/app_themes.dart';
import 'package:mixnotice/ui/pages/library_page.dart';
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

Widget _wrap(PlaybackController pb, Widget child, {Size size = const Size(360, 640)}) => MediaQuery(
      data: MediaQueryData(size: size, devicePixelRatio: 1, padding: EdgeInsets.zero),
      child: ChangeNotifierProvider.value(
        value: pb,
        child: MaterialApp(theme: buildAppTheme(kBuiltinThemes.first), home: child),
      ),
    );

/// 在给定视口尺寸下泵一帧并断言无渲染异常（溢出会以 FlutterError 抛出）
Future<void> _pumpAt(WidgetTester tester, Size size, Widget widget) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: '${size.width}x${size.height} 下出现渲染异常（疑似溢出）');
}

void main() {
  final sizes = [
    const Size(320, 568), // 极窄屏（iPhone SE 级）
    const Size(360, 640), // 主流 Android
    const Size(412, 900), // 大屏手机
    const Size(1200, 800), // 桌面窗口
  ];

  for (final size in sizes) {
    testWidgets('声音库卡片在 ${size.width}x${size.height} 下不溢出', (tester) async {
      final pb = PlaybackController(_FakeAudioEngine());
      await tester.runAsync(() async {
        await pb.addSource('rain-light', autoPlay: false);
        await pb.addSource('campfire', autoPlay: false);
      });
      await _pumpAt(tester, size, _wrap(pb, const LibraryPage(), size: size));
      expect(find.text('小雨'), findsWidgets);
    });
  }

  testWidgets('卡片固定高度：不随屏宽变矮（旧 1.55 宽高比回归）', (tester) async {
    final pb = PlaybackController(_FakeAudioEngine());
    await tester.pumpWidget(_wrap(pb, const LibraryPage()));
    await tester.pumpAndSettle();

    // 卡片高度恒为 112（SliverGridDelegateWithMaxCrossAxisExtent.mainAxisExtent）
    final grid = tester.widget<GridView>(find.byType(GridView).first);
    final d = grid.gridDelegate as SliverGridDelegateWithMaxCrossAxisExtent;
    expect(d.mainAxisExtent, 112);
    expect(d.maxCrossAxisExtent, lessThanOrEqualTo(200));
  });

  testWidgets('迷你播放条：多轨堆叠渲染无溢出', (tester) async {
    final pb = PlaybackController(_FakeAudioEngine());
    await tester.runAsync(() async {
      await pb.addSource('rain-light', autoPlay: false);
      await pb.addSource('waves', autoPlay: false);
      await pb.addSource('birds', autoPlay: false);
    });
    tester.view.physicalSize = const Size(360, 640) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_wrap(pb, const Scaffold(body: Column(children: [MiniPlayer()]))));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('3 轨 · 已暂停'), findsOneWidget); // autoPlay:false → idle 态
  });

  testWidgets('迷你播放条：空混音时完全隐藏', (tester) async {
    final pb = PlaybackController(_FakeAudioEngine());
    await tester.pumpWidget(_wrap(pb, const Scaffold(body: Column(children: [MiniPlayer()]))));
    await tester.pumpAndSettle();
    expect(find.byType(MiniPlayer), findsOneWidget);
    expect(find.textContaining('轨 ·'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
