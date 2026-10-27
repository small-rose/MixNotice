/// 播放态电平条：播放/试听中跳动，静止时低幅静默（无需图片资源）
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

class LevelBars extends StatefulWidget {
  final Color color;
  final bool active;
  final double height;
  final int count;

  const LevelBars({
    super.key,
    required this.color,
    required this.active,
    this.height = 14,
    this.count = 4,
  });

  @override
  State<LevelBars> createState() => _LevelBarsState();
}

class _LevelBarsState extends State<LevelBars> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    if (widget.active) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant LevelBars old) {
    super.didUpdateWidget(old);
    if (widget.active && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.active && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const barW = 2.6;
    const gap = 2.6;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return SizedBox(
          width: widget.count * barW + (widget.count - 1) * gap,
          height: widget.height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(widget.count, (i) {
              final phase = _ctrl.value * 2 * math.pi + i * 0.9;
              final ratio = widget.active ? 0.34 + 0.66 * (0.5 + 0.5 * math.sin(phase)) : 0.28;
              return Container(
                width: barW,
                height: (widget.height * ratio).clamp(2.0, widget.height),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: widget.active ? 0.95 : 0.42),
                  borderRadius: BorderRadius.circular(barW / 2),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
