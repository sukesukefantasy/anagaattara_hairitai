import 'dart:ui';

import 'package:flame/components.dart';

import '../game/world_scale.dart';
import 'game_stage/lighting/camera_viewport_coords.dart';

/// パララックス背景など、奥行きに応じてカメラ zoom の見かけを補正する層。
///
/// [PositionComponent.size] / [PositionComponent.position] はレイアウト用に固定し、
/// 補正は [paintWithDepthZoom] 内の canvas スケールのみで行う（srcSize ピクセル基準）。
/// ズーム中心は [depthZoomFocusWorld]（[CameraController.cameraAnchor]）をローカルへ射影。
mixin DepthZoomVisual on PositionComponent {
  /// プレイフィールドからの奥行き（m）。奥=正、手前=負。
  double get worldDepthMeters;

  /// ズーム拡大の中心（ワールド座標）。null のときは下端中央。
  Vector2? get depthZoomFocusWorld => null;

  /// 描画時にカメラ zoom を打ち消す係数（1 = 補正なし）。
  double depthZoomRenderFactor = 1.0;

  /// ローカル座標（左上原点）でのズームピボット。X=カメラフォーカス、Y=レイヤー下端。
  Vector2 get depthZoomPivotLocal {
    final world = depthZoomFocusWorld;
    if (world != null && isMounted) {
      final local = CameraViewportCoords.worldOffsetToLocal(
        this,
        Offset(world.x, world.y),
      );
      return Vector2(local.dx, size.y);
    }
    return Vector2(size.x / 2, size.y);
  }

  void applyDepthZoom(double cameraZoom, double referenceZoom) {
    depthZoomRenderFactor = WorldScale.depthCompensatingScaleFactor(
      worldDepthMeters,
      cameraZoom,
      referenceZoom,
    );
  }

  /// スプライト描画に奥行きズームを適用する（帯 clip の外側で呼ぶ）。
  void paintWithDepthZoom(Canvas canvas, void Function(Canvas canvas) paint) {
    final factor = depthZoomRenderFactor;
    if ((factor - 1.0).abs() < 1e-6) {
      paint(canvas);
      return;
    }

    final pivot = depthZoomPivotLocal;
    canvas.save();
    canvas.translate(pivot.x, pivot.y);
    canvas.scale(factor);
    canvas.translate(-pivot.x, -pivot.y);
    paint(canvas);
    canvas.restore();
  }
}
