/// ローカルライト描画の品質ティア（v8.5: 全プラットフォーム Canvas 統一）。
enum LightingQuality {
  /// Canvas per-component 暗幕 + マスク dstIn + ランタン punch。
  mobileCanvas,
}

/// ライティング関連の定数。
abstract final class LightingConfig {
  LightingConfig._();

  static const int maxActiveLights = 6;
}

/// 実行環境に応じたライティング品質。
abstract final class LightingQualityTier {
  LightingQualityTier._();

  static const LightingQuality current = LightingQuality.mobileCanvas;

  /// 全プラットフォームで Canvas ローカル照明を使用する。
  static const bool useCanvasLocalLights = true;
}
