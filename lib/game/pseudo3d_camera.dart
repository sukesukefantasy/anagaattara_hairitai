import 'dart:ui';

import 'package:flame/components.dart';

import '../component/game_stage/lighting/camera_viewport_coords.dart';
import 'world_scale.dart';

/// 屋外背景用の疑似3D射影カメラ。
///
/// - **パン**: `s = D/(D+z)` で描画 X のみ射影（[referenceZoom] 固定、viewfinder 非連動）
/// - **ズーム**: [depthZoomRenderFactor] で奥行きごとに viewfinder への追従を弱める
///   （[referenceZoom] では係数 1 = [BackgroundData.srcSize] そのまま）
class Pseudo3DCamera {
  const Pseudo3DCamera({
    required this.focusWorldX,
    required this.referenceZoom,
    required this.viewfinderZoom,
  });

  /// カメラフォーカス（通常 [CameraController.cameraAnchor].x）。
  final double focusWorldX;

  final double referenceZoom;

  final double viewfinderZoom;

  /// viewfinder 均一ズームに対する奥行き別の描画スケール（1 = 補正なし）。
  ///
  /// [WorldScale.depthCompensatingScaleFactor] — referenceZoom では常に 1。
  double depthZoomRenderFactor(double depthMeters) {
    return WorldScale.depthCompensatingScaleFactor(
      depthMeters,
      viewfinderZoom,
      referenceZoom,
    );
  }

  /// ローカル座標のピボット周りに奥行きズーム（canvas.scale）を適用する。
  ///
  /// ピボットはカメラフォーカス X・レイヤー下端（[depthZoomPivotLocal]）を推奨。
  static void paintWithDepthZoomAtPivot(
    Canvas canvas, {
    required double factor,
    required double pivotLocalX,
    required double pivotLocalY,
    required void Function(Canvas canvas) paint,
  }) {
    if ((factor - 1.0).abs() < 1e-6) {
      paint(canvas);
      return;
    }
    canvas.save();
    canvas.translate(pivotLocalX, pivotLocalY);
    canvas.scale(factor);
    canvas.translate(-pivotLocalX, -pivotLocalY);
    paint(canvas);
    canvas.restore();
  }

  /// 奥行きスケール s = D/(D+z)。プレイ面 z<=0 は 1。
  ///
  /// D は referenceZoom 時のカメラ距離（パン用パララックスのみ、ズーム非連動）。
  double depthScale(double depthMeters) {
    if (depthMeters <= WorldScale.playfieldDepthMeters) {
      return 1.0;
    }
    final dCam = WorldScale.cameraDistanceMeters(
      referenceZoom,
      referenceZoom,
    );
    return (dCam / (dCam + depthMeters)).clamp(0.0, 1.0);
  }

  /// 真のワールド X を奥行き込みの描画用 X へ射影する。
  ///
  /// focus + (wx - focus) * s により、パン時の見かけ速度は (1-s)。
  double projectedWorldX(double trueWorldX, double depthMeters) {
    final s = depthScale(depthMeters);
    return focusWorldX + (trueWorldX - focusWorldX) * s;
  }

  /// 奥行きズームの canvas ピボット（ローカル: フォーカス X、レイヤー下端 Y）。
  Vector2 depthZoomPivotLocal(double componentWorldLeft, double layerHeight) {
    return Vector2(focusWorldX - componentWorldLeft, layerHeight);
  }

  /// パララックスで見かけ位置が広がる分、真ワールドのタイル走査範囲を拡張する。
  Rect expandedVisibleWorld(Rect cameraVisible, double depthMeters) {
    final s = depthScale(depthMeters);
    if ((s - 1.0).abs() < 1e-6) {
      return cameraVisible;
    }
    return CameraViewportCoords.inflateWorldRectHorizontally(
      cameraVisible,
      1.0 / s,
      focusWorldX,
    );
  }
}
