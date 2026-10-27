/// 应用外壳：三 Tab（声音库/方案库/计时器）+ 迷你播放条（设计稿 v1.1）
library;

import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import 'pages/library_page.dart';
import 'pages/presets_page.dart';
import 'pages/timer_page.dart';
import 'widgets/mini_player.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      body: TabBarView(
        physics: const NeverScrollableScrollPhysics(),
        children: [const LibraryPage(), const PresetsPage(), const TimerPage()],
      ),
      // 迷你播放条悬浮于 Tab 栏上方
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        const MiniPlayer(),
        Container(
          decoration: BoxDecoration(
            color: t.bg.withAlpha(240),
            border: Border(top: BorderSide(color: t.line)),
          ),
          child: TabBar(
            labelColor: t.primary,
            unselectedLabelColor: t.textSub,
            indicatorColor: Colors.transparent,
            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(icon: Icon(Icons.graphic_eq_outlined), text: '声音库'),
              Tab(icon: Icon(Icons.playlist_play_outlined), text: '方案库'),
              Tab(icon: Icon(Icons.timer_outlined), text: '计时器'),
            ],
          ),
        ),
      ]),
    );
  }
}
