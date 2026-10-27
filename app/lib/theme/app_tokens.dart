import 'package:flutter/material.dart';

/// ============================================================
/// L1 基础层：语义 Token
/// 规范来源：《UI设计规范-MixNoticeApp-v1.1.md》第二章
/// 规则：组件代码只允许引用 AppTokens 的字段，禁止写死色值。
/// ============================================================

@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  final Color bg; // 页面底色
  final Color surface; // 卡片/列表底
  final Color surface2; // 次级卡片/滑杆轨道
  final Color primary; // 主操作/播放态/滑杆填充
  final Color primaryPress; // 按压态（亮度 -8%）
  final Color amber; // 时间/火 元素强调，占比 <=5%
  final Color teal; // 休息模式强调
  final Color text; // 主文字（对比 >= 4.5:1）
  final Color textSub; // 次要文字
  final Color danger; // 删除/错误
  final Color line; // 分隔线（约 8% 透明度）

  const AppTokens({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.primary,
    required this.primaryPress,
    required this.amber,
    required this.teal,
    required this.text,
    required this.textSub,
    required this.danger,
    required this.line,
  });

  /// 夜林（默认深色）
  static const AppTokens nightForest = AppTokens(
    bg: Color(0xFF0F1512),
    surface: Color(0xFF1A241E),
    surface2: Color(0xFF223029),
    primary: Color(0xFF4CAF87),
    primaryPress: Color(0xFF3D9B72),
    amber: Color(0xFFE8A854),
    teal: Color(0xFF4CB8A4),
    text: Color(0xFFEAF2EC),
    textSub: Color(0xFF9DB3A6),
    danger: Color(0xFFE2695E),
    line: Color(0x14EAF2EC),
  );

  /// 深空（深色·冷蓝）
  static const AppTokens deepSpace = AppTokens(
    bg: Color(0xFF0D1117),
    surface: Color(0xFF161D27),
    surface2: Color(0xFF1E2733),
    primary: Color(0xFF5B9BD5),
    primaryPress: Color(0xFF4A87BF),
    amber: Color(0xFFE8A854),
    teal: Color(0xFF4CB8A4),
    text: Color(0xFFE8EEF5),
    textSub: Color(0xFF97A6B5),
    danger: Color(0xFFE2695E),
    line: Color(0x14E8EEF5),
  );

  /// 晨雾（浅色·暖纸）
  static const AppTokens morningMist = AppTokens(
    bg: Color(0xFFF5F4EF),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFE4E3DC),
    primary: Color(0xFF2E7D5C),
    primaryPress: Color(0xFF256A4D),
    amber: Color(0xFFC77E2E),
    teal: Color(0xFF2E8C7A),
    text: Color(0xFF1F2B25),
    textSub: Color(0xFF6B7D74),
    danger: Color(0xFFC24E44),
    line: Color(0x1A1F2B25),
  );

  /// 暖沙（浅色·暖木）
  static const AppTokens warmSand = AppTokens(
    bg: Color(0xFFF7F2E9),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEAE2D4),
    primary: Color(0xFFB0713A),
    primaryPress: Color(0xFF9A6030),
    amber: Color(0xFFC77E2E),
    teal: Color(0xFF2E8C7A),
    text: Color(0xFF2A2118),
    textSub: Color(0xFF7A6C5C),
    danger: Color(0xFFC24E44),
    line: Color(0x1A2A2118),
  );

  @override
  AppTokens copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? primary,
    Color? primaryPress,
    Color? amber,
    Color? teal,
    Color? text,
    Color? textSub,
    Color? danger,
    Color? line,
  }) {
    return AppTokens(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      primary: primary ?? this.primary,
      primaryPress: primaryPress ?? this.primaryPress,
      amber: amber ?? this.amber,
      teal: teal ?? this.teal,
      text: text ?? this.text,
      textSub: textSub ?? this.textSub,
      danger: danger ?? this.danger,
      line: line ?? this.line,
    );
  }

  @override
  AppTokens lerp(AppTokens? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppTokens(
      bg: c(bg, other.bg),
      surface: c(surface, other.surface),
      surface2: c(surface2, other.surface2),
      primary: c(primary, other.primary),
      primaryPress: c(primaryPress, other.primaryPress),
      amber: c(amber, other.amber),
      teal: c(teal, other.teal),
      text: c(text, other.text),
      textSub: c(textSub, other.textSub),
      danger: c(danger, other.danger),
      line: c(line, other.line),
    );
  }
}

/// 组件内取 token：`final t = context.tokens;`
extension AppTokensContext on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
