import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../../game/world_scale.dart';

/// カメラ可視域と viewport HUD 座標の変換。
///
/// viewport 子（暗転の上のローカル光等）の [render] では viewfinder 変換は
/// canvas に掛かっていない。そのためワールド点は [Viewfinder.localToGlobal] で
/// スクリーン（viewport 内）座標へ変換してから描く。
abstract final class CameraViewportCoords {
  CameraViewportCoords._();

  /// ワールド座標 → viewport HUD 上のスクリーン座標（px）。
  static Vector2 worldToScreen(CameraComponent camera, Vector2 world) {
    return camera.viewfinder.localToGlobal(world);
  }

  /// 互換エイリアス（シェーダー uniform 用）。
  static Vector2 worldToViewportLocal(CameraComponent camera, Vector2 world) =>
      worldToScreen(camera, world);
  static Rect worldRectToScreenRect(CameraComponent camera, Rect world) {
    final topLeft = worldToScreen(camera, Vector2(world.left, world.top));
    final bottomRight = worldToScreen(
      camera,
      Vector2(world.right, world.bottom),
    );
    return Rect.fromLTRB(
      topLeft.x,
      topLeft.y,
      bottomRight.x,
      bottomRight.y,
    );
  }

  /// カメラ可視域をワールド座標 Rect で返す。
  static Rect visibleWorldDrawRect(
    CameraComponent camera, {
    double paddingScreenPx = 0,
  }) {
    final vis = camera.visibleWorldRect;
    if (paddingScreenPx <= 0) {
      return vis;
    }
    final padWorld = paddingScreenPx / camera.viewfinder.zoom;
    return Rect.fromLTRB(
      vis.left - padWorld,
      vis.top - padWorld,
      vis.right + padWorld,
      vis.bottom + padWorld,
    );
  }

  /// ループ遠景・中景用: カメラ可視 X ∩ ステージ幅 [stageLeftX, stageRightX]。
  ///
  /// カメラ可動域（[WorldScale.worldWidth] = stageRightX - stageLeftX）外は描画・暗化の対象外。
  static Rect loopStageVisibleWorldRect(Rect cameraVisible) {
    final left = math.max(cameraVisible.left, WorldScale.stageLeftX);
    final right = math.min(cameraVisible.right, WorldScale.stageRightX);
    if (right <= left) {
      return Rect.zero;
    }
    return Rect.fromLTRB(
      left,
      cameraVisible.top,
      right,
      cameraVisible.bottom,
    );
  }

  /// ワールド矩形を [pivotWorldX] 周りに水平 [scale] 倍へ拡張（ステージ X にクランプ）。
  static Rect inflateWorldRectHorizontally(
    Rect rect,
    double scale,
    double pivotWorldX,
  ) {
    if (scale <= 1.0 || rect.isEmpty) {
      return rect;
    }
    final newLeft = pivotWorldX + (rect.left - pivotWorldX) * scale;
    final newRight = pivotWorldX + (rect.right - pivotWorldX) * scale;
    final left = math.max(newLeft, WorldScale.stageLeftX);
    final right = math.min(newRight, WorldScale.stageRightX);
    if (right <= left) {
      return Rect.zero;
    }
    return Rect.fromLTRB(left, rect.top, right, rect.bottom);
  }

  /// 奥行きズーム後も帯 clip が画面内に食い込まないよう、ローカル帯をピボット周りに拡張。
  static Rect inflateBandForDepthZoom(
    Rect band,
    double factor,
    Vector2 pivotLocal,
  ) {
    if ((factor - 1.0).abs() < 1e-6 || band.isEmpty) {
      return band;
    }
    final scale = 1.0 / factor;
    double mapX(double x) => pivotLocal.x + (x - pivotLocal.x) * scale;
    return Rect.fromLTRB(
      mapX(band.left),
      band.top,
      mapX(band.right),
      band.bottom,
    );
  }

  /// [GameStageComponent.loop] の環境暗化／clip 帯（[loopStageVisibleWorldRect] 基準）。
  static Rect visibleLoopLayerBandLocal(
    PositionComponent receiver,
    CameraComponent camera,
  ) {
    if (!receiver.isMounted) {
      return Rect.zero;
    }

    final vis = loopStageVisibleWorldRect(camera.visibleWorldRect);
    if (vis.isEmpty) {
      return Rect.zero;
    }

    final worldY = receiver.toAbsoluteRect().top + receiver.size.y * 0.5;
    final localLeft =
        worldOffsetToLocal(receiver, Offset(vis.left, worldY)).dx;
    final localRight =
        worldOffsetToLocal(receiver, Offset(vis.right, worldY)).dx;

    final h = receiver.size.y;
    final left = math.min(localLeft, localRight);
    final right = math.max(localLeft, localRight);
    if (right <= left) {
      return Rect.zero;
    }
    return Rect.fromLTRB(left, 0, right, h);
  }

