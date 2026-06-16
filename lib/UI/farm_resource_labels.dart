/// ファーム／自動化 UI 用の残滓・意志ラベル。
class FarmResourceLabels {
  static const life = '生命';
  static const history = '歴史';
  static const inorganic = '無機';
  static const willpower = '意志';
  static const currency = '通貨';
  static const mining = '採掘Pt';

  static String cargoAbsolute({
    required int life,
    required int history,
    required int inorganic,
    required int cap,
  }) =>
      '${FarmResourceLabels.life} $life/$cap · ${FarmResourceLabels.history} $history/$cap · ${FarmResourceLabels.inorganic} $inorganic/$cap';
}
