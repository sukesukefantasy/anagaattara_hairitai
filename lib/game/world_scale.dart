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
}