  /// 横長ストリップ（地面・地下）: カメラ可視 X をコンポーネントローカル帯に変換。
  ///
  /// Y 交差は使わない（ズーム時に細い地面帯が落ちるのを防ぐ）。
  /// 描画・環境暗化・タイル範囲はすべてこの矩形のみを参照する。
  static Rect visibleHorizontalBandLocal(
    PositionComponent receiver,
    CameraComponent camera, {
    bool clampToComponentWidth = true,
  }) {
    if (!receiver.isMounted) {
      return Rect.zero;
    }

    final vis = camera.visibleWorldRect;
    final world = receiver.toAbsoluteRect();

    final overlapLeft = math.max(vis.left, world.left);
    final overlapRight = math.min(vis.right, world.right);
    if (overlapRight <= overlapLeft) {
      return Rect.zero;
    }

    final worldY = world.top + world.height * 0.5;
    final localLeft =
        worldOffsetToLocal(receiver, Offset(overlapLeft, worldY)).dx;
    final localRight =
        worldOffsetToLocal(receiver, Offset(overlapRight, worldY)).dx;

    final h = receiver.size.y;
    final left = math.min(localLeft, localRight);
    final right = math.max(localLeft, localRight);
    if (clampToComponentWidth) {
      final w = receiver.size.x;
      final clampedLeft = left.clamp(0.0, w);
      final clampedRight = right.clamp(0.0, w);
      if (clampedRight <= clampedLeft) {
        return Rect.zero;
      }
      return Rect.fromLTRB(clampedLeft, 0, clampedRight, h);
    }
    if (right <= left) {
      return Rect.zero;
    }
    return Rect.fromLTRB(left, 0, right, h);
  }

  /// ワールド可視域 ∩ [receiver] の絶対矩形をコンポーネントローカル座標に変換。
  static Rect intersectVisibleLocalRect(
    PositionComponent receiver,
    CameraComponent camera, {
    double paddingScreenPx = 0,
    double paddingWorld = 0,
  }) {
    var vis = visibleWorldDrawRect(
      camera,
      paddingScreenPx: paddingScreenPx,
    );
    if (paddingWorld > 0) {
      vis = Rect.fromLTRB(
        vis.left - paddingWorld,
        vis.top - paddingWorld,
        vis.right + paddingWorld,
        vis.bottom + paddingWorld,
      );
    }

    final world = receiver.toAbsoluteRect();
    final hit = vis.intersect(world);
    if (hit.isEmpty || hit.width <= 0 || hit.height <= 0) {
      return Rect.zero;
    }

    final corners = [
      Offset(hit.left, hit.top),
      Offset(hit.right, hit.top),
      Offset(hit.left, hit.bottom),
      Offset(hit.right, hit.bottom),
    ];

    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;

    for (final corner in corners) {
      final local = worldOffsetToLocal(receiver, corner);
      minX = math.min(minX, local.dx);
      minY = math.min(minY, local.dy);
      maxX = math.max(maxX, local.dx);
      maxY = math.max(maxY, local.dy);
    }

    final w = receiver.size.x;
    final h = receiver.size.y;
    final left = minX.clamp(0.0, w);
    final top = minY.clamp(0.0, h);
    final right = maxX.clamp(0.0, w);
    final bottom = maxY.clamp(0.0, h);
    if (right <= left || bottom <= top) {
      return Rect.zero;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// [visibleHorizontalBandLocal] のエイリアス（既存呼び出し互換）。
  static Rect intersectVisibleLocalRectForStrip(
    PositionComponent receiver,
    CameraComponent camera, {
    double paddingScreenPx = 0,
    double paddingWorld = 0,
  }) {
    // padding は描画帯には使わない（ランタン判定は Renderer 側で inflate）。
    return visibleHorizontalBandLocal(receiver, camera);
  }

  static Offset worldOffsetToLocal(
    PositionComponent receiver,
    Offset world,
  ) {
    final local = receiver.toLocal(Vector2(world.dx, world.dy));
    return Offset(local.x, local.y);
  }
}
