import 'package:flutter/material.dart';
import '../window_manager.dart';
import '../../component/item/item_bag.dart';
import '../../component/item/item.dart';
import '../../main.dart';
import '../dialogs/confirmation_dialog.dart';
import '../widgets/item_sprite_icon.dart';
import 'window_base.dart';

class ItemBagWindow extends StatelessWidget with GameWindowResponsiveMixin {
  final WindowManager windowManager;
  final ItemBag itemBag;
  final MyGame game; // MyGameのインスタンスを追加

  const ItemBagWindow({
    super.key,
    required this.windowManager,
    required this.itemBag,
    required this.game,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = getIsMobile(windowManager);

    return GameWindow(
      windowManager: windowManager,
      title: 'ITEM BAG',
      backgroundColor: Colors.brown[800],
      child: Column(
        children: [
          Expanded(
            child: AnimatedBuilder(
              animation: itemBag, // ItemBagの変更を監視
              builder: (context, child) {
                if (itemBag.items.isEmpty) {
                  return Center(
                    child: Text(
                      'No items yet.',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : windowManager.screenWidth * 0.025,
                        color: Colors.white,
                        fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: itemBag.items.length,
                  itemBuilder: (context, index) {
                    final itemName = itemBag.items.keys.elementAt(index);
                    final item = itemBag.items[itemName]!;
                    final count = itemBag.getItemCount(itemName);
                    final displayDisplayName = item.displayName;
                    final displayDescription = item.description;
                    
                    return Card(
                      margin: EdgeInsets.symmetric(
                        horizontal: windowManager.screenWidth * 0.02,
                        vertical: windowManager.screenHeight * 0.005,
                      ),
                      color: Colors.brown[600],
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: windowManager.screenWidth * 0.02,
                          vertical: windowManager.screenHeight * 0.01,
                        ),
                        child: Row(
                          children: [
                            // アイテム画像
                            GestureDetector(
                              onTap: () {
                                _showItemDetailDialog(context, item);
                              },
                              child: Stack(
                                children: [
                                  ItemSpriteIcon(
                                    itemName: item.name,
                                    spritePath: item.spritePath,
                                    width: isMobile ? 50 : windowManager.screenWidth * 0.08,
                                    height: isMobile ? 50 : windowManager.screenWidth * 0.08,
                                  ),
                                  if (itemBag.equippedItemName == item.name)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'E',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: isMobile ? 10 : windowManager.screenWidth * 0.015,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // アイテム名、数量、説明
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayDisplayName,
                                    style: TextStyle(
                                      fontSize: isMobile ? 14 : windowManager.screenHeight * 0.03,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontFamily:
                                          'Nosutaru-dotMPlusH-10-Regular',
                                    ),
                                  ),
                                  Text(
                                    'x$count',
                                    style: TextStyle(
                                      fontSize: isMobile ? 10 : windowManager.screenHeight * 0.02,
                                      color: Colors.white70,
                                      fontFamily:
                                          'Nosutaru-dotMPlusH-10-Regular',
                                    ),
                                  ),
                                  if (!isMobile) // スマホでは説明文を省略または詳細ダイアログに任せる
                                    Text(
                                      displayDescription,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: windowManager.screenHeight * 0.025,
                                        color: Colors.white70,
                                        fontFamily:
                                            'Nosutaru-dotMPlusH-10-Regular',
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // アイテム詳細、使用ボタン
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildPrimaryActionButton(
                                  context,
                                  item,
                                  count,
                                  isMobile,
                                ),
                                if (item.type == ItemType.placeable) ...[
                                  const SizedBox(width: 4),
                                  _buildItemActionButton(
                                    context,
                                    BagWindowActionType.dispose,
                                    () => _handleItemAction(
                                      context,
                                      item,
                                      1,
                                      BagWindowActionType.dispose,
                                    ),
                                    Colors.red,
                                    count > 0,
                                    isMobile,
                                  ),
                                ],
                                const SizedBox(width: 4),
                                _buildItemActionButton(
                                  context,
                                  BagWindowActionType.carry,
                                  () => _handleItemAction(
                                    context,
                                    item,
                                    1,
                                    BagWindowActionType.carry,
                                  ),
                                  Colors.blue,
                                  true,
                                  isMobile,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // 閉じるボタン
          Padding(
            padding: EdgeInsets.all(windowManager.screenWidth * 0.01),
            child: ElevatedButton(
              onPressed: () {
                windowManager.hideOverlay();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 20 : windowManager.screenWidth * 0.02,
                  vertical: isMobile ? 10 : windowManager.screenHeight * 0.01,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'close',
                style: TextStyle(
                  fontSize: isMobile ? 14 : windowManager.screenWidth * 0.02,
                  color: Colors.white,
                  fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // アイテム詳細ダイアログを表示するメソッド
  void _showItemDetailDialog(BuildContext context, Item item) {
    final displayDisplayName = item.displayName;
    final displayDescription = item.description;
    final isMobile = getIsMobile(windowManager);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.brown[700], // ダイアログの背景色
          title: Text(
            displayDisplayName,
            style: TextStyle(
              fontSize: isMobile ? 18 : windowManager.screenHeight * 0.03,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
            ),
          ),
          content: Text(
            displayDescription,
            style: TextStyle(
              fontSize: isMobile ? 14 : windowManager.screenHeight * 0.025,
              color: Colors.white70,
              fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'close',
                style: TextStyle(
                  fontSize: isMobile ? 14 : windowManager.screenWidth * 0.02,
                  color: Colors.white,
                  fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                ),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // アイテム使用ダイアログを表示するメソッド
  void _showUseItemDialog(BuildContext context, Item item, int currentCount) {
    int useCount = 1; // 使用する個数の初期値
    final displayDisplayName = item.displayName;
    final isMobile = getIsMobile(windowManager);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              backgroundColor: Colors.brown[700],
              alignment: Alignment.center,
              title: Text(
                '$displayDisplayName を使用',
                style: TextStyle(
                  fontSize: isMobile ? 18 : windowManager.screenWidth * 0.02,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ItemSpriteIcon(
                    itemName: item.name,
                    spritePath: item.spritePath,
                    width: isMobile ? 60 : windowManager.screenWidth * 0.1,
                    height: isMobile ? 60 : windowManager.screenHeight * 0.1,
                  ),
                  Text(
                    '所持数: $currentCount',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : windowManager.screenWidth * 0.02,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                    ),
                  ),
                  if (item.type != ItemType.gem) // 宝石のみ個数選択を省略
                    Column(
                      children: [
                        SizedBox(width: windowManager.screenWidth * 0.01),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    useCount =
                                        (useCount - 10).clamp(1, currentCount);
                                  });
                                },
                                child: Text(
                                  '-10',
                                  style: TextStyle(
                                    fontSize: isMobile
                                        ? 11
                                        : windowManager.screenWidth * 0.012,
                                    color: Colors.white,
                                    fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.remove,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  setState(() {
                                    if (useCount > 1) useCount--;
                                  });
                                },
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  '$useCount個',
                                  style: TextStyle(
                                    fontSize: isMobile
                                        ? 14
                                        : windowManager.screenWidth * 0.015,
                                    color: Colors.white70,
                                    fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, color: Colors.white),
                                onPressed: () {
                                  setState(() {
                                    if (useCount < currentCount) useCount++;
                                  });
                                },
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    useCount = (useCount + 10)
                                        .clamp(1, currentCount);
                                  });
                                },
                                child: Text(
                                  '+10',
                                  style: TextStyle(
                                    fontSize: isMobile
                                        ? 11
                                        : windowManager.screenWidth * 0.012,
                                    color: Colors.white,
                                    fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    useCount = currentCount;
                                  });
                                },
                                child: Text(
                                  '全て',
                                  style: TextStyle(
                                    fontSize: isMobile
                                        ? 11
                                        : windowManager.screenWidth * 0.012,
                                    color: Colors.amberAccent,
                                    fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  SizedBox(height: windowManager.screenHeight * 0.01),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildItemActionButton(
                        dialogContext,
                        _resolveBagConsumeAction(item),
                        () {
                          _handleItemAction(
                            dialogContext,
                            item,
                            useCount,
                            _resolveBagConsumeAction(item),
                          );
                        },
                        Colors.teal,
                        currentCount > 0,
                        isMobile,
                      ),
                      // 解除ボタン (Toolの場合のみ)
                      if (item.type == ItemType.tool)
                        _buildItemActionButton(
                          context,
                          BagWindowActionType.unequip,
                          () => _handleItemAction(
                            dialogContext,
                            item,
                            1,
                            BagWindowActionType.unequip,
                          ),
                          Colors.orange,
                          true,
                          isMobile,
                        ),
                    ],
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: Text(
                    'close',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : windowManager.screenWidth * 0.02,
                      color: Colors.white,
                      fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      // ダイアログが閉じられた後に、アイテムバッグの表示を更新する
    });
  }

  /// バッグの「使用」ダイアログから消費扱いで processed するアクション。
  /// CustomItem は定義の [CustomItem.customActionType]（通常は consume）に合わせる。
  BagWindowActionType _resolveBagConsumeAction(Item item) {
    if (item is CustomItem) return item.customActionType;
    return BagWindowActionType.consume;
  }

  // アイテムを使用するロジック
  void _useItem(BuildContext context, Item item, int countToUse) {
    final player = game.player;
    for (int i = 0; i < countToUse; i++) {
      item.onUse(player);
    }
    game.gameRuntimeState.codexIncrementItemUsed(
      item.name,
      count: countToUse,
    );
    itemBag.removeItem(item.name, count: countToUse);

    // ダイアログを閉じる
    Navigator.of(context).pop();
  }

  // アイテムタイプに基づいて主要なアクションタイプを決定するヘルパーメソッド
  BagWindowActionType _getActionType(Item item) {
    // 装備中のアイテムであれば解除を優先
    if (itemBag.equippedItemName == item.name) {
      return BagWindowActionType.unequip;
    }

    switch (item.type) {
      case ItemType.currency:
      case ItemType.health:
      case ItemType.stress:
      case ItemType.powerUp:
        return BagWindowActionType.consume;
      case ItemType.gem:
        return BagWindowActionType.view; // Gemは眺める
      case ItemType.tool:
        return BagWindowActionType.equip; // Toolは装備
      case ItemType.placeable:
        return BagWindowActionType.place;
      case ItemType.custom:
        return (item as CustomItem).customActionType; // customActionType を参照
      case ItemType.collection:
        return BagWindowActionType.none;
    }
  }

  // アイテムのアクションを処理するメソッド
  Future<void> _handleItemAction(
    BuildContext dialogContext,
    Item item,
    int countToUse,
    BagWindowActionType actionType,
  ) async {
    switch (actionType) {
      case BagWindowActionType.consume:
      case BagWindowActionType.custom:
        // custom は CustomItem の customActionType で来る。スタック消費は _useItem に必ず委譲する。
        _useItem(dialogContext, item, countToUse);
        break;
      case BagWindowActionType.place:
        windowManager.hideOverlay();
        if (!ItemFactory.tryStartPlaceablePlacement(game, item)) {
          if (item is PlaceableItem && !item.canBeginPlacement(game)) {
            game.windowManager.showDialog(['地下でのみ配置できます。']);
          } else {
            game.windowManager.showDialog(['配置を開始できませんでした。']);
          }
        }
        break;
      case BagWindowActionType.carry:
        windowManager.hideOverlay();
        game.player.startCarrying(item);
        break;
      case BagWindowActionType.equip:
        if (item is ToolItem) {
          game.player.equipItem(item.name);
        }
        break;
      case BagWindowActionType.unequip:
        if (item is ToolItem) {
          game.player.unequipItem(item.name);
        }
        break;
      case BagWindowActionType.dispose:
        showDialog(
          context: dialogContext,
          builder: (BuildContext context) {
            final displayDisplayName = item.displayName;
            return ConfirmationDialog(
              title: 'アイテムの廃棄',
              message: '$displayDisplayName を 「全て」 廃棄しますか？',
              onConfirm: () {
                game.player.disposePlaceableItem(item);
              },
            );
          },
        );
        break;
      case BagWindowActionType.view:
        game.player.viewGem(item);
        break;
      case BagWindowActionType.none:
        break;
    }
  }

  // アクションボタンを生成するヘルパーメソッド
  Widget _buildItemActionButton(
    BuildContext context,
    BagWindowActionType actionType,
    VoidCallback onPressed,
    Color backgroundColor,
    bool isEnabled,
    bool isMobile,
  ) {
    String buttonText;
    switch (actionType) {
      case BagWindowActionType.consume:
        buttonText = '消費';
        break;
      case BagWindowActionType.carry:
        buttonText = '持つ';
        break;
      case BagWindowActionType.equip:
        buttonText = '装備';
        break;
      case BagWindowActionType.unequip:
        buttonText = '解除';
        break;
      case BagWindowActionType.dispose:
        buttonText = '廃棄';
        break;
      case BagWindowActionType.view:
        buttonText = '眺める';
        break;
      case BagWindowActionType.custom:
        buttonText = '使用';
        break;
      case BagWindowActionType.place:
        buttonText = '配置';
        break;
      case BagWindowActionType.none:
        return const SizedBox.shrink();
    }

    return ElevatedButton(
      onPressed: isEnabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : windowManager.screenWidth * 0.015,
          vertical: isMobile ? 4 : windowManager.screenHeight * 0.01,
        ),
        minimumSize: Size.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        buttonText,
        style: TextStyle(
          fontSize: isMobile ? 12 : windowManager.screenWidth * 0.013,
          color: Colors.white,
          fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
        ),
      ),
    );
  }

  // メインアクションボタンを生成するヘルパーメソッド
  Widget _buildPrimaryActionButton(BuildContext context, Item item, int count, bool isMobile) {
    final actionType = _getActionType(item);
    Color backgroundColor;
    VoidCallback onPressed;
    bool isEnabled = true;

    switch (actionType) {
      case BagWindowActionType.consume:
        backgroundColor = Colors.teal;
        onPressed = () {
          _showUseItemDialog(context, item, count);
        };
        isEnabled = count > 0;
        break;
      case BagWindowActionType.equip:
        backgroundColor = Colors.green;
        onPressed = () {
          _handleItemAction(context, item, 1, BagWindowActionType.equip);
        };
        break;
      case BagWindowActionType.unequip:
        backgroundColor = Colors.orange;
        onPressed = () {
          _handleItemAction(context, item, 1, BagWindowActionType.unequip);
        };
        break;
      case BagWindowActionType.dispose:
        backgroundColor = Colors.red;
        onPressed = () {
          _handleItemAction(context, item, 1, BagWindowActionType.dispose);
        };
        break;
      case BagWindowActionType.view:
        backgroundColor = Colors.yellow;
        onPressed = () {
          _handleItemAction(context, item, 1, BagWindowActionType.view);
        };
        break;
      case BagWindowActionType.carry:
        backgroundColor = Colors.blueGrey;
        onPressed = () {
          _handleItemAction(context, item, 1, BagWindowActionType.carry);
        };
        break;
      case BagWindowActionType.custom:
        backgroundColor = Colors.teal;
        onPressed = () {
          _showUseItemDialog(context, item, count);
        };
        break;
      case BagWindowActionType.place:
        backgroundColor = Colors.brown;
        onPressed = () {
          if (item is PlaceableItem && !item.canBeginPlacement(game)) {
            game.windowManager.showDialog(['地下でのみ使えます。']);
            return;
          }
          _handleItemAction(context, item, 1, BagWindowActionType.place);
        };
        isEnabled =
            count > 0 &&
            (item is! PlaceableItem || item.canBeginPlacement(game));
        break;
      case BagWindowActionType.none:
        return const SizedBox.shrink();
    }

    return _buildItemActionButton(
      context,
      actionType,
      onPressed,
      backgroundColor,
      isEnabled,
      isMobile,
    );
  }
}
