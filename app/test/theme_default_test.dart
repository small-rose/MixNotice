// 默认主题回归：首次启动必须是浅色「晨雾」（2026-10-26 产品决定，替换原 v1.1 的深色默认）
// 目的：防止后续重构把 kDefaultTheme 改回 kBuiltinThemes.first 而静默回退成深色。
import 'package:flutter_test/flutter_test.dart';

import 'package:mixnotice/theme/app_themes.dart';
import 'package:mixnotice/theme/theme_controller.dart';

void main() {
  test('首次启动默认主题 = 晨雾（浅色）', () {
    final ctrl = AppThemeController();
    expect(ctrl.base.id, 'morning-mist');
    expect(ctrl.base.name, '晨雾');
    expect(ctrl.isDark, isFalse);
    // 浅色主题的底色是暖白，不是纯白（避免刺眼）
    expect(ctrl.tokens.bg.toARGB32(), 0xFFF5F4EF);
  });

  test('显式传 base 时不被默认值覆盖', () {
    final ctrl = AppThemeController(base: kBuiltinThemes.first);
    expect(ctrl.base.id, 'night-forest');
    expect(ctrl.isDark, isTrue);
  });
}
