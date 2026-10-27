import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_tokens.dart';
import 'app_themes.dart';
import 'mtheme.dart';

/// ============================================================
/// L3 用户层：主题控制器
/// 规范来源：《UI设计规范-MixNoticeApp-v1.1.md》第八章 8.1 / 8.3
/// 基准主题 + 自定义强调色 + 冷暖基调（背景色相 ±8°）→ 实时生效
/// 持久化：接入工程时用 shared_preferences 存 baseId/accent/warmth（见 TODO）
/// ============================================================

class AppThemeController extends ChangeNotifier {
  BuiltinTheme _base;
  Color? _accent; // null = 使用主题默认 primary
  double _warmth; // -1(冷) .. 1(暖)，映射背景色相 ±8°
  bool followSystem;

  AppThemeController({
    BuiltinTheme? base,
    Color? accent,
    double warmth = 0,
    this.followSystem = true,
  })  : _base = base ?? kBuiltinThemes.first,
        _accent = accent,
        _warmth = warmth.clamp(-1.0, 1.0);

  BuiltinTheme get base => _base;
  Color? get accent => _accent;
  double get warmth => _warmth;

  /// 当前最终 tokens（对比度守卫后）。Widget 树通过 buildAppTheme(tokens) 消费。
  AppTokens get tokens {
    var t = _base.tokens;
    if (_accent != null) {
      t = t.copyWith(
        primary: _accent,
        primaryPress: _derivePress(_accent!, _base.isDark),
      );
    }
    if (_warmth != 0) t = _applyWarmth(t, _warmth);
    return t.withContrastGuard();
  }

  void setBase(BuiltinTheme theme) {
    _base = theme;
    notifyListeners();
  }

  /// 自定义强调色；传 null 恢复主题默认
  void setAccent(Color? color) {
    _accent = color;
    notifyListeners();
  }

  /// 冷暖基调：-1 冷 .. 1 暖（背景系色相偏移 ±8°，文字自动反算）
  void setWarmth(double value) {
    _warmth = value.clamp(-1.0, 1.0);
    notifyListeners();
  }

  /// 导入 .mtheme：内置主题无用户主题存储位，工程接入后落本地库；
  /// MVP 先作为「临时叠加基准」使用（导入即应用）。
  void applyImported(MTheme theme) {
    _base = BuiltinTheme(theme.id, theme.name, theme.isDark, theme.tokens);
    notifyListeners();
  }

  // ---- 内部实现 ----

  Color _derivePress(Color accent, bool isDark) {
    final hsl = HSLColor.fromColor(accent);
    return (isDark
            ? hsl.withLightness((hsl.lightness * 0.92).clamp(0.0, 1.0))
            : hsl.withLightness((hsl.lightness * 0.92).clamp(0.0, 1.0)))
        .toColor();
  }

  /// 冷暖：对 bg/surface/surface2 色相偏移 warmth*8°；primary/text 不动
  AppTokens _applyWarmth(AppTokens t, double warmth) {
    Color shift(Color c) {
      final hsl = HSLColor.fromColor(c);
      final hue = (hsl.hue + warmth * 8) % 360;
      return hsl.withHue(hue < 0 ? hue + 360 : hue).toColor();
    }

    return t.copyWith(bg: shift(t.bg), surface: shift(t.surface), surface2: shift(t.surface2));
  }

  // ---- 持久化（工程接入时实现）----
  // TODO(V1.0 工程): 接入 shared_preferences
  // Future<void> load() async { ... baseId/accentValue/warmth/followSystem ... }
  // Future<void> _persist() async { ... }
}
