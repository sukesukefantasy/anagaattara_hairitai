import 'package:flutter/material.dart';
import 'farm_resource_labels.dart';
import 'widgets/will_core_pip.dart';

/// 残滓3粒・意志・通貨のコストチップ。
class FarmResourceIcons {
  static const lifeColor = Colors.redAccent;
  static const historyColor = Colors.lightBlueAccent;
  static const inorganicColor = Colors.blueGrey;
  static const currencyColor = Colors.amberAccent;

  static Widget lifeDot({double size = 8}) => _dot(lifeColor, size);
  static Widget historyDot({double size = 8}) => _dot(historyColor, size);
  static Widget inorganicDot({double size = 8}) => _dot(inorganicColor, size);

  static Widget _dot(Color c, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );

  /// 意志力ポイント（HUD と同じ橙グラデーション核ピップ）。
  static Widget willChip(double amount, {double fontSize = 11}) =>
      WillpowerCostIcon(amount: amount, fontSize: fontSize);

  static Widget currencyChip(int amount, {double fontSize = 11}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.paid, size: fontSize + 2, color: currencyColor),
          const SizedBox(width: 2),
          Text(
            '${FarmResourceLabels.currency}$amount',
            style: TextStyle(color: currencyColor, fontSize: fontSize),
          ),
        ],
      );

  /// 意志の核単位（消費・獲得）。
  static Widget willCoreChip({
    required double units,
    double fontSize = 11,
  }) =>
      WillCoreCostIcon(units: units, fontSize: fontSize);

  static Widget humanityChip(double amount, {double fontSize = 11}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.public, size: fontSize + 2, color: Colors.orangeAccent),
          const SizedBox(width: 2),
          Text(
            '人間性−${amount.toInt()}',
            style: TextStyle(color: Colors.orangeAccent, fontSize: fontSize),
          ),
        ],
      );

  static Widget residueChip({
    int life = 0,
    int history = 0,
    int inorganic = 0,
    double fontSize = 11,
  }) {
    final parts = <Widget>[];
    if (life > 0) {
      parts.addAll([
        lifeDot(),
        const SizedBox(width: 2),
        Text('$life', style: TextStyle(color: lifeColor, fontSize: fontSize)),
      ]);
    }
    if (history > 0) {
      if (parts.isNotEmpty) parts.add(const SizedBox(width: 6));
      parts.addAll([
        historyDot(),
        const SizedBox(width: 2),
        Text('$history', style: TextStyle(color: historyColor, fontSize: fontSize)),
      ]);
    }
    if (inorganic > 0) {
      if (parts.isNotEmpty) parts.add(const SizedBox(width: 6));
      parts.addAll([
        inorganicDot(),
        const SizedBox(width: 2),
        Text('$inorganic', style: TextStyle(color: inorganicColor, fontSize: fontSize)),
      ]);
    }
    if (parts.isEmpty) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: parts);
  }
}
