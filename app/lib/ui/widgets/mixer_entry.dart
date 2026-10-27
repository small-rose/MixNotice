/// 混音台入口（常驻 AppBar）
/// FR-03/FR-04 缺口修复：静默态（未播放、空混音）时迷你播放条会隐藏，
/// 此前没有任何入口进入混音台。此处保证三 Tab 页随时可进。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../audio/playback_controller.dart';
import '../../theme/app_tokens.dart';

class MixerEntryButton extends StatelessWidget {
  const MixerEntryButton({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final count = context.select<PlaybackController, int>((p) => p.channels.length);
    return IconButton(
      icon: Stack(clipBehavior: Clip.none, children: [
        Icon(Icons.tune, color: t.textSub),
        if (count > 0)
          Positioned(
            right: -3,
            top: -3,
            child: Container(
              padding: const EdgeInsets.all(3),
              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
              decoration: BoxDecoration(color: t.primary, shape: BoxShape.circle),
              child: Center(
                child: Text('$count',
                    style: TextStyle(
                        color: t.bg, fontSize: 9, fontWeight: FontWeight.w700, height: 1)),
              ),
            ),
          ),
      ]),
      tooltip: '混音台',
      onPressed: () => Navigator.pushNamed(context, '/mixer'),
    );
  }
}
