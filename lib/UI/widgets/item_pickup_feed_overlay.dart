import 'package:flutter/material.dart';

import '../../component/item/item.dart';
import '../../system/item_pickup_feed.dart';
import 'item_sprite_icon.dart';

/// 画面右上（バッグボタン付近）に表示する入手ログ。
class ItemPickupFeedOverlay extends StatelessWidget {
  const ItemPickupFeedOverlay({
    super.key,
    required this.controller,
    required this.fontSize,
    required this.topOffset,
    required this.rightOffset,
    this.onEntryShown,
  });

  final ItemPickupFeedController controller;
  final double fontSize;
  final double topOffset;
  final double rightOffset;
  final void Function(ItemPickupFeedEntry entry)? onEntryShown;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final entries = controller.entries;
        if (entries.isEmpty) return const SizedBox.shrink();

        return Positioned(
          top: topOffset,
          right: rightOffset,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final entry in entries)
                _PickupFeedTile(
                  key: ValueKey(entry.id),
                  entry: entry,
                  fontSize: fontSize,
                  onShown: onEntryShown,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PickupFeedTile extends StatefulWidget {
  const _PickupFeedTile({
    super.key,
    required this.entry,
    required this.fontSize,
    this.onShown,
  });

  final ItemPickupFeedEntry entry;
  final double fontSize;
  final void Function(ItemPickupFeedEntry entry)? onShown;

  @override
  State<_PickupFeedTile> createState() => _PickupFeedTileState();
}

class _PickupFeedTileState extends State<_PickupFeedTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  )..forward();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onShown?.call(widget.entry);
    });
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final border = entry.isFirstAcquisition
        ? Colors.amber
        : (entry.borderColor ?? Colors.white24);
    final labelSize = widget.fontSize * 0.85;

    return FadeTransition(
      opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Container(
          constraints: BoxConstraints(maxWidth: widget.fontSize * 14),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: border.withValues(alpha: entry.isFirstAcquisition ? 0.95 : 0.55),
              width: entry.isFirstAcquisition ? 2 : 1,
            ),
            boxShadow: entry.isFirstAcquisition
                ? [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.35),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ItemSpriteIcon(
                itemName: entry.itemName,
                spritePath: entry.spritePath,
                width: labelSize * 1.6,
                height: labelSize * 1.6,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  entry.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: labelSize,
                    fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                  ),
                ),
              ),
              if (entry.stackCount > 1) ...[
                const SizedBox(width: 6),
                Text(
                  '×${entry.stackCount}',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: labelSize * 0.9,
                    fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 燃料ランクなど、入手ログの枠色ヒント。
Color? pickupFeedBorderForItemName(String itemName) {
  return switch (itemName) {
    '粗製燃料' => Colors.grey.shade400,
    '生命馏分' => Colors.redAccent,
    '歴史胶质' => Colors.lightBlueAccent,
    '無機基油' => Colors.blueGrey,
    '意志凝固' => Colors.cyanAccent,
    _ => null,
  };
}

String pickupFeedDisplayName(Item item) => item.displayName;
