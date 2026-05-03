import 'package:flutter/material.dart';
import '../window_manager.dart';
import '../../component/item/item_bag.dart';
import '../../component/item/item.dart';
import '../../main.dart';
import '../../game_manager/mission_manager.dart';
import '../dialogs/confirmation_dialog.dart';

class ItemBagWindow extends StatelessWidget {
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
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: windowManager.screenWidth * 0.5,
          height: windowManager.screenHeight * 0.8,
          decoration: BoxDecoration(
            color: Colors.brown[800], // アイテムバッグの背景色
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: windowManager.screenWidth * 0.02,
                  vertical: windowManager.screenHeight * 0.01,
                ),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        'ITEM BAG',
                        style: TextStyle(
                          fontSize: windowManager.screenWidth * 0.02,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                          letterSpacing: 5,
                        ),
                      ),
                    ),
                    /* Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 30),
                        onPressed: () {
                          windowManager.hideWindow();
                        },
                      ),
                    ), */
                  ],
                ),
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: itemBag, // ItemBagの変更を監視
                  builder: (context, child) {
                    if (itemBag.items.isEmpty) {
                      return Center(
                        child: Text(
                          'No items yet.',
                          style: TextStyle(
                            fontSize: windowManager.screenWidth * 0.025,
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
                        final isLap1 = game.gameRuntimeState.scenarioCount == 1;
                        final displayDisplayName = game.missionManager.getItemDisplayName(item.name);
                        final displayDescription = isLap1 ? item.description : (game.missionManager.getAttributeLevel() >= 3 || game.missionManager.getCurrentPhase() == MissionPhase.collapse ? (item.isMemoItem ? item.description : 'DATA_CORRUPTED: 意味を定義できません。') : item.description);
                        
                        return Card(
                          margin: EdgeInsets.symmetric(
                            horizontal: windowManager.screenWidth * 0.02,
                            vertical: windowManager.screenHeight * 0.01,
                          ),
                          color: Colors.brown[600],
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: windowManager.screenWidth * 0.01,
                              vertical: windowManager.screenHeight * 0.01,
                            ),
                            child: Row(
                              children: [
                                // アイテム画像 (スプライトパスから取得、Image.assetを使用)
                                // 現在、FlameのSpriteComponentから直接FlutterのWidgetとして画像を取得する方法がないため、
                                // 暫定的にassets/images/以下の対応する画像を使用します。
                                // 実際のゲームでは、アイテムのスプライト画像を適切に管理・表示するロジックが必要です。

                                // アイテム画像
                                GestureDetector(
                                  onTap: () {
                                    _showItemDetailDialog(context, item);
                                  },
                                  child: Stack(
                                    children: [
                                      Image.asset(
                                        'assets/images/${item.spritePath}', // item.spritePath を使用
                                        width: windowManager.screenWidth * 0.1,
                                        height:
                                            windowManager.screenHeight *
                                            0.1, // 画面幅の10%
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Icon(
                                            Icons.broken_image,
                                            size: 50,
                                            color: Colors.grey,
                                          );
                                        },
                                      ),
                                      if (itemBag.equippedItemName == item.name)
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'E',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: windowManager.screenWidth * 0.02,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // アイテム名、数量、説明
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayDisplayName,
                                        style: TextStyle(
                                          fontSize:
                                              windowManager.screenHeight *
                                              0.03, // 画面高さの2.8%
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontFamily:
                                              'Nosutaru-dotMPlusH-10-Regular',
                                        ),
                                      ),
                                      if (displayDisplayName != item.name)
                                        Text(
                                          '(${item.name}) x$count',
                                          style: TextStyle(
                                            fontSize:
                                                windowManager.screenHeight *
                                                0.02,
                                            color: Colors.white70,
                                            fontFamily:
                                                'Nosutaru-dotMPlusH-10-Regular',
                                          ),
                                        )
                                      else
                                        Text(
                                          'x$count',
                                          style: TextStyle(
                                            fontSize:
                                                windowManager.screenHeight *
                                                0.02,
                                            color: Colors.white70,
                                            fontFamily:
                                                'Nosutaru-dotMPlusH-10-Regular',
                                          ),
                                        ),
                                      Text(
                                        displayDescription,
                                        style: TextStyle(
                                          fontSize:
                                              windowManager.screenHeight *
                                              0.025, // 画面高さの2%
                                          color: Colors.white70,
                                          fontFamily:
                                              'Nosutaru-dotMPlusH-10-Regular',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: windowManager.screenWidth * 0.01,
                                ),
                                // アイテム詳細、使用ボタン
                                Row(
                                  children: [
                                    _buildPrimaryActionButton(
                                      context,
                                      item,
                                      count,
                                    ),
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
                    windowManager.hideWindow();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: EdgeInsets.symmetric(
                      horizontal: windowManager.screenWidth * 0.02,
                      vertical: windowManager.screenHeight * 0.01,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'close',
                    style: TextStyle(
                      fontSize: windowManager.screenWidth * 0.02,
                      color: Colors.white,
                      fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // アイテム詳細ダイアログを表示するメソッド
  void _showItemDetailDialog(BuildContext context, Item item) {
    final displayDisplayName = game.missionManager.getItemDisplayName(item.name);
    final isLap1 = game.gameRuntimeState.scenarioCount == 1;
    final displayDescription = isLap1 ? item.description : (game.missionManager.getAttributeLevel() >= 3 || game.missionManager.getCurrentPhase() == MissionPhase.collapse ? (item.isMemoItem ? item.description : 'DATA_CORRUPTED: 意味を定義できません。') : item.description);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.brown[700], // ダイアログの背景色
          title: Text(
            '$displayDisplayName${displayDisplayName != item.name ? ' (${item.name})' : ''}',
            style: TextStyle(
              fontSize: windowManager.screenHeight * 0.03,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
            ),
          ),
          content: Text(
            displayDescription,
            style: TextStyle(
              fontSize: windowManager.screenHeight * 0.025,
              color: Colors.white70,
              fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'close',
                style: TextStyle(
                  fontSize: windowManager.screenWidth * 0.02,
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
    final displayDisplayName = game.missionManager.getItemDisplayName(item.name);

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
                  fontSize: windowManager.screenWidth * 0.02,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/${item.spritePath}',
                    width: windowManager.screenWidth * 0.1,
                    height: windowManager.screenHeight * 0.1, // 画面幅の10%
                    fit: BoxFit.contain,
                  ),
                  Text(
                    '所持数: $currentCount',
                    style: TextStyle(
                      fontSize: windowManager.screenWidth * 0.02,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                    ),
                  ),
                  if (item.type != ItemType.gem &&
                      item.type != ItemType.placeable) // 宝石と配置アイテムは個数選択させない
                    Column(
                      children: [
                        SizedBox(width: windowManager.screenWidth * 0.01),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
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
                            Text(
                              '$useCount個',
                              style: TextStyle(
                                fontSize: windowManager.screenWidth * 0.015,
                                color: Colors.white70,
                                fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
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
                          ],
                        ),
                      ],
                    ),
                  SizedBox(height: windowManager.screenHeight * 0.01),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildItemActionButton(
                        dialogContext, // Navigator.of(dialogContext).pop() のために dialogContext を使用
                        BagWindowActionType.consume,
                        () {
                          _handleItemAction(
                            dialogContext,
                            item,
                            useCount,
                            BagWindowActionType.consume,
                          );
                        },
                        Colors.teal, // 消費アイテムは通常 Teal
                        currentCount > 0, // 数量が0より大きい場合のみ有効
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
                          true, // 常に有効とするか、装備状態によって変える
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
                      fontSize: windowManager.screenWidth * 0.02,
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
      // ItemBag.items の変更をlistenするAnimatedBuilderが自動で更新するはずなので、setStateは不要
    });
  }

  // アイテムを使用するロジック
  void _useItem(BuildContext context, Item item, int countToUse) {
    final player = game.player;
    for (int i = 0; i < countToUse; i++) {
      item.onUse(player);
    }
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
        return BagWindowActionType.dispose; // Placeableは廃棄するがメインアクション
      case ItemType.custom:
        return (item as CustomItem).customActionType; // customActionType を参照
      case ItemType.collection:
        return BagWindowActionType.none;
    }
  }

  // アイテムのアクションを処理するメソッド
  Future<void> _handleItemAction(
    // Future<void> に変更
    BuildContext dialogContext,
    Item item,
    int countToUse,
    BagWindowActionType actionType,
  ) async {
    // async を追加
    switch (actionType) {
      case BagWindowActionType.consume:
        _useItem(dialogContext, item, countToUse);
        break;
      case BagWindowActionType.carry:
        game.player.startCarrying(item);
        windowManager.hideWindow();
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
            final displayDisplayName = game.missionManager.getItemDisplayName(item.name);
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
      case BagWindowActionType.custom:
        item.onUse(game.player);
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
        buttonText = '廃棄する';
        break;
      case BagWindowActionType.view:
        buttonText = '眺める';
        break;
      case BagWindowActionType.custom:
        buttonText = '';
        break;
      case BagWindowActionType.none:
        return const SizedBox.shrink();
    }

    return ElevatedButton(
      onPressed: isEnabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        padding: EdgeInsets.symmetric(
          horizontal: windowManager.screenWidth * 0.015,
          vertical: windowManager.screenHeight * 0.01,
        ),
        minimumSize: Size.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        buttonText, // 内部で決定されたテキストを表示
        style: TextStyle(
          fontSize: windowManager.screenWidth * 0.013,
          color: Colors.white,
          fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
        ),
      ),
    );
  }

  // メインアクションボタンを生成するヘルパーメソッド
  Widget _buildPrimaryActionButton(BuildContext context, Item item, int count) {
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
      case BagWindowActionType.carry: // Gem の持ち運びもここに含まれる
        backgroundColor = Colors.blueGrey;
        onPressed = () {
          _handleItemAction(context, item, 1, BagWindowActionType.carry);
        };
        break;
      case BagWindowActionType.custom:
        // CustomItem のデフォルトアクションタイプは _getActionType で取得されるため、ここでは custom は考慮しない
        // カスタムアクションがある場合は、別途ハンドリングが必要
        backgroundColor = Colors.teal; // デフォルト色
        onPressed = () {
          _showUseItemDialog(context, item, count); // カスタムアクションは使用ダイアログで処理
        };
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
    );
  }
}
