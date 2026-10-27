import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// ============================================================
/// L2 主题层：内置主题注册表 + ThemeData 构建
/// 规范来源：《UI设计规范-MixNoticeApp-v1.1.md》第二、三、四章
/// 新增主题 = 在 [_builtin] 追加一个 AppTokens 常量，零组件改动。
/// ============================================================

class BuiltinTheme {
  final String id;
  final String name;
  final bool isDark;
  final AppTokens tokens;
  const BuiltinTheme(this.id, this.name, this.isDark, this.tokens);
}

/// 4 套内置主题：夜林（默认深）/ 深空（深）/ 晨雾（浅）/ 暖沙（浅）
const List<BuiltinTheme> kBuiltinThemes = [
  BuiltinTheme('night-forest', '夜林', true, AppTokens.nightForest),
  BuiltinTheme('deep-space', '深空', true, AppTokens.deepSpace),
  BuiltinTheme('morning-mist', '晨雾', false, AppTokens.morningMist),
  BuiltinTheme('warm-sand', '暖沙', false, AppTokens.warmSand),
];

/// 由 Token 构建 ThemeData（Material 3）
/// 组件永远通过 context.tokens 取色，ThemeData 只负责桥接系统组件。
ThemeData buildAppTheme(BuiltinTheme theme) {
  final t = theme.tokens;
  final isDark = theme.isDark;
  final base = isDark
      ? ThemeData(useMaterial3: true, brightness: Brightness.dark)
      : ThemeData(useMaterial3: true, brightness: Brightness.light);

  final scheme = ColorScheme(
    brightness: isDark ? Brightness.dark : Brightness.light,
    primary: t.primary,
    onPrimary: isDark ? t.bg : Colors.white,
    primaryContainer: t.surface2,
    onPrimaryContainer: t.text,
    secondary: t.teal,
    onSecondary: isDark ? t.bg : Colors.white,
    surface: t.surface,
    onSurface: t.text,
    surfaceContainerHighest: t.surface2,
    onSurfaceVariant: t.textSub,
    error: t.danger,
    onError: isDark ? t.bg : Colors.white,
    outlineVariant: t.line,
  );

  // 字阶：display 用于倒计时大数字；全局数字等宽（tabular-nums）防跳动
  final textTheme = base.textTheme.copyWith(
    displayLarge: base.textTheme.displayLarge?.copyWith(
      fontSize: 56,
      height: 64 / 56,
      fontWeight: FontWeight.w300,
      letterSpacing: 2,
      fontFeatures: [FontFeature.tabularFigures()],
      color: t.text,
    ),
    titleLarge: base.textTheme.titleLarge
        ?.copyWith(fontSize: 22, height: 30 / 22, fontWeight: FontWeight.w600, color: t.text),
    titleMedium: base.textTheme.titleMedium
        ?.copyWith(fontSize: 17, height: 24 / 17, fontWeight: FontWeight.w600, color: t.text),
    bodyMedium: base.textTheme.bodyMedium
        ?.copyWith(fontSize: 15, height: 22 / 15, color: t.text),
    bodySmall: base.textTheme.bodySmall
        ?.copyWith(fontSize: 13, height: 18 / 13, color: t.textSub),
  );

  return base.copyWith(
    scaffoldBackgroundColor: t.bg,
    colorScheme: scheme,
    extensions: <ThemeExtension<dynamic>>[t],
    textTheme: textTheme,
    splashFactory: InkSparkle.splashFactory,
    dividerTheme: DividerThemeData(color: t.line, thickness: 1),
    sliderTheme: SliderThemeData(
      trackHeight: 4,
      activeTrackColor: t.primary,
      inactiveTrackColor: t.surface2,
      thumbColor: Colors.white,
      // 拇指描边 2pt primary，热区 44pt 由组件层保证
      thumbShape: RoundSliderThumbShape(
        enabledThumbRadius: 10,
        elevation: 0,
        borderWidth: 2,
        borderColor: t.primary,
      ),
      overlayShape: RoundSliderOverlayShape(overlayRadius: 22),
    ),
    tabBarTheme: TabBarTheme(
      labelColor: t.primary,
      unselectedLabelColor: t.textSub,
      dividerColor: t.line,
    ),
    dialogTheme: DialogTheme(
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: textTheme.titleMedium,
      contentTextStyle: textTheme.bodyMedium,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: t.surface2,
      contentTextStyle: textTheme.bodyMedium,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
