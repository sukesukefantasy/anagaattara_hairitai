/// 3層リングライトの半径と暗さオーバーレイ減算量を定義する。
class LightProfile {
  final double innerRadius;
  final double midRadius;
  final double outerRadius;
  final double innerCut;
  final double midCut;
  final double outerCut;

  const LightProfile({
    required this.innerRadius,
    required this.midRadius,
    required this.outerRadius,
    required this.innerCut,
    required this.midCut,
    required this.outerCut,
  });

  factory LightProfile.fromBrightnessLevel(
    int level, {
    double innerRadius = 120,
    double midRadius = 240,
    double outerRadius = 360,
  }) {
    return LightProfile(
      innerRadius: innerRadius,
      midRadius: midRadius,
      outerRadius: outerRadius,
      innerCut: level / 10.0,
      midCut: level / 70.0,
      outerCut: level / 800.0,
    );
  }

  static final LightProfile standard = LightProfile.fromBrightnessLevel(600);
}
