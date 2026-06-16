import 'package:flutter/material.dart';
import '../system/farm_resource_cost.dart';
import 'farm_resource_icons.dart';

/// コスト内訳をアイコンチップで1行表示。
class FarmResourceCostRow extends StatelessWidget {
  const FarmResourceCostRow({
    super.key,
    required this.cost,
    this.fontSize = 11,
    this.fallbackLabel,
    this.textColor,
  });

  final FarmResourceCost cost;
  final double fontSize;
  final String? fallbackLabel;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    if (!cost.hasStandardCost && cost.note == null) {
      if (fallbackLabel == null || fallbackLabel!.isEmpty) {
        return const SizedBox.shrink();
      }
      return Text(
        fallbackLabel!,
        style: TextStyle(color: textColor ?? Colors.white54, fontSize: fontSize),
      );
    }

    final chips = <Widget>[];

    if (cost.hasResidue) {
      chips.add(
        FarmResourceIcons.residueChip(
          life: cost.life,
          history: cost.history,
          inorganic: cost.inorganic,
          fontSize: fontSize,
        ),
      );
    }
    if (cost.currency > 0) {
      chips.add(FarmResourceIcons.currencyChip(cost.currency, fontSize: fontSize));
    }
    if (cost.willpower > 0) {
      chips.add(FarmResourceIcons.willChip(cost.willpower, fontSize: fontSize));
    }
    if (cost.willCoreSpend.abs() > 1e-9) {
      chips.add(
        FarmResourceIcons.willCoreChip(
          units: cost.willCoreSpend,
          fontSize: fontSize,
        ),
      );
    }
    if (cost.humanitySpend > 0) {
      chips.add(
        FarmResourceIcons.humanityChip(cost.humanitySpend, fontSize: fontSize),
      );
    }
    if (cost.note != null && cost.note!.isNotEmpty) {
      chips.add(
        Text(
          cost.note!,
          style: TextStyle(
            color: textColor ?? Colors.white54,
            fontSize: fontSize,
          ),
        ),
      );
    }
    if (cost.affinityAligned) {
      chips.add(
        Text(
          '主軸お得',
          style: TextStyle(
            color: Colors.tealAccent.shade100,
            fontSize: fontSize - 1,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: chips,
    );
  }
}

/// HUD 用：3種残滓の絶対量＋色ドット。
class FarmCargoAbsoluteRow extends StatelessWidget {
  const FarmCargoAbsoluteRow({
    super.key,
    required this.life,
    required this.history,
    required this.inorganic,
    required this.cap,
    this.fontSize = 11,
  });

  final int life;
  final int history;
  final int inorganic;
  final int cap;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _kind(FarmResourceIcons.lifeDot(), life, FarmResourceIcons.lifeColor),
        _kind(
          FarmResourceIcons.historyDot(),
          history,
          FarmResourceIcons.historyColor,
        ),
        _kind(
          FarmResourceIcons.inorganicDot(),
          inorganic,
          FarmResourceIcons.inorganicColor,
        ),
      ],
    );
  }

  Widget _kind(Widget dot, int value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        const SizedBox(width: 3),
        Text(
          '$value/$cap',
          style: TextStyle(
            color: color.withValues(alpha: 0.85),
            fontSize: fontSize,
            fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
          ),
        ),
      ],
    );
  }
}
