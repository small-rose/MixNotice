/// 通用小组件：音源图标（自绘线性图标 + 专属淡色底）
library;

import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../icons/sound_glyph.dart';

/// 音源专属淡色（0-7）。卡片/迷你播放条用它做渐变底色与图标底，保证同类音源视觉一致。
const kSoundTints = [
  Color(0x387FA6C9), Color(0x388E9BB3), Color(0x38A9C4B8), Color(0x386FB5C9),
  Color(0x387FBF8E), Color(0x40E8A854), Color(0x38B3AEC4), Color(0x38C9A98F),
];

/// 取音源淡色（越界安全）
Color soundTint(int colorIndex) => kSoundTints[colorIndex.clamp(0, kSoundTints.length - 1)];

class SoundIcon extends StatelessWidget {
  final String sourceId;
  final int colorIndex;
  final double size;
  final bool highlighted; // 试听中：主色描边 + 主色图标

  const SoundIcon(this.sourceId, this.colorIndex,
      {super.key, this.size = 40, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: soundTint(colorIndex),
        borderRadius: BorderRadius.circular(size),
        border: highlighted ? Border.all(color: t.primary, width: 1.5) : null,
      ),
      alignment: Alignment.center,
      child: SoundGlyph(
        sourceId,
        // 单色化：普通态用主文字色，试听态切主色（emoji 无法做到的状态着色）
        color: highlighted ? t.primary : t.text.withValues(alpha: 0.86),
        size: size * 0.58,
      ),
    );
  }
}
