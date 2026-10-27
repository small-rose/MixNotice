/// 音源线性图标：16 个 24×24 网格、1.8pt 描边、圆头圆角的自绘矢量图标。
/// 替换原先的 emoji 占位（emoji 跨平台渲染不一致、无法单色化、部分音源无对应字形）。
/// 设计约束：统一 24 网格 / stroke 1.8 / StrokeCap.round / StrokeJoin.round；
/// 颜色由外部传入（严格单色），便于「已加入」「试听中」等状态着色。
library;

import 'package:flutter/material.dart';

/// 绘制单个音源图标（纯矢量，无资源文件）
class SoundGlyph extends StatelessWidget {
  final String sourceId;
  final double size;
  final Color color;

  const SoundGlyph(this.sourceId, {super.key, required this.color, this.size = 24});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _GlyphPainter(sourceId, color)),
      );
}

class _GlyphPainter extends CustomPainter {
  final String sourceId;
  final Color color;

  _GlyphPainter(this.sourceId, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    canvas.save();
    canvas.scale(scale);
    for (final p in glyphPaths(sourceId)) {
      canvas.drawPath(p, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.sourceId != sourceId || old.color != color;
}

// ============================================================
// 路径构造
// ============================================================

/// 缓存：图标路径与尺寸无关，构造一次即可
final Map<String, List<Path>> _cache = {};

/// 返回该音源的描边路径（24×24 坐标系）
List<Path> glyphPaths(String id) => _cache.putIfAbsent(id, () => _build(id));

List<Path> _build(String id) {
  switch (id) {
    case 'rain-light':
      return [_cloud(const Offset(12, 8.4)), _drops(const [9.2, 13.4], 3.2)];
    case 'rain-heavy':
      return [_cloud(const Offset(12, 8.2)), _drops(const [6.8, 10.2, 13.6, 17.2], 4.6)];
    case 'thunder':
      return [_cloud(const Offset(12, 8.0)), _bolt()];
    case 'wind':
      return [_wind()];
    case 'stream':
      return [_flow(8.2), _flow(12.4), _flow(16.6)];
    case 'waves':
      return [_waveCrest(), _waveBase(), _foam()];
    case 'birds':
      return [_bird(9.2, 12.6, 5.4, 4.6), _bird(17.4, 8.4, 3.6, 3.1)];
    case 'campfire':
      return [_flameOuter(), _flameInner(), _logs()];
    case 'forest':
      return [_pine(const Offset(7.6, 3.2), 9.6, 10.6), _pine(const Offset(16.6, 8.0), 7.0, 7.6), _ground()];
    case 'night-crickets':
      return [_crescent(), _sparkle(17.6, 14.6, 2.2), _sparkle(20.2, 18.4, 1.6), _grass()];
    case 'noise-white':
      return [_bars(const [4.2, 4.2, 4.2, 4.2, 4.2])];
    case 'noise-pink':
      return [_bars(const [7.0, 6.0, 5.0, 4.2, 3.4])];
    case 'noise-brown':
      return [_bars(const [8.0, 6.2, 4.6, 3.2, 2.2])];
    case 'cafe':
      return [_cup(), _cupHandle(), _saucer(), _steam()];
    case 'keyboard':
      return [_keyboardBody(), _keys()];
    case 'chimes':
      return [_chimeBar(), _chime(8.0, 10.0), _chime(12.0, 13.4), _chime(16.0, 8.6)];
    case 'dog-bark':
      return [_dogHead(), _dogEars(), _dogFace(), _barkArcs(19.4, 15.4)];
    case 'chicken':
      return [_henBody(), _henTail(), _henHead(), _henLegs()];
    case 'goose':
      return [_gooseBody(), _gooseNeck(), _waterline()];
    case 'pond':
      return [_fish(), _fishTail(), _ripple(4.2, 17.6, 8.6), _ripple(12.6, 18.8, 7.0), _drop(9.0, 6.4), _drop(14.6, 5.4)];
    case 'bird-cuckoo':
      return [_perchedBird(10.4, 13.4), _birdHead(14.8, 9.4), _beak(16.5, 9.4), _longTail(), _branch()];
    case 'bird-sparrow':
      return [_perchedBird(10.8, 13.6), _birdHead(14.6, 9.8), _beak(16.2, 9.8), _shortTail(), _groundLine()];
    case 'bird-nightingale':
      return [_perchedBird(9.4, 13.8), _birdHead(13.4, 9.6), _openBeak(15.0, 9.4), _note(), _groundLine()];
    default:
      // 兜底：两声波（未知音源也不空白）
      return [_fallback()];
  }
}

// ---- 云（雨/雷共用）----
Path _cloud(Offset c) {
  final a = Path()..addOval(Rect.fromCircle(center: c + const Offset(-4.4, 0.4), radius: 2.9));
  final b = Path()..addOval(Rect.fromCircle(center: c + const Offset(0.4, -1.4), radius: 3.7));
  final d = Path()..addOval(Rect.fromCircle(center: c + const Offset(4.6, 0.9), radius: 2.5));
  final base = Path()
    ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(c.dx - 7.1, c.dy + 0.6, 14.2, 2.8), const Radius.circular(1.4)));
  var p = Path.combine(PathOperation.union, a, b);
  p = Path.combine(PathOperation.union, p, d);
  return Path.combine(PathOperation.union, p, base);
}

Path _drops(List<double> xs, double len) {
  final p = Path();
  for (final x in xs) {
    p.moveTo(x, 14.4);
    p.lineTo(x - 1.0, 14.4 + len);
  }
  return p;
}

Path _bolt() => Path()
  ..moveTo(13.4, 13.2)
  ..lineTo(10.4, 17.6)
  ..lineTo(12.5, 17.6)
  ..lineTo(11.0, 21.4);

// ---- 风 ----
Path _wind() => Path()
  ..moveTo(3.0, 8.0)
  ..lineTo(12.6, 8.0)
  ..cubicTo(15.4, 8.0, 15.4, 3.7, 12.4, 3.7)
  ..moveTo(3.0, 12.4)
  ..lineTo(15.4, 12.4)
  ..cubicTo(18.7, 12.4, 18.7, 16.9, 15.0, 16.9)
  ..moveTo(3.0, 16.6)
  ..lineTo(8.6, 16.6);

// ---- 溪流：三道细流 ----
Path _flow(double y) => Path()
  ..moveTo(3.0, y)
  ..cubicTo(6.0, y - 1.7, 9.0, y + 1.7, 12.0, y)
  ..cubicTo(15.0, y - 1.7, 18.0, y + 1.7, 21.0, y);

// ---- 海浪：浪头 + 卷曲 + 底浪 + 浪花 ----
Path _waveCrest() => Path()
  ..moveTo(2.8, 16.0)
  ..cubicTo(5.8, 11.6, 9.4, 9.0, 12.8, 10.2)
  ..cubicTo(15.6, 11.2, 14.8, 14.4, 12.3, 14.4)
  ..cubicTo(10.5, 14.4, 10.6, 12.2, 12.4, 12.2);

Path _waveBase() => Path()
  ..moveTo(2.8, 19.8)
  ..cubicTo(5.6, 18.2, 8.4, 21.4, 11.2, 19.8)
  ..cubicTo(14.0, 18.2, 16.8, 21.4, 19.6, 19.8);

Path _foam() => Path()
  ..moveTo(16.8, 7.2)
  ..lineTo(20.0, 7.2)
  ..moveTo(18.4, 9.8)
  ..lineTo(21.0, 9.8);

// ---- 鸟（两段拱形翅膀）----
Path _bird(double cx, double cy, double w, double h) => Path()
  ..moveTo(cx - w, cy)
  ..quadraticBezierTo(cx - w * 0.5, cy - h, cx, cy)
  ..quadraticBezierTo(cx + w * 0.5, cy - h, cx + w, cy);

// ---- 篝火 ----
Path _flameOuter() => Path()
  ..moveTo(12.0, 2.8)
  ..cubicTo(14.8, 6.4, 16.8, 8.4, 16.8, 11.0)
  ..cubicTo(16.8, 13.9, 14.6, 16.0, 12.0, 16.0)
  ..cubicTo(9.4, 16.0, 7.2, 13.9, 7.2, 11.0)
  ..cubicTo(7.2, 8.4, 9.2, 6.4, 12.0, 2.8)
  ..close();

Path _flameInner() => Path()
  ..moveTo(12.0, 9.6)
  ..cubicTo(13.3, 11.3, 14.0, 12.2, 14.0, 13.3)
  ..cubicTo(14.0, 14.5, 13.1, 15.4, 12.0, 15.4)
  ..cubicTo(10.9, 15.4, 10.0, 14.5, 10.0, 13.3)
  ..cubicTo(10.0, 12.2, 10.7, 11.3, 12.0, 9.6);

Path _logs() => Path()
  ..moveTo(5.2, 21.0)
  ..lineTo(14.4, 16.4)
  ..moveTo(18.8, 21.0)
  ..lineTo(9.6, 16.4);

// ---- 森林 ----
Path _pine(Offset tip, double baseY, double halfWidth) {
  final bottom = tip.dy + baseY;
  final x = tip.dx;
  final midY = bottom - baseY * 0.38;
  // 双层塔形轮廓（松树特征：上窄下宽 + 中段收腰）
  final p = Path()
    ..moveTo(x, tip.dy)
    ..lineTo(x + halfWidth * 0.62, midY)
    ..lineTo(x + halfWidth * 0.38, midY)
    ..lineTo(x + halfWidth, bottom)
    ..lineTo(x - halfWidth, bottom)
    ..lineTo(x - halfWidth * 0.38, midY)
    ..lineTo(x - halfWidth * 0.62, midY)
    ..close();
  final trunk = Path()
    ..moveTo(x, bottom)
    ..lineTo(x, bottom + 3.0);
  return Path.combine(PathOperation.union, p, trunk);
}

Path _ground() => Path()
  ..moveTo(2.6, 22.2)
  ..lineTo(21.4, 22.2);

// ---- 夜晚虫鸣：月牙 + 星光 + 草叶 ----
Path _crescent() {
  final outer = Path()..addOval(Rect.fromCircle(center: const Offset(11.0, 9.6), radius: 6.4));
  final cut = Path()..addOval(Rect.fromCircle(center: const Offset(14.4, 6.6), radius: 5.8));
  return Path.combine(PathOperation.difference, outer, cut);
}

Path _sparkle(double cx, double cy, double r) => Path()
  ..moveTo(cx, cy - r)
  ..lineTo(cx, cy + r)
  ..moveTo(cx - r, cy)
  ..lineTo(cx + r, cy);

Path _grass() => Path()
  ..moveTo(5.6, 21.4)
  ..lineTo(6.8, 18.0)
  ..moveTo(9.0, 21.4)
  ..lineTo(9.6, 17.6)
  ..moveTo(12.4, 21.4)
  ..lineTo(11.8, 18.2);

// ---- 噪音：频谱柱（高度分布区分类别）----
Path _bars(List<double> heights) {
  const xs = [4.6, 8.4, 12.2, 16.0, 19.8];
  const baseline = 17.6;
  final p = Path();
  for (var i = 0; i < xs.length; i++) {
    p.moveTo(xs[i], baseline);
    p.lineTo(xs[i], baseline - heights[i]);
  }
  return p;
}

// ---- 咖啡馆 ----
Path _cup() => Path()
  ..moveTo(4.8, 9.6)
  ..lineTo(15.6, 9.6)
  ..lineTo(15.6, 12.4)
  ..cubicTo(15.6, 15.5, 13.2, 17.6, 10.2, 17.6)
  ..cubicTo(7.2, 17.6, 4.8, 15.5, 4.8, 12.4)
  ..close();

Path _cupHandle() => Path()
  ..moveTo(15.6, 10.8)
  ..cubicTo(18.4, 10.8, 18.4, 15.0, 15.6, 15.0);

Path _saucer() => Path()
  ..moveTo(3.4, 20.4)
  ..lineTo(17.0, 20.4);

Path _steam() => Path()
  ..moveTo(8.6, 7.0)
  ..cubicTo(7.4, 5.6, 9.8, 4.8, 8.6, 3.2)
  ..moveTo(12.4, 7.0)
  ..cubicTo(11.2, 5.6, 13.6, 4.8, 12.4, 3.2);

// ---- 键盘 ----
Path _keyboardBody() => Path()
  ..addRRect(RRect.fromRectAndRadius(
      const Rect.fromLTWH(3.2, 7.6, 17.6, 9.6), const Radius.circular(2.2)));

Path _keys() => Path()
  ..moveTo(6.6, 11.0)
  ..lineTo(6.6, 11.0)
  ..moveTo(10.0, 11.0)
  ..lineTo(10.0, 11.0)
  ..moveTo(13.4, 11.0)
  ..lineTo(13.4, 11.0)
  ..moveTo(16.8, 11.0)
  ..lineTo(16.8, 11.0)
  ..moveTo(6.6, 14.0)
  ..lineTo(9.6, 14.0)
  ..moveTo(12.4, 14.0)
  ..lineTo(17.2, 14.0);

// ---- 风铃 ----
Path _chimeBar() => Path()
  ..moveTo(5.6, 4.4)
  ..lineTo(18.4, 4.4);

Path _chime(double x, double ballY) => Path()
  ..moveTo(x, 4.4)
  ..lineTo(x, ballY - 1.6)
  ..addOval(Rect.fromCircle(center: Offset(x, ballY), radius: 1.6));

// ---- 兜底 ----
Path _fallback() => Path()
  ..moveTo(3.4, 12.0)
  ..lineTo(6.0, 12.0)
  ..lineTo(8.2, 6.6)
  ..lineTo(11.4, 17.4)
  ..lineTo(13.8, 10.0)
  ..lineTo(16.0, 12.0)
  ..lineTo(20.6, 12.0);

// ---- 狗：圆脸 + 垂耳 + 眼鼻嘴 ----
Path _dogHead() => Path()
  ..addOval(Rect.fromCenter(center: const Offset(11.4, 13.4), width: 11.0, height: 10.6));

Path _dogEars() => Path()
  ..moveTo(7.0, 9.8)
  ..cubicTo(4.2, 8.0, 3.0, 13.4, 6.4, 15.0)
  ..moveTo(15.8, 9.8)
  ..cubicTo(18.6, 8.0, 19.8, 13.4, 16.4, 15.0);

Path _dogFace() => Path()
  ..moveTo(9.4, 12.6)
  ..lineTo(9.4, 12.61)
  ..moveTo(13.4, 12.6)
  ..lineTo(13.4, 12.61)
  ..moveTo(11.4, 14.6)
  ..lineTo(11.4, 14.61)
  ..moveTo(11.4, 15.4)
  ..lineTo(11.4, 16.2)
  ..moveTo(10.0, 17.0)
  ..quadraticBezierTo(11.4, 18.0, 12.8, 17.0);

/// 叫声弧线（狗/通用）：两道由近及远的声波
Path _barkArcs(double x, double y) => Path()
  ..moveTo(x, y - 1.8)
  ..quadraticBezierTo(x + 1.5, y, x, y + 1.8)
  ..moveTo(x + 1.4, y - 3.0)
  ..quadraticBezierTo(x + 3.9, y, x + 1.4, y + 3.0);

// ---- 母鸡：身椭圆 + 翘尾 + 头冠喙 + 双腿 ----
Path _henBody() => Path()
  ..addOval(Rect.fromCenter(center: const Offset(10.6, 15.6), width: 10.8, height: 8.0));

Path _henTail() => Path()
  ..moveTo(5.6, 13.2)
  ..cubicTo(3.2, 11.2, 3.0, 8.4, 4.4, 6.6)
  ..moveTo(6.4, 12.6)
  ..cubicTo(4.8, 10.8, 4.8, 9.0, 5.8, 7.8);

Path _henHead() => Path()
  ..moveTo(15.2, 12.8)
  ..cubicTo(15.8, 10.8, 16.8, 9.4, 17.8, 8.8)
  ..addOval(Rect.fromCircle(center: const Offset(18.6, 8.2), radius: 1.7))
  ..moveTo(17.4, 6.2)
  ..cubicTo(17.8, 5.0, 18.9, 5.0, 19.2, 6.0)
  ..moveTo(20.2, 7.8)
  ..lineTo(21.6, 8.3)
  ..lineTo(20.1, 8.9);

Path _henLegs() => Path()
  ..moveTo(9.2, 19.6)
  ..lineTo(9.2, 21.6)
  ..moveTo(12.2, 19.5)
  ..lineTo(12.2, 21.6);

// ---- 鹅：长颈浮水 ----
Path _gooseBody() => Path()
  ..addOval(Rect.fromCenter(center: const Offset(9.6, 15.8), width: 10.6, height: 6.4));

Path _gooseNeck() => Path()
  ..moveTo(13.8, 14.4)
  ..cubicTo(14.6, 11.0, 15.0, 8.2, 16.6, 6.8)
  ..addOval(Rect.fromCircle(center: const Offset(17.6, 6.4), radius: 1.5))
  ..moveTo(19.0, 5.9)
  ..lineTo(20.6, 6.4)
  ..lineTo(18.9, 7.0)
  ..moveTo(7.4, 14.0)
  ..lineTo(6.2, 16.4);

Path _waterline() => Path()
  ..moveTo(3.0, 20.4)
  ..cubicTo(5.4, 19.4, 7.4, 21.2, 10.0, 20.4)
  ..cubicTo(12.6, 19.6, 14.6, 21.2, 17.4, 20.4)
  ..cubicTo(18.8, 20.0, 19.8, 20.1, 21.0, 20.5);

// ---- 池塘：鱼 + 水波 + 水珠 ----
Path _fish() => Path()
  ..moveTo(6.2, 11.6)
  ..cubicTo(8.2, 9.2, 12.2, 9.2, 14.8, 11.6)
  ..cubicTo(12.2, 14.0, 8.2, 14.0, 6.2, 11.6)
  ..close()
  ..moveTo(8.6, 11.2)
  ..lineTo(8.6, 11.21);

Path _fishTail() => Path()
  ..moveTo(14.8, 11.6)
  ..lineTo(17.8, 9.8)
  ..lineTo(17.8, 13.4)
  ..close();

Path _ripple(double x, double y, double w) => Path()
  ..moveTo(x, y)
  ..quadraticBezierTo(x + w * 0.25, y - 1.3, x + w * 0.5, y)
  ..quadraticBezierTo(x + w * 0.75, y + 1.3, x + w, y);

Path _drop(double x, double y) => Path()
  ..moveTo(x, y)
  ..lineTo(x, y + 0.01);

// ---- 栖鸟（杜鹃/麻雀/夜莺共用身形）----
Path _perchedBird(double cx, double cy) => Path()
  ..moveTo(cx - 4.8, cy + 1.6)
  ..quadraticBezierTo(cx - 4.4, cy - 3.4, cx, cy - 3.6)
  ..quadraticBezierTo(cx + 4.2, cy - 3.8, cx + 5.0, cy - 0.6)
  ..quadraticBezierTo(cx + 5.4, cy + 2.6, cx + 1.6, cy + 3.4)
  ..quadraticBezierTo(cx - 2.8, cy + 4.2, cx - 4.8, cy + 1.6)
  ..close();

Path _birdHead(double cx, double cy) => Path()
  ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: 1.8));

