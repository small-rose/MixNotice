// Logo 主题适配验证：把矢量标记在 4 套内置主题上渲染成 PNG，确认
// 1) 波浪几何正确（无溢出/错位）2) 颜色随主题 token 变化（非写死贴图）
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sough_mix/theme/app_themes.dart';
import 'package:sough_mix/ui/icons/soughmix_logo.dart';

Future<void> _dump(WidgetTester tester, GlobalKey key, String name) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final img = await boundary.toImage(pixelRatio: 3);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }) as Uint8List;
  Directory('build').createSync(recursive: true);
  File('build/$name.png').writeAsBytesSync(bytes);
}

void main() {
  testWidgets('Logo 在四套主题下取色并渲染', (tester) async {
    tester.view.physicalSize = const Size(560, 170);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Row(
          children: [
            for (final th in kBuiltinThemes)
              Expanded(
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: buildAppTheme(th),
                  home: Scaffold(body: Center(child: SoughMixLogo(size: 72))),
                ),
              ),
          ],
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await _dump(tester, key, 'ui_logo_themes');

    // 单态是否存在、且四套主题渲染无异常
    expect(find.byType(SoughMixLogo), findsNWidgets(4));
    expect(tester.takeException(), isNull);
    expect(File('build/ui_logo_themes.png').existsSync(), isTrue);
  });

  test('Logo 取色策略：auto 跟随主题，dark / light 为固定品牌色', () {
    final light = kBuiltinThemes.firstWhere((t) => t.id == 'morning-mist').tokens;
    final dark = kBuiltinThemes.firstWhere((t) => t.id == 'night-forest').tokens;

    // auto：跟随当前主题 token
    expect(resolveLogoColors(LogoStyle.auto, light).$1, light.primary);
    expect(resolveLogoColors(LogoStyle.auto, dark).$1, dark.primary);

    // 强制变体：与主题无关，固定取品牌色
    expect(resolveLogoColors(LogoStyle.dark, dark).$1, kLogoInkDark);
    expect(resolveLogoColors(LogoStyle.dark, dark).$2, kLogoDotDark);
    expect(resolveLogoColors(LogoStyle.light, light).$1, kLogoInkLight);
    expect(resolveLogoColors(LogoStyle.light, light).$2, kLogoDotLight);

    // 单色模式：圆点与波浪同色
    final (monoWave, monoDot) = resolveLogoColors(LogoStyle.light, light, monochrome: true);
    expect(monoDot, monoWave);
  });
}
