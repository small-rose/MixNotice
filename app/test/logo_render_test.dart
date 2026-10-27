// Logo 主题适配验证：把矢量标记在 4 套内置主题上渲染成 PNG，确认
// 1) 波浪几何正确（无溢出/错位）2) 颜色随主题 token 变化（非写死贴图）
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mixnotice/theme/app_themes.dart';
import 'package:mixnotice/ui/icons/mixnotice_logo.dart';

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
                  home: Scaffold(body: Center(child: MixNoticeLogo(size: 72))),
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
    expect(find.byType(MixNoticeLogo), findsNWidgets(4));
    expect(tester.takeException(), isNull);
    expect(File('build/ui_logo_themes.png').existsSync(), isTrue);
  });
}
