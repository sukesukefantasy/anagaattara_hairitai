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

  /// 論理ステージ右端（ワールド X）。
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

  /// 屋外カメラのクランプ境界（左右）。
  ///
  /// 地面・空・遠景ループの有効範囲と同じ境界を使うことで、
  /// 端で黒帯が見えるケースを避ける。
  static const double cameraBoundLeftX = extendedWorldLeft;
  static const double cameraBoundRightX = extendedWorldRight;

  /// ループ遠景の横カバレッジ幅（カメラ境界に一致）。
  static const double loopHorizontalCoverageWidth =
      cameraBoundRightX - cameraBoundLeftX;

  /// ステージ幅を [tileW] で覆うのに必要なタイル枚数（切り上げ）。
  static int loopStageTileCount(double tileW) {
    if (tileW < 1) {
      return 0;
    }
    return (loopHorizontalCoverageWidth / tileW).ceil();
  }

  /// 1 周期のワールド幅（= [loopStageTileCount] × [tileW]）。
  static double loopStageTilePeriod(double tileW) =>
      loopStageTileCount(tileW) * tileW;

  /// 描画スロット [slot] のタイル左端（[srcSize.x] 1 枚ぶんそのまま配置）。
  ///
  /// ステージ内 [loopStageTileCount] 枚は [cameraBoundRightX] に右端揃え。
  /// slot 0 が最左、slot count-1 が右端ぴったり。
  static double loopStageTileTrueLeft(int slot, double tileW) {
    final count = loopStageTileCount(tileW);
    if (count <= 0) {
      return cameraBoundLeftX;
    }
    return cameraBoundRightX - (count - slot) * tileW;
  }

  /// タイル列のワールド左端と幅（水平ループ [GameStageComponent] の size / position 用）。
  static ({double left, double width}) loopStageStripBounds(
    double tileW, {
    int marginSlots = 0,
  }) {
    final count = loopStageTileCount(tileW);
    if (count <= 0) {
      return (left: cameraBoundLeftX, width: 0);
    }
    final slots = loopStagePaintSlotRange(count, marginSlots: marginSlots);
    final left = loopStageTileTrueLeft(slots.start, tileW);
    final right = loopStageTileTrueLeft(slots.endInclusive, tileW) + tileW;
    return (left: left, width: right - left);
  }

  /// ループ遠景の描画スロット範囲（ステージ内タイル + 片側 [marginSlots] 余白）。
  static ({int start, int endInclusive}) loopStagePaintSlotRange(
    int tileCount, {
    int marginSlots = 0,
  }) {
    if (tileCount <= 0) {
      return (start: 0, endInclusive: -1);
    }
    return (
      start: -marginSlots,
      endInclusive: tileCount + marginSlots - 1,
    );
  }

  /// ループ遠景タイル列のワールド原点（ステージ最左タイルの左端）。
  static double loopBackgroundTileOriginWorldX(double tileWidth) =>
      loopStageTileTrueLeft(0, tileWidth);

  // --- Z 奥行き（メートル）---

  /// プレイヤー足元のプレイフィールド平面
  static const double playfieldDepthMeters = 0;

  /// 近景（電柱など）の目安
  static const double nearForegroundDepthMeters = -4;

  /// 遠景（山・ビル群）の目安
  static const double farMountainDepthMeters = 300;

  /// 空・星空レイヤーの目安
  static const double skyDepthMeters = 1000;

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

  /// プレイ面（depth=0）の描画 priority。
  static const int renderPriorityAtPlayfield = 35;

  /// 最遠（[skyDepthMeters]）の描画 priority。
  static const int renderPriorityAtSky = 1;

  /// 手前（depth &lt; 0）方向の priority 増分（1m あたり）。
  static const double renderPriorityNearScalePerMeter = 2.5;

  /// 建物・駅などプレイ面上の立体（地面スプライトよりわずかに手前）。
  static const double buildingDepthMeters = -0.5;

  /// 自動化キット（建物より手前・プレイヤーより奥）。
  static const double automationKitDepthMeters = -1.0;

  /// depth ≥ 0 側: 1m 奥行くごとに priority を下げる傾き。
  static double get renderPriorityFarScalePerMeter =>
      (renderPriorityAtPlayfield - renderPriorityAtSky) / skyDepthMeters;

  /// [SkyComponent]（= [skyDepthMeters]）。
  static int get outdoorSkyRenderPriority =>
      renderPriorityForDepth(skyDepthMeters);

  /// 地面・電車レール（= [playfieldDepthMeters]）。
  static int get outdoorGroundRenderPriority =>
      renderPriorityForDepth(playfieldDepthMeters);

  /// 建物・ロケット（= [buildingDepthMeters]）。
  static int get outdoorBuildingRenderPriority =>
      renderPriorityForDepth(buildingDepthMeters);

  /// 自動化キット（= [automationKitDepthMeters]）。
  static int get outdoorAutomationKitRenderPriority =>
      renderPriorityForDepth(automationKitDepthMeters);

  /// 手前シルエット（= [nearForegroundDepthMeters]）。
  static int get outdoorNearForegroundRenderPriority =>
      renderPriorityForDepth(nearForegroundDepthMeters);

  /// 奥行き [depthMeters] から Flame の描画 priority を導出する。
  ///
  /// 正 = 奥（小さい priority）、0 = プレイ面、負 = 手前（大きい priority）。
  ///
  /// * depth ≥ 0: `renderPriorityAtPlayfield - depth × renderPriorityFarScalePerMeter`
  /// * depth &lt; 0: `renderPriorityAtPlayfield + (playfield - depth) × renderPriorityNearScalePerMeter`
  ///
  /// [skyDepthMeters] で [renderPriorityAtSky]、[playfieldDepthMeters] で
  /// [renderPriorityAtPlayfield] になるよう傾きは自動で決まる。
  static int renderPriorityForDepth(
    double depthMeters, {
    int? override,
  }) {
    if (override != null) {
      return override;
    }
    if (depthMeters < playfieldDepthMeters) {
      return (renderPriorityAtPlayfield +
              (playfieldDepthMeters - depthMeters) *
                  renderPriorityNearScalePerMeter)
          .round()
          .clamp(renderPriorityAtSky, lightingOverlayRenderPriority - 1);
    }
    return (renderPriorityAtPlayfield -
            depthMeters * renderPriorityFarScalePerMeter)
        .round()
        .clamp(renderPriorityAtSky, lightingOverlayRenderPriority - 1);
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
