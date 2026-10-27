// 图标预览导出（设计校验用）：把 16 个自绘图标渲染成 PNG，便于目视检查笔画与辨识度
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mixnotice/core/constants.dart';
import 'package:mixnotice/ui/icons/sound_glyph.dart';

void main() {
  testWidgets('导出音源图标预览图', (tester) async {
    tester.view.physicalSize = const Size(1100, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: const Color(0xFF0F1512),
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: Wrap(spacing: 12, runSpacing: 16, children: [
                for (final s in kSounds)
                  SizedBox(
                    width: 120,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      SoundGlyph(s.id, color: const Color(0xFFEAF2EC), size: 72),
                      const SizedBox(height: 6),
                      Text('${s.name}  ·  ${s.id}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF9DB3A6), fontSize: 11)),
                    ]),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final img = await boundary.toImage(pixelRatio: 2);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });
    Directory('build').createSync(recursive: true);
    File('build/glyph_sheet.png').writeAsBytesSync(bytes!);
    expect(File('build/glyph_sheet.png').existsSync(), isTrue);
  });
}
