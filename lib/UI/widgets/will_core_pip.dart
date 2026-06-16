import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../system/storage/game_runtime_state.dart';

/// 意志力 HUD（[GameUI._willCorePip]）と共通の色。
abstract final class WillCorePipColors {
  static Color get shell => const Color(0xFFb8860b).withValues(alpha: 0.75);
  static const innerBg = Color(0xFF120c08);
  static const gradientStart = Color(0xFFe65100);
  static const gradientEnd = Color(0xFFffc947);
  static const labelText = Color(0xFFffe0b2);
  static const icon = Color(0xFFffcc80);
}

/// 意志の核1単位分のミニピップ（HUD と同形）。
class WillCorePip extends StatelessWidget {
  const WillCorePip({
    super.key,
    required this.width,
    required this.height,
    required this.fill,
  });

  final double width;
  final double height;
  final double fill;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: WillCorePipColors.shell, width: 1.1),
          color: WillCorePipColors.innerBg.withValues(alpha: 0.9),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fill.clamp(0.0, 1.0),
                heightFactor: 1,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        WillCorePipColors.gradientStart,
                        WillCorePipColors.gradientEnd,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 意志力ポイント量を HUD 風ピップ列で表示。
class WillpowerCostIcon extends StatelessWidget {
  const WillpowerCostIcon({
    super.key,
    required this.amount,
    this.fontSize = 11,
    this.showLabel = true,
  });

  final double amount;
  final double fontSize;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    if (amount <= 0) return const SizedBox.shrink();
    final pipW = math.max(12.0, fontSize * 0.9);
    final pipH = math.max(8.0, fontSize * 0.65);
    final gap = (fontSize * 0.18).clamp(2.0, 4.0);
    final pips = _buildPipsForWillpower(amount, pipW, pipH, gap);
    final amountText = amount.toStringAsFixed(
      amount == amount.roundToDouble() ? 0 : 1,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.brightness_5_outlined,
          size: fontSize + 2,
          color: WillCorePipColors.icon,
        ),
        const SizedBox(width: 3),
        ...pips,
        if (showLabel) ...[
          SizedBox(width: gap + 1),
          Text(
            amountText,
            style: TextStyle(
              color: WillCorePipColors.labelText,
              fontSize: fontSize,
              fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
            ),
          ),
        ],
      ],
    );
  }
}

/// 核単位数（1.0 = 1核消費）を HUD 風ピップで表示。
class WillCoreCostIcon extends StatelessWidget {
  const WillCoreCostIcon({
    super.key,
    required this.units,
    this.fontSize = 11,
  });

  /// 正 = 消費、負 = 獲得（D 系など）。
  final double units;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    if (units.abs() < 1e-9) return const SizedBox.shrink();
    final pipW = math.max(12.0, fontSize * 0.9);
    final pipH = math.max(8.0, fontSize * 0.65);
    final gap = (fontSize * 0.18).clamp(2.0, 4.0);
    final absUnits = units.abs();
    final pips = _buildPipsForCoreUnits(absUnits, pipW, pipH, gap);
    final prefix = units < 0 ? '+' : '';
    final label = '$prefix${absUnits.toStringAsFixed(absUnits == absUnits.roundToDouble() ? 0 : 1)}核';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.brightness_5_outlined,
          size: fontSize + 2,
          color: WillCorePipColors.icon,
        ),
        const SizedBox(width: 3),
        ...pips,
        SizedBox(width: gap + 1),
        Text(
          label,
          style: TextStyle(
            color: WillCorePipColors.labelText,
            fontSize: fontSize,
            fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
          ),
        ),
      ],
    );
  }
}

List<Widget> _buildPipsForWillpower(
  double willpower,
  double pipW,
  double pipH,
  double gap,
) {
  const unit = GameRuntimeState.willCoreUnit;
  var remaining = willpower;
  final widgets = <Widget>[];
  var i = 0;
  while (remaining > 1e-6 && i < 6) {
    if (i > 0) widgets.add(SizedBox(width: gap));
    final fill = (remaining / unit).clamp(0.0, 1.0);
    widgets.add(WillCorePip(width: pipW, height: pipH, fill: fill));
    remaining -= fill * unit;
    i++;
  }
  return widgets;
}

List<Widget> _buildPipsForCoreUnits(
  double units,
  double pipW,
  double pipH,
  double gap,
) {
  var remaining = units;
  final widgets = <Widget>[];
  var i = 0;
  while (remaining > 1e-6 && i < 6) {
    if (i > 0) widgets.add(SizedBox(width: gap));
    final fill = remaining.clamp(0.0, 1.0);
    widgets.add(WillCorePip(width: pipW, height: pipH, fill: fill));
    remaining -= fill;
    i++;
  }
  return widgets;
}
