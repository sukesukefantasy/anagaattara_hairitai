import 'light_profile.dart';

/// [local_lights.frag] と同型のリング減衰・relight 計算（Canvas 用）。
abstract final class CanvasLightRings {
  CanvasLightRings._();

  static const double lightStrengthScale = 0.035;

  /// 画面 px 距離からリング cut 値（シェーダー [computeRingCut] 相当）。
  static double ringCut(
    double distPx,
    LightProfile profile,
    double zoom,
    double radiusScale,
  ) {
    final rInner = profile.innerRadius * zoom * radiusScale;
    final rMid = profile.midRadius * zoom * radiusScale;
    final rOuter = profile.outerRadius * zoom * radiusScale;

    if (distPx >= rOuter) {
      return 0.0;
    }
    if (distPx <= rInner) {
      return profile.innerCut;
    }
    if (distPx <= rMid) {
      final t = _smoothstep(rInner, rMid, distPx);
      return profile.innerCut + (profile.midCut - profile.innerCut) * t;
    }
    final t = _smoothstep(rMid, rOuter, distPx);
    return profile.midCut + (profile.outerCut - profile.midCut) * t;
  }

  /// cut と深度から relight マスク alpha（0..1、白 dstOut 用）。
  static double relightAlpha(
    double ringCutValue,
    double depthFactor,
    double ambientDarkness,
  ) {
    if (ambientDarkness <= 0.001 || ringCutValue <= 0.0) {
      return 0.0;
    }
    final lightStrength =
        ringCutValue * lightStrengthScale * depthFactor.clamp(0.0, 1.0);
    final effectiveDarkness =
        (ambientDarkness - lightStrength).clamp(0.0, ambientDarkness);
    return (1.0 - effectiveDarkness / ambientDarkness).clamp(0.0, 1.0);
  }

  static double _smoothstep(double edge0, double edge1, double x) {
    if (edge0 == edge1) {
      return x < edge0 ? 0.0 : 1.0;
    }
    final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
  }
}
