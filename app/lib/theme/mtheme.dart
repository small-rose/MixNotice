import 'dart:convert';

import 'package:flutter/material.dart';

import 'app_tokens.dart';
import 'app_themes.dart' show BuiltinTheme;

/// ============================================================
/// .mtheme 主题文件（L2 扩展）+ 对比度守卫
/// 规范来源：《UI设计规范-MixNoticeApp-v1.1.md》第八章 8.2 / 8.3
/// 规则：
///  - schemaVersion 向后兼容；缺省 token 回落基准主题（不白屏）
///  - primary 对 surface 对比度 < 4.5:1 时自动校正（禁止不可读主题生效）
/// ============================================================

class MThemeFormatException implements Exception {
  final String message;
  const MThemeFormatException(this.message);
  @override
  String toString() => 'MThemeFormatException: $message';
}

class MTheme {
  static const int schemaVersion = 1;
  static const String fileExtension = '.mtheme';

  final String id;
  final String name;
  final bool isDark;
  final AppTokens tokens;

  const MTheme({required this.id, required this.name, required this.isDark, required this.tokens});

  /// 从 JSON 字符串解析。[fallback] 提供缺省 token 的回落基准。
  factory MTheme.fromJson(String raw, {required BuiltinTheme fallback}) {
    final dynamic decoded;
    try {
      decoded = json.decode(raw);
    } catch (_) {
      throw const MThemeFormatException('非法 JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const MThemeFormatException('顶层必须是对象');
    }
    final version = decoded['schemaVersion'];
    if (version is! int || version < 1 || version > schemaVersion) {
      throw MThemeFormatException(
          '不支持的 schemaVersion: $version（当前支持 1..$schemaVersion）');
    }
    final colors = (decoded['colors'] as Map<String, dynamic>?) ?? const {};
    Color pick(String key, Color fb) {
      final v = colors[key];
      return v is String ? _parseHex(v, fb) : fb;
    }

    final base = fallback.tokens;
    final tokens = AppTokens(
      bg: pick('bg', base.bg),
      surface: pick('surface', base.surface),
      surface2: pick('surface2', base.surface2),
      primary: pick('primary', base.primary),
      primaryPress: pick('primaryPress', base.primaryPress),
      amber: pick('amber', base.amber),
      teal: pick('teal', base.teal),
      text: pick('text', base.text),
      textSub: pick('textSub', base.textSub),
      danger: pick('danger', base.danger),
      line: pick('line', base.line),
    );
    return MTheme(
      id: decoded['id'] is String ? decoded['id'] as String : 'imported',
      name: decoded['name'] is String ? decoded['name'] as String : '导入主题',
      isDark: decoded['mode'] == 'dark',
      tokens: tokens.withContrastGuard(),
    );
  }

  String toJson() => json.encode({
        'schemaVersion': schemaVersion,
        'id': id,
        'name': name,
        'mode': isDark ? 'dark' : 'light',
        'colors': {
          'bg': _toHex(tokens.bg),
          'surface': _toHex(tokens.surface),
          'surface2': _toHex(tokens.surface2),
          'primary': _toHex(tokens.primary),
          'primaryPress': _toHex(tokens.primaryPress),
          'amber': _toHex(tokens.amber),
          'teal': _toHex(tokens.teal),
          'text': _toHex(tokens.text),
          'textSub': _toHex(tokens.textSub),
          'danger': _toHex(tokens.danger),
          'line': _toHex(tokens.line),
        },
      });

  /// #RRGGBB / #AARRGGBB；非法值回落 [fb]（不抛异常，保证不白屏）
  static Color _parseHex(String input, Color fb) {
    var hex = input.trim().replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return fb;
    final value = int.tryParse(hex, radix: 16);
    return value == null ? fb : Color(value);
  }

  static String _toHex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
}

/// 对比度守卫：WCAG 相对亮度对比度，primary 对 surface >= 4.5 才放行。
extension AppTokensContrastGuard on AppTokens {
  double _luminance(Color c) => c.computeLuminance();

  double contrastRatio(Color a, Color b) {
    final la = _luminance(a);
    final lb = _luminance(b);
    final lighter = la > lb ? la : lb;
    final darker = la > lb ? lb : la;
    return (lighter + 0.05) / (darker + 0.05);
  }

  Color _scale(Color c, double factor) {
    final v = c.toARGB32();
    final a = (v >> 24) & 0xFF;
    int ch(int x) => (((x * factor).round()).clamp(0, 255));
    return Color.fromARGB(
      a,
      ch((v >> 16) & 0xFF),
      ch((v >> 8) & 0xFF),
      ch(v & 0xFF),
    );
  }

  /// 返回校正后的 tokens。isDark 基准下 primary 不足则逐级加深，浅色反之。
  AppTokens withContrastGuard({double minRatio = 4.5}) {
    final isDark = _luminance(bg) < 0.5;
    var primary = this.primary;
    var text = this.text;
    var textSub = this.textSub;
    const maxIterations = 48;
    const step = 0.97; // 每次缩放 3%

    // primary 守卫
    var i = 0;
    while (contrastRatio(primary, surface) < minRatio && i < maxIterations) {
      primary = isDark ? _scale(primary, 1 / step) : _scale(primary, step);
      i++;
    }
    // text / textSub 守卫
    i = 0;
    while (contrastRatio(text, surface) < minRatio && i < maxIterations) {
      text = isDark ? _scale(text, 1 / step) : _scale(text, step);
      i++;
    }
    i = 0;
    while (contrastRatio(textSub, surface) < minRatio && i < maxIterations) {
      textSub = isDark ? _scale(textSub, 1 / step) : _scale(textSub, step);
      i++;
    }
    // primaryPress：primary 基础上再压一档
    final press = isDark
        ? _scale(primary, 1 / 0.92)
        : _scale(primary, 0.92);
    return copyWith(primary: primary, primaryPress: press, text: text, textSub: textSub);
  }
}
