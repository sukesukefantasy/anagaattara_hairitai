import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import '../window_manager.dart';
import '../../component/item/item_bag.dart';
import '../../component/player.dart';
import '../../main.dart';
import '../../component/item/item.dart';

class ShopWindow extends StatefulWidget {
  final WindowManager windowManager;
  final ItemBag itemBag;
  final MyGame game; // お金とプレイヤー情報にアクセスするため

  const ShopWindow({
    super.key,
    required this.windowManager,
    required this.itemBag,
    required this.game,
  });

  @override
  State<ShopWindow> createState() => _ShopWindowContentState();
}

class _ShopWindowContentState extends State<ShopWindow> {
  // 仮の販売アイテムリスト
  static final List<Map<String, dynamic>> _shopItems = [
    {
      'name': '栄養剤',
      'description': 'HPを100回復します',
      'spritePath': 'health_potion.png',
      'price': 50,
      'itemType': ItemType.health,
      'healAmount': 100.0,
    },
    {
      'name': '紅茶の力',
      'description': 'ストレスを20軽減し、最大ストレス値を増加します',
      'spritePath': 'tea.png',
      'price': 70,
      'itemType': ItemType.stress,
      'stressReduction': 20.0,
    },
    {
      'name': 'レッド・ブリ',
      'description': '使用するとキマリます。1時間の間、ストレスを無効にします',
      'spritePath': 'blue_red.png',
      'price': 460,
      'itemType': ItemType.powerUp,
      'stressReduction': 20.0,
    },
    {
      'name': '採掘の気力',
      'description': '採掘ポイントを5増やします',
      'spritePath': 'shovel.png',
      'price': 120,
      'itemType': ItemType.custom,
      'effect': (Player player) {
        // 仮の効果：採掘ポイントを少し増やすなど
        player.updateMiningPoints(1);
        player.addMaxStress(5.0); // 例としてストレス耐性も少し上げる
        debugPrint('採掘ポイントを5増やしました！');
      },
      'value': 1,
    },
    {
      'name': '石',
      'description': 'この星を構成している何か',
      'spritePath': 'stone.png',
      'price': 1,
      'itemType': ItemType.custom,
      'effect': (Player player) {
        debugPrint('石を買った！');
      },
      'value': 1,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: widget.windowManager.screenWidth * 0.7, // 画面幅の70%
          height: widget.windowManager.screenHeight * 0.9, // 画面高さの90%
          decoration: BoxDecoration(
            color: Colors.lightGreen[800], // ショップの背景色
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.windowManager.screenWidth * 0.02,
                  vertical: widget.windowManager.screenHeight * 0.01,
                ), // 画面幅の4%
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        'SHOP',
                        style: TextStyle(
                          fontSize:
                              widget.windowManager.screenWidth *
                              0.02, // 画面高さの5%
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
                        icon: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: widget.windowManager.screenWidth * 0.013, // 画面幅の6%
                        ),
                        onPressed: () {
                          widget.windowManager.hideWindow();
                        },
                      ),
                    ), */
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.windowManager.screenWidth * 0.03,
                ), // 画面幅の3%
                child: AnimatedBuilder(
                  animation: widget.game.player!.currencyNotifier, // お金の変化を監視
                  builder: (context, child) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Image.asset(
                          'assets/images/money.png',
                          width: widget.windowManager.screenWidth * 0.1,
                          height: widget.windowManager.screenHeight * 0.1,
                          fit: BoxFit.contain,
                        ),
                        SizedBox(
                          width: widget.windowManager.screenWidth * 0.01,
                        ), // 画面幅の1%
                        Text(
                          '${widget.game.player!.moneyPoints}',
                          style: TextStyle(
                            fontSize:
                                widget.windowManager.screenHeight *
                                0.03, // 画面高さの3%
                            color: Colors.white,
                            fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _shopItems.length,
                  itemBuilder: (context, index) {
                    final shopItem = _shopItems[index];
                    final itemName = shopItem['name'];
                    final itemPrice = shopItem['price'];
                    final itemSpritePath = shopItem['spritePath'];
                    final isAffordable =
                        widget.game.player!.moneyPoints >= itemPrice;

                    return Card(
                      margin: EdgeInsets.symmetric(
                        horizontal: widget.windowManager.screenWidth * 0.02,
                        vertical: widget.windowManager.screenHeight * 0.01,
                      ),
                      color: Colors.lightGreen[600],
                      child: Padding(
                        padding: EdgeInsets.all(
                          widget.windowManager.screenWidth * 0.01,
                        ), // 画面幅の2%
                        child: Row(
                          children: [
                            Image.asset(
                              'assets/images/$itemSpritePath',
                              width: widget.windowManager.screenWidth * 0.1,
                              height: widget.windowManager.screenHeight * 0.1,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.broken_image,
                                  size:
                                      widget.windowManager.screenWidth *
                                      0.1, // 画面幅の10%
                                  color: Colors.grey,
                                );
                              },
                            ),
                            SizedBox(
                              width: widget.windowManager.screenWidth * 0.01,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    itemName,
                                    style: TextStyle(
                                      fontSize:
                                          widget.windowManager.screenHeight *
                                          0.03, // 画面高さの2.8%
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                                    ),
                                  ),
                                  Text(
                                    shopItem['description'],
                                    style: TextStyle(
                                      fontSize:
                                          widget.windowManager.screenHeight *
                                          0.025, // 画面高さの2%
                                      color: Colors.white70,
                                      fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: widget.windowManager.screenWidth * 0.01,
                            ),
                            Column(
                              children: [
                                Text(
                                  '$itemPrice G',
                                  style: TextStyle(
                                    fontSize:
                                        widget.windowManager.screenHeight *
                                        0.03, // 画面高さの2.8%
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isAffordable
                                            ? Colors.amberAccent
                                            : Colors.redAccent,
                                    fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed:
                                      isAffordable
                                          ? () {
                                            _purchaseItem(
                                              shopItem,
                                            ); // 購入処理を呼び出す
                                          }
                                          : null, // お金が足りない場合はボタンを無効化
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        isAffordable
                                            ? Colors.blueAccent
                                            : Colors.grey,
                                    padding: EdgeInsets.symmetric(
                                      horizontal:
                                          widget.windowManager.screenWidth *
                                          0.025, // 画面幅の2.5%
                                      vertical:
                                          widget.windowManager.screenHeight *
                                          0.01,
                                    ),
                                  ),
                                  child: Text(
                                    isAffordable ? 'Buy' : 'Not enough',
                                    style: TextStyle(
                                      fontSize:
                                          widget.windowManager.screenHeight *
                                          0.025, // 画面高さの2.2%
                                      color: Colors.white,
                                      fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.windowManager.screenWidth * 0.02,
                  vertical: widget.windowManager.screenHeight * 0.02,
                ), // 画面幅の4%
                child: ElevatedButton(
                  onPressed: () {
                    widget.windowManager.hideWindow();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: EdgeInsets.symmetric(
                      horizontal:
                          widget.windowManager.screenWidth * 0.05, // 画面幅の5%
                      vertical:
                          widget.windowManager.screenHeight * 0.02, // 画面高さの2%
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Close',
                    style: TextStyle(
                      fontSize:
                          widget.windowManager.screenHeight *
                          0.035, // 画面高さの3.5%
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

  // アイテム購入処理
  void _purchaseItem(Map<String, dynamic> shopItem) {
    final player = widget.game.player!;
    final int price = shopItem['price'] as int;
    if (player.moneyPoints < price) {
      debugPrint('お金が足りません！');
      return;
    }

    // お金を減らす
    player.updateMoneyPoints(-price);
    debugPrint('${shopItem['name']} を購入しました。-$price G');

    // アイテムをPlayerのItemBagに追加
    final String itemName = shopItem['name'] as String;
    final Item? purchasedItem = ItemFactory.createItemByName(
      itemName,
      Vector2.zero(),
    );

    if (purchasedItem != null) {
      widget.itemBag.addItem(purchasedItem);
      debugPrint('$itemName をアイテムバッグに追加しました。');
    } else {
      debugPrint('アイテムの生成に失敗しました: $itemName');
    }

    // 購入後、表示を更新
    setState(() {}); // StatefulWidgetにすることでsetStateが利用可能に
  }
}