Path _beak(double x, double y) => Path()
  ..moveTo(x, y - 0.4)
  ..lineTo(x + 1.7, y)
  ..lineTo(x, y + 0.5);

Path _openBeak(double x, double y) => Path()
  ..moveTo(x, y - 0.5)
  ..lineTo(x + 1.6, y - 1.0)
  ..moveTo(x, y + 0.3)
  ..lineTo(x + 1.5, y + 0.6);

Path _longTail() => Path()
  ..moveTo(5.9, 14.6)
  ..lineTo(3.0, 16.8)
  ..moveTo(6.1, 15.9)
  ..lineTo(3.7, 18.5);

Path _shortTail() => Path()
  ..moveTo(6.2, 15.2)
  ..lineTo(3.4, 13.6)
  ..moveTo(6.4, 16.2)
  ..lineTo(4.0, 15.4);

Path _branch() => Path()
  ..moveTo(2.8, 19.2)
  ..lineTo(19.6, 19.2);

Path _groundLine() => Path()
  ..moveTo(4.2, 19.6)
  ..lineTo(18.6, 19.6)
  ..moveTo(6.4, 21.4)
  ..lineTo(7.2, 20.2)
  ..moveTo(15.6, 21.4)
  ..lineTo(15.0, 20.2);

// ---- 音符（夜莺鸣唱）----
Path _note() => Path()
  ..addOval(Rect.fromCircle(center: const Offset(18.8, 6.6), radius: 1.25))
  ..moveTo(20.05, 6.5)
  ..lineTo(20.05, 2.9)
  ..cubicTo(21.0, 3.3, 21.3, 4.1, 20.9, 4.8);
