import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_tokens.dart';
import 'app_themes.dart';
import 'mtheme.dart';

/// ============================================================
/// L3 用户层：主题控制器
/// 规范来源：《UI设计规范-MixNoticeApp-v1.1.md》第八章 8.1 / 8.3
/// 基准主题 + 自定义强调色 + 冷暖基调（背景色相 ±8°）→ 实时生效
/// 持久化：shared_preferences（baseId/accent/warmth），重启后恢复
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
  })  : _base = base ?? kDefaultTheme,
        _accent = accent,
        _warmth = warmth.clamp(-1.0, 1.0);

  BuiltinTheme get base => _base;
  Color? get accent => _accent;
  double get warmth => _warmth;
  bool get isDark => _base.isDark;

  /// 当前最终 tokens（对比度守卫后）。Widget 树通过 buildThemeFromTokens 消费。
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
    _persist();
    notifyListeners();
  }

  /// 自定义强调色；传 null 恢复主题默认
  void setAccent(Color? color) {
    _accent = color;
    _persist();
    notifyListeners();
  }

  /// 冷暖基调：-1 冷 .. 1 暖（背景系色相偏移 ±8°，文字自动反算）
  void setWarmth(double value) {
    _warmth = value.clamp(-1.0, 1.0);
    _persist();
    notifyListeners();
  }

  /// 导入 .mtheme：作为「临时叠加基准」使用（导入即应用，重启后回落上次基准）
  void applyImported(MTheme theme) {
    _base = BuiltinTheme(theme.id, theme.name, theme.isDark, theme.tokens);
    _accent = null;
    _warmth = 0;
    notifyListeners();
  }

  // ---- 持久化（shared_preferences）----
  static const _kBaseId = 'theme.baseId';
  static const _kAccent = 'theme.accentValue';
  static const _kWarmth = 'theme.warmth';

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final id = sp.getString(_kBaseId);
    if (id != null) {
      for (final t in kBuiltinThemes) {
        if (t.id == id) {
          _base = t;
          break;
        }
      }
    }
    final av = sp.getInt(_kAccent);
    _accent = av == null ? null : Color(av);
    _warmth = (sp.getDouble(_kWarmth) ?? 0).clamp(-1.0, 1.0);
  }

  void _persist() {
    SharedPreferences.getInstance().then((sp) {
      sp.setString(_kBaseId, _base.id);
      if (_accent != null) {
        sp.setInt(_kAccent, _accent!.toARGB32());
      } else {
        sp.remove(_kAccent);
      }
      sp.setDouble(_kWarmth, _warmth);
    });
  }

  // ---- 内部实现 ----

  Color _derivePress(Color accent, bool isDark) {
    final hsl = HSLColor.fromColor(accent);
    return hsl.withLightness((hsl.lightness * 0.92).clamp(0.0, 1.0)).toColor();
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
}
