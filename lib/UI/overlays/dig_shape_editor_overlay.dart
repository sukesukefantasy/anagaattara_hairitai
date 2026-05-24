import 'dart:math' show min;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../component/common/terrain/dig_shape_template.dart';
import '../../system/dig_shape_editor_controller.dart';

/// 掘削断面をドラッグ描画するフルスクリーンオーバーレイ。
class DigShapeEditorOverlay extends StatelessWidget {
  final DigShapeEditorController controller;
  final DigShapeTemplate? savedTemplate;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final VoidCallback onClear;
  final VoidCallback onRestoreDefault;

  const DigShapeEditorOverlay({
    super.key,
    required this.controller,
    this.savedTemplate,
    required this.onConfirm,
    required this.onCancel,
    required this.onClear,
    required this.onRestoreDefault,
  });

  static double get _guideRadiusPx => DigShapeTemplate.customDigRadiusPx;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.72),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    '掘削の断面を選ぶ／描く',
                    style: TextStyle(
                      color: Colors.amber.shade200,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'テンプレートまたは手書き・中央の円は半径 ${_guideRadiusPx.toInt()}px',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const horizontalMargin = 32.0;
                  final side = min(
                    constraints.maxWidth - horizontalMargin,
                    constraints.maxHeight,
                  ).clamp(120.0, 480.0);
                  final canvasSize = Size(side, side);

                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: horizontalMargin / 2,
                      ),
                      child: ValueListenableBuilder<int>(
                        valueListenable: controller.previewTick,
                        builder: (context, _, __) {
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanStart: (d) => _handleDrag(
                              d.localPosition,
                              canvasSize,
                            ),
                            onPanUpdate: (d) => _handleDrag(
                              d.localPosition,
                              canvasSize,
                            ),
                            child: Container(
                              width: side,
                              height: side,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.45),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.amber.withOpacity(0.45),
                                ),
                              ),
                              child: CustomPaint(
                                size: canvasSize,
                                painter: _DigShapeEditorPainter(
                                  points: controller.drawPointsNormalized,
                                  previewTemplate: controller.previewTemplate,
                                  savedTemplate: savedTemplate,
                                  guideDigRadiusPx: _guideRadiusPx,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildPresetBar(),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: onClear,
                    child: const Text('描き直し', style: TextStyle(fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: onRestoreDefault,
                    child: const Text('元の円', style: TextStyle(fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: onCancel,
                    child: const Text('キャンセル', style: TextStyle(fontSize: 12)),
                  ),
                  FilledButton(
                    onPressed: onConfirm,
                    child: const Text('確定', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetBar() {
    final presets = DigShapeTemplate.builtInPresets;
    final freehandSelected =
        controller.isFreehandMode &&
        controller.drawPointsNormalized.isEmpty &&
        controller.previewTemplate == null;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        ChoiceChip(
          label: const Text('手書き', style: TextStyle(fontSize: 11)),
          selected: freehandSelected,
          onSelected: (_) => controller.useFreehand(),
          visualDensity: VisualDensity.compact,
        ),
        for (var i = 0; i < presets.length; i++)
          ChoiceChip(
            label: Text(presets[i].label, style: const TextStyle(fontSize: 11)),
            selected: controller.selectedPresetIndex == i,
            onSelected: (_) => controller.selectPreset(i),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }

  void _handleDrag(Offset localPos, Size canvasSize) {
    if (canvasSize.width < 1 || canvasSize.height < 1) return;
    controller.addDrawPointNormalized(
      Vector2(
        (localPos.dx / canvasSize.width).clamp(0.0, 1.0),
        (localPos.dy / canvasSize.height).clamp(0.0, 1.0),
      ),
    );
  }
}

class _DigShapeEditorPainter extends CustomPainter {
  final List<Vector2> points;
  final DigShapeTemplate? previewTemplate;
  final DigShapeTemplate? savedTemplate;
  final double guideDigRadiusPx;

  _DigShapeEditorPainter({
    required this.points,
    required this.previewTemplate,
    required this.savedTemplate,
    required this.guideDigRadiusPx,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintDigRadiusGuide(canvas, size);

    if (previewTemplate != null) {
      _paintTemplateOutline(
        canvas,
        size,
        previewTemplate!.verticesLocal,
        Colors.cyanAccent,
        strokeWidth: 2.5,
        fill: Colors.cyan.withOpacity(0.12),
      );
    }
    if (savedTemplate != null) {
      _paintTemplateOutline(
        canvas,
        size,
        savedTemplate!.verticesLocal,
        Colors.white24,
        strokeWidth: 1,
        fill: null,
      );
    }

    final stroke = Paint()
      ..color = Colors.amber
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    if (points.length >= 2) {
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final px = points[i].x * size.width;
        final py = points[i].y * size.height;
        if (i == 0) {
          path.moveTo(px, py);
        } else {
          path.lineTo(px, py);
        }
      }
      canvas.drawPath(path, stroke);
    }
    final dot = Paint()..color = Colors.amber.shade200;
    for (final p in points) {
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        3,
        dot,
      );
    }
  }

  void _paintDigRadiusGuide(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final r = guideDigRadiusPx;

    final fill = Paint()..color = Colors.white.withOpacity(0.04);
    canvas.drawCircle(center, r, fill);

    final ring = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, r, ring);

    final dash = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(center.dx - r, center.dy),
      Offset(center.dx + r, center.dy),
      dash,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - r),
      Offset(center.dx, center.dy + r),
      dash,
    );

    final label = TextPainter(
      text: TextSpan(
        text: 'R${guideDigRadiusPx.toInt()}',
        style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(
      canvas,
      Offset(center.dx + r + 4, center.dy - label.height / 2),
    );
  }

  void _paintTemplateOutline(
    Canvas canvas,
    Size size,
    List<Vector2> localVerts,
    Color color, {
    required double strokeWidth,
    Color? fill,
  }) {
    if (localVerts.length < 3) return;
    var minX = double.infinity;
    var maxX = -double.infinity;
    var minY = double.infinity;
    var maxY = -double.infinity;
    for (final v in localVerts) {
      if (v.x < minX) minX = v.x;
      if (v.x > maxX) maxX = v.x;
      if (v.y < minY) minY = v.y;
      if (v.y > maxY) maxY = v.y;
    }
    final cx = (minX + maxX) * 0.5;
    final cy = (minY + maxY) * 0.5;
    final halfW = (maxX - minX) * 0.5;
    final halfH = (maxY - minY) * 0.5;
    final normScale = halfW > halfH ? halfW : halfH;
    if (normScale < 1e-6) return;

    final centerX = size.width * 0.5;
    final centerY = size.height * 0.5;
    final drawScale = guideDigRadiusPx / normScale;

    final path = Path();
    for (var i = 0; i < localVerts.length; i++) {
      final lx = (localVerts[i].x - cx) * drawScale + centerX;
      final ly = (localVerts[i].y - cy) * drawScale + centerY;
      if (i == 0) {
        path.moveTo(lx, ly);
      } else {
        path.lineTo(lx, ly);
      }
    }
    path.close();
    if (fill != null) {
      canvas.drawPath(path, Paint()..color = fill);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _DigShapeEditorPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.previewTemplate != previewTemplate ||
      oldDelegate.savedTemplate != savedTemplate ||
      oldDelegate.guideDigRadiusPx != guideDigRadiusPx;
}
