/// 设置入口（三页常驻 AppBar）
/// 反馈：设置按钮仅在声音库出现，方案库/计时器页无处可进。
/// 抽成独立组件，保证三 Tab 页 AppBar 右侧按钮组完全一致（混音台 + 设置）。
library;

import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';

class SettingsEntryButton extends StatelessWidget {
  const SettingsEntryButton({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return IconButton(
      icon: Icon(Icons.settings_outlined, color: t.textSub),
      tooltip: '设置',
      onPressed: () => Navigator.pushNamed(context, '/settings'),
    );
  }
}
