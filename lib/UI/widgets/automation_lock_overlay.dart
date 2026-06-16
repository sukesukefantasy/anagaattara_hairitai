import 'package:flutter/material.dart';

/// 未解放項目の南京錠オーバーレイ。
Widget automationLockOverlay({
  required bool locked,
  required Widget child,
}) {
  if (!locked) return child;
  return Stack(
    children: [
      child,
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
      const Positioned.fill(
        child: Center(
          child: Icon(
            Icons.lock,
            color: Colors.white70,
            size: 28,
          ),
        ),
      ),
    ],
  );
}
