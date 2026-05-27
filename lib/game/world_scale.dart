import 'dart:math' as math;

import 'package:flame/components.dart';

/// ゲーム世界の単位＝ソース画像の 1px（[size] は原則 [srcSize] と一致）。
///
/// 身長などのメートル定義から [pixelsPerMeter] を決め、屋外横幅は
/// [worldWidthMeters] からゲーム単位へ換算する。
abstract final class WorldScale {
  WorldScale._();

  /// プレイヤー身長の目安（メートル）
  static const double playerHeightMeters = 1.4;

  /// その身長に対応させるプレイヤースプライト基準高さ（テクスチャ px）
  static const double playerSpriteHeightPx = 50;

  /// 1m あたりのゲーム単位（テクスチャ px に相当）
  static const double pixelsPerMeter =
      playerSpriteHeightPx / playerHeightMeters;

  /// 屋外ステージの論理横幅（メートル）
  ///
  /// `84 × (50/1.4) = 3000` ゲーム単位（従来の `MyGame.worldWidth` と一致）
  static const double worldWidthMeters = 84;

  /// [worldWidthMeters] をゲーム単位へ換算した横幅
  static const double worldWidth = worldWidthMeters * pixelsPerMeter;

  /// 論理ステージ右端（ワールド X）。プレイエリアはおおむね `extendedWorldLeft`〜`extendedWorldRight`。
  static const double stageRightX = 0;

  /// 論理ステージ左端（ワールド X）
  static const double stageLeftX = -worldWidth;

  /// ステージ両端からさらに広げる余白（空・地面・環境光ティントの描画範囲）
  static const double horizontalStageExtension = 800;

  /// 環境演出をかける水平範囲の左端
  static const double extendedWorldLeft =
      stageLeftX - horizontalStageExtension;

  /// 環境演出をかける水平範囲の右端
  static const double extendedWorldRight =
      stageRightX + horizontalStageExtension;

  /// 環境演出をかける水平幅
  static const double extendedWorldWidth =
      extendedWorldRight - extendedWorldLeft;

  /// ループ遠景タイル列のワールド原点（index 0 タイルの左端）。
  ///
  /// 右端 [stageRightX] からマイナス X へ [tileWidth] 単位で並べる。
  static double loopBackgroundTileOriginWorldX(double tileWidth) =>
      stageRightX - tileWidth;

  // --- Z 奥行き（メートル）---

  /// プレイヤー足元のプレイフィールド平面
  static const double playfieldDepthMeters = 0;

  /// 近景（電柱など）の目安
  static const double nearForegroundDepthMeters = -4;

  /// 遠景（山・ビル群）の目安
  static const double farMountainDepthMeters = 300;

  /// 空・星空レイヤーの目安
  static const double skyDepthMeters = 500;

  /// referenceZoom（屋外/屋内で設定される基準ズーム）における、カメラの手前距離（m）。
  ///
  /// ズームの「距離感」をパララックスに反映するためのチューニング定数。
  static const double cameraDistanceAtReferenceMeters = 100.0;

  /// 奥行きズーム重み [zoomWeightForDepth] の atan ヒンジ（m）。大きいほど遠景も拡大しやすい。
  static const double zoomWeightHingeMeters = cameraDistanceAtReferenceMeters;

  /// viewfinder.zoom からカメラ手前距離（m）を近似する。
  ///
  /// zoom が大きい（ズームイン）ほど近く、zoom が小さい（ズームアウト）ほど遠くなる。
  static double cameraDistanceMeters(double cameraZoom, double referenceZoom) {
    if (cameraZoom <= 1e-6) {
      return cameraDistanceAtReferenceMeters;
    }
    if (referenceZoom <= 1e-6) {
      return cameraDistanceAtReferenceMeters;
    }
    return cameraDistanceAtReferenceMeters * referenceZoom / cameraZoom;
  }

  /// ワールド座標差（ゲーム単位）をメートルに換算。
  static double worldDistanceMeters(Vector2 a, Vector2 b) {
    return a.distanceTo(b) / pixelsPerMeter;
  }

  /// Z 奥行き（m）からローカルライトの punch 強度（0..1）を求める。
  static double lightingPunchForDepthMeters(double depthMeters) {
    if (depthMeters <= playfieldDepthMeters) {
      return 1.0;
    }
    return (1.0 - depthMeters / farMountainDepthMeters).clamp(0.0, 1.0);
  }

  /// 環境暗転オーバーレイ（全画面）の priority
  static const int lightingOverlayRenderPriority = 55;

  /// ローカルライト relight（full 参加者のスプライト形状・減衰帯）の priority
  static const int localLightOverlayRenderPriority = 56;

  static const double _renderPriorityBaseAtPlayfield = 40;
  static const double _farDepthPriorityScale = 0.126;
  static const double _nearDepthPriorityScale = 15.0;

  /// 奥行き [depthMeters] から Flame の描画 priority を導出する。
  ///
  /// 正 = 奥（小さい priority）、0 = プレイ面、負 = 手前（大きい priority）。
  static int renderPriorityForDepth(
    double depthMeters, {
    int? override,
  }) {
    if (override != null) {
      return override;
    }
    if (depthMeters < playfieldDepthMeters) {
      return (_renderPriorityBaseAtPlayfield +
              (playfieldDepthMeters - depthMeters) * _nearDepthPriorityScale)
          .round()
          .clamp(lightingOverlayRenderPriority + 1, 120);
    }
    return (_renderPriorityBaseAtPlayfield -
            depthMeters * _farDepthPriorityScale)
        .round()
        .clamp(1, lightingOverlayRenderPriority - 1);
  }

  /// 奥行きズームの影響重み（0..1）。手前=1、遠いほど小さい（atan で滑らかに減衰）。
  ///
  /// 屋内 [DepthZoomVisual] と屋外 [Pseudo3DCamera.depthZoomRenderFactor] で使用。
  ///
  /// パララックス scroll とは別。没入感調整は [zoomWeightHingeMeters] を変更する。
  static double zoomWeightForDepth(double depthMeters) {
    if (depthMeters <= playfieldDepthMeters) {
      return 1.0;
    }
    return (2.0 / math.pi * math.atan(zoomWeightHingeMeters / depthMeters))
        .clamp(0.0, 1.0);
  }

  /// 深度 [depthMeters] における見かけのカメラ zoom（[referenceZoom] 基準の線形補間）。
  static double effectiveZoomAtDepth(
    double depthMeters,
    double cameraZoom,
    double referenceZoom,
  ) {
    if (cameraZoom <= 0 || referenceZoom <= 0) {
      return cameraZoom;
    }
    final w = zoomWeightForDepth(depthMeters);
    return referenceZoom + (cameraZoom - referenceZoom) * w;
  }

  /// 均一 viewfinder zoom を打ち消すコンポーネント scale 係数（XY 同一）。
  static double depthCompensatingScaleFactor(
    double depthMeters,
    double cameraZoom,
    double referenceZoom,
  ) {
    if (cameraZoom <= 0) {
      return 1.0;
    }
    return effectiveZoomAtDepth(depthMeters, cameraZoom, referenceZoom) /
        cameraZoom;
  }
}
