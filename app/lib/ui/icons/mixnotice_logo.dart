/// MixNotice 品牌标记（矢量自绘，随主题取色）
///
/// 概念「三叠浪 · 萤火一点」：
///  - 三条振幅递减的声波 = 多轨混音，由「有声」沉入「入静」，轮廓隐含 M（Mix）
///  - 右上琥珀圆点 = Notice（提醒 / 萤火）
///
/// 为什么不贴图：贴图无法跟随主题。这里直接用 AppTokens 取色绘制，
/// 四套内置主题 + 自定义强调色 / 冷暖偏移 / 导入主题都能自动适配，
/// 且 2x/3x 任意缩放都锐利（桌面端无 raster 目录也不用适配多分辨率）。
library;

import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';

/// 画布基准：96×96 设计单位，绘制时按 [size] 等比缩放
const double _kLogoViewSize = 96;

class MixNoticeLogo extends StatelessWidget {
  final double size;

  /// 单色模式：波浪与圆点同用强调色（用于浅色底需要更高对比的场景）
  final bool monochrome;

  const MixNoticeLogo({super.key, this.size = 30, this.monochrome = false});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      label: 'MixNotice',
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size(size, size),
          painter: _LogoPainter(
            wave: t.primary,
            dot: monochrome ? t.primary : t.amber,
          ),
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final Color wave;
  final Color dot;
  const _LogoPainter({required this.wave, required this.dot});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / _kLogoViewSize;
    canvas.save();
    canvas.scale(s);

    // 三叠浪：几何与 brand/app-icon.svg 等比换算（1024 → 96，×0.09375），
    // 振幅自上而下 8.6 / 5.4 / 3.4，周期 141 / 120 / 95，描边 6.2 / 5.4 / 4.9
    void wave1(Canvas c) => c.drawPath(
          _sine(const Offset(21.6, 40.3), halfPeriod: 13.2, amp: 4.3),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = 6.2
            ..color = wave,
        );

    void wave2(Canvas c) => c.drawPath(
          _sine(const Offset(25.5, 54.9), halfPeriod: 11.25, amp: 2.7),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = 5.4
            ..color = wave.withValues(alpha: 0.62),
        );

    void wave3(Canvas c) => c.drawPath(
          _sine(const Offset(30.2, 67.7), halfPeriod: 8.9, amp: 1.7),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = 4.9
            ..color = wave.withValues(alpha: 0.42),
        );

    wave1(canvas);
    wave2(canvas);
    wave3(canvas);

    // Notice：萤火一点（(72.2, 26.2)、半径 4.1，同样由 app-icon 等比换算）
    canvas.drawCircle(const Offset(72.2, 26.2), 4.1, Paint()..color = dot);

    canvas.restore();
  }

  /// 生成 4 段对称二次贝塞尔构成的波浪（与 SVG 的 `q` 命令等价）
  Path _sine(Offset origin, {required double halfPeriod, required double amp}) {
    final p = Path()..moveTo(origin.dx, origin.dy);
    double x = origin.dx;
    double y = origin.dy;
    // 每半个周期一个二次贝塞尔：控制点在起始点水平中位、垂直 ±2×amp 处
    for (var i = 0; i < 4; i++) {
      final up = i.isEven; // 偶数段上凸
      final cx = x + halfPeriod / 2;
      final cy = up ? y - amp * 2 : y + amp * 2;
      final ex = x + halfPeriod;
      p.quadraticBezierTo(cx, cy, ex, y);
      x = ex;
    }
    return p;
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) => old.wave != wave || old.dot != dot;
}
