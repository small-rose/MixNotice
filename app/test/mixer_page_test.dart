// 交互回归：声音库勾选加入/取消 + 混音台播放暂停
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mixnotice/audio/audio_engine.dart';
import 'package:mixnotice/audio/playback_controller.dart';
import 'package:mixnotice/data/models.dart';
import 'package:mixnotice/theme/app_themes.dart';
import 'package:mixnotice/ui/pages/library_page.dart';
import 'package:mixnotice/ui/pages/mixer_page.dart';

class _FakeAudioEngine implements AudioEngine {
  int pauses = 0;
  int resumes = 0;
  int stops = 0;
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
  Future<void> pauseAll() async => pauses++;
  @override
  Future<void> resumeAll() async => resumes++;
  @override
  Future<void> stopAll() async => stops++;
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

Widget _wrap(Widget child) => ChangeNotifierProvider.value(
      value: _pb!,
      child: MaterialApp(theme: buildAppTheme(kBuiltinThemes.first), home: child),
    );

PlaybackController? _pb;

void main() {
  setUp(() => _pb = PlaybackController(_FakeAudioEngine()));

  testWidgets('声音库勾选：点一次加入混音，再点一次移除', (tester) async {
    final pb = _pb!;
    await tester.pumpWidget(_wrap(const LibraryPage()));
    await tester.pumpAndSettle();

    final toggle = find.byKey(const ValueKey('mix-toggle-rain-light'));
    expect(toggle, findsOneWidget);

    await tester.tap(toggle);
    await tester.pump();
    expect(pb.containsSource('rain-light'), isTrue, reason: '勾选后应加入混音');
    expect(pb.channels.length, 1);

    await tester.tap(toggle);
    await tester.pump();
    expect(pb.containsSource('rain-light'), isFalse, reason: '再次点击应移除音轨');
    expect(pb.channels, isEmpty);
  });

  testWidgets('混音台：播放/暂停按钮切换状态', (tester) async {
    final pb = _pb!;
    final engine = pb.engine as _FakeAudioEngine;
    await tester.runAsync(() async {
      await pb.addSource('rain-light', autoPlay: false);
      await pb.addSource('campfire', autoPlay: false);
    });
    await tester.pumpWidget(_wrap(const MixerPage()));
    await tester.pumpAndSettle();

    final btn = find.byKey(const ValueKey('mixer-play-toggle'));
    expect(btn, findsOneWidget);
    // 起始 idle：按钮为「播放」
    expect(find.byIcon(Icons.play_arrow_rounded), findsWidgets);

    await tester.tap(btn);
    await tester.pumpAndSettle();
    expect(pb.isPlaying, isTrue, reason: '点播放后应进入播放态');
    expect(engine.resumes, greaterThan(0));

    await tester.tap(btn);
    await tester.pumpAndSettle();
    expect(pb.isPaused, isTrue, reason: '再点一次应暂停');
    expect(engine.pauses, greaterThan(0));
  });

  testWidgets('混音台窄屏（320px）不溢出', (tester) async {
    final pb = _pb!;
    await tester.runAsync(() async {
      for (final id in ['rain-light', 'campfire', 'waves', 'dog-bark']) {
        await pb.addSource(id, autoPlay: false);
      }
    });
    tester.view.physicalSize = const Size(320, 640) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_wrap(const MixerPage()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('音轨 4'), findsOneWidget);
  });
}
