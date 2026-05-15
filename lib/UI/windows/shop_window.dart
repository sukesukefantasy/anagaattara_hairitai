import 'package:flutter/material.dart';
import 'package:flame/components.dart';

import '../../component/item/item.dart';
import '../../component/item/item_bag.dart';
import '../../main.dart';
import '../window_manager.dart';
import 'window_base.dart';

class ShopWindow extends StatefulWidget {
  final WindowManager windowManager;
  final ItemBag itemBag;
  final MyGame game;

  const ShopWindow({
    super.key,
    required this.windowManager,
    required this.itemBag,
    required this.game,
  });

  @override
  State<ShopWindow> createState() => _ShopWindowContentState();
}

class _ShopWindowContentState extends State<ShopWindow>
    with GameWindowResponsiveMixin {
  static const int _maxQtyPerPurchase = 99;

  /// [ItemFactory._itemDefinitions] のキー。省略時も [name] を使うため通常は冗長だが明示用。
  static String resolveFactoryKey(Map<String, dynamic> row) {
    return (row['factoryKey'] as String?) ?? (row['name'] as String);
  }

  static String resolveDisplayTitle(Map<String, dynamic> row) {
    return (row['displayName'] as String?) ?? (row['name'] as String);
  }

  /// `name` は常にインベントリ／ファクトリの正式キー（案 A）
  static final List<Map<String, dynamic>> _shopItems = [
    {
      'name': '栄養剤',
      'description': 'HPを100回復します',
      'spritePath': 'health_potion.png',
      'price': 50,
    },
    {
      'name': 'お茶の力',
      'displayName': '紅茶の力',
      'description': 'ストレスを20軽減し、最大ストレス値を増加します',
      'spritePath': 'green_cha.png',
      'price': 70,
    },
    {
      'name': 'レッド・ブリ',
      'description': '使用するとキマります。1時間の間、ストレスを無効にします',
      'spritePath': 'blue_red.png',
      'price': 460,
    },
    {
      'name': '採掘の気力',
      'description': '採掘ポイントを5増やします',
      'spritePath': 'shovel.png',
      'price': 120,
    },
    {
      'name': '石',
      'displayName': '希少な鉱石',
      'description': 'この星の地層から採取された、未知の組成を持つ鉱石。',
      'spritePath': 'stone.png',
      'price': 1,
    },
    {
      'name': '自動化キット',
      'description':
          '設置して手を動かすと通貨と採掘ポイントが貯まる。強化すると自動化できる。',
      'spritePath': 'energy_cube.png',
      'price': 80,
    },
  ];

  void _showShopItemDetailDialog(
    BuildContext dialogContext,
    Map<String, dynamic> shopItem,
  ) {
    final isMobile = getIsMobile(widget.windowManager);
    final title = resolveDisplayTitle(shopItem);

    showDialog<void>(
      context: dialogContext,
      builder: (BuildContext innerContext) {
        return AlertDialog(
          backgroundColor: Colors.lightGreen[700],
          title: Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 18 : widget.windowManager.screenHeight * 0.03,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
            ),
          ),
          content: Text(
            shopItem['description'] as String,
            style: TextStyle(
              fontSize: isMobile ? 14 : widget.windowManager.screenHeight * 0.025,
              color: Colors.white70,
              fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(innerContext).pop(),
              child: Text(
                'close',
                style: TextStyle(
                  fontSize: isMobile ? 14 : widget.windowManager.screenWidth * 0.02,
                  color: Colors.white,
                  fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openQuantityPurchaseSheet(Map<String, dynamic> shopItem) {
    final int price = shopItem['price'] as int;
    final player = widget.game.player;
    final maxByMoney = price > 0 ? player.moneyPoints ~/ price : 0;
    final maxQty =
        maxByMoney.clamp(0, _maxQtyPerPurchase);
    if (maxQty < 1) return;

    final isMobile = getIsMobile(widget.windowManager);
    final title = resolveDisplayTitle(shopItem);

    showDialog<void>(
      context: context,
      builder: (BuildContext outerContext) {
        int qty = 1;
        return StatefulBuilder(
          builder: (context, localSetState) {
            final total = price * qty;
            return AlertDialog(
              backgroundColor: Colors.lightGreen[700],
              title: Text(
                '$title の購入',
                style: TextStyle(
                  fontSize:
                      isMobile ? 18 : widget.windowManager.screenHeight * 0.03,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, color: Colors.white),
                        onPressed: () =>
                            localSetState(() => qty = (qty - 1).clamp(1, maxQty)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '$qty',
                          style: TextStyle(
                            fontSize: isMobile ? 20 : widget.windowManager.screenHeight * 0.035,
                            color: Colors.white,
                            fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.white),
                        onPressed: () =>
                            localSetState(() => qty = (qty + 1).clamp(1, maxQty)),
                      ),
                    ],
                  ),
                  Text(
                    '合計 $total G（単価 $price）',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : widget.windowManager.screenHeight * 0.025,
                      color: Colors.white70,
                      fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                    ),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(outerContext).pop(),
                  child: Text(
                    'キャンセル',
                    style: TextStyle(
                      fontSize:
                          isMobile ? 14 : widget.windowManager.screenWidth * 0.02,
                      color: Colors.white,
                      fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                    ),
                  ),
                ),
                TextButton(
                  onPressed:
                      widget.game.player.moneyPoints >= total
                          ? () {
                            Navigator.of(outerContext).pop();
                            _completePurchase(shopItem, qty);
                          }
                          : null,
                  child: Text(
                    '購入',
                    style: TextStyle(
                      fontSize:
                          isMobile ? 14 : widget.windowManager.screenWidth * 0.02,
                      color: Colors.amberAccent,
                      fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _completePurchase(Map<String, dynamic> shopItem, int qty) {
    final factoryKey = resolveFactoryKey(shopItem);
    final int price = shopItem['price'] as int;

    final Item? prototype =
        ItemFactory.createItemByName(factoryKey, Vector2.zero());
    if (prototype == null) {
      debugPrint(
        'ShopWindow: アイテム生成に失敗したため購入を中止: factoryKey=$factoryKey',
      );
      return;
    }

    final player = widget.game.player;
    final int total = price * qty;
    if (player.moneyPoints < total) {
      debugPrint('ShopWindow: 所持金が不足しているため購入を中止');
      return;
    }

    player.updateMoneyPoints(-total);

    final displayName = resolveDisplayTitle(shopItem);
    debugPrint('$displayName ×$qty を購入しました。-$total G');

    for (int i = 0; i < qty; i++) {
      final Item? purchasedItem =
          ItemFactory.createItemByName(factoryKey, Vector2.zero());
      if (purchasedItem != null) {
        widget.itemBag.addItem(purchasedItem);
      } else {
        debugPrint(
          'ShopWindow: 個別生成に失敗 (factoryKey=$factoryKey index=$i)',
        );
      }
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = getIsMobile(widget.windowManager);
    final screenWidth = widget.windowManager.screenWidth;
    final screenHeight = widget.windowManager.screenHeight;

    return GameWindow(
      windowManager: widget.windowManager,
      title: 'SHOP',
      backgroundColor: Colors.lightGreen[800],
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03),
            child: AnimatedBuilder(
              animation: widget.game.player.currencyNotifier,
              builder: (context, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Image.asset(
                      'assets/images/money.png',
                      width: isMobile ? 40 : screenWidth * 0.1,
                      height: isMobile ? 40 : screenHeight * 0.1,
                      fit: BoxFit.contain,
                    ),
                    SizedBox(width: screenWidth * 0.01),
                    Text(
                      '${widget.game.player.moneyPoints}',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : screenHeight * 0.03,
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
                final title = resolveDisplayTitle(shopItem);
                final itemPrice = shopItem['price'] as int;
                final itemSpritePath = shopItem['spritePath'] as String;
                final isAffordable =
                    widget.game.player.moneyPoints >= itemPrice;

                return Card(
                  margin: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.02,
                    vertical: screenHeight * 0.005,
                  ),
                  color: Colors.lightGreen[600],
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 8 : screenWidth * 0.01),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () =>
                              _showShopItemDetailDialog(context, shopItem),
                          child: Image.asset(
                            'assets/images/$itemSpritePath',
                            width: isMobile ? 50 : screenWidth * 0.1,
                            height: isMobile ? 50 : screenHeight * 0.1,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.broken_image,
                                size: isMobile ? 40 : 50,
                                color: Colors.grey,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: isMobile ? 14 : screenHeight * 0.03,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                                ),
                              ),
                              if (!isMobile)
                                Text(
                                  shopItem['description'] as String,
                                  style: TextStyle(
                                    fontSize: screenHeight * 0.025,
                                    color: Colors.white70,
                                    fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            Text(
                              '$itemPrice G',
                              style: TextStyle(
                                fontSize: isMobile ? 14 : screenHeight * 0.03,
                                fontWeight: FontWeight.bold,
                                color: isAffordable
                                    ? Colors.amberAccent
                                    : Colors.redAccent,
                                fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                              ),
                            ),
                            ElevatedButton(
                              onPressed: isAffordable
                                  ? () => _openQuantityPurchaseSheet(shopItem)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isAffordable
                                    ? Colors.blueAccent
                                    : Colors.grey,
                                padding: EdgeInsets.symmetric(
                                  horizontal:
                                      isMobile ? 12 : screenWidth * 0.025,
                                  vertical:
                                      isMobile ? 6 : screenHeight * 0.01,
                                ),
                                minimumSize: Size.zero,
                              ),
                              child: Text(
                                isAffordable ? 'Buy' : '...',
                                style: TextStyle(
                                  fontSize:
                                      isMobile ? 12 : screenHeight * 0.025,
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
              horizontal: screenWidth * 0.02,
              vertical: screenHeight * 0.01,
            ),
            child: ElevatedButton(
              onPressed: () => widget.windowManager.hideWindow(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 20 : screenWidth * 0.05,
                  vertical: isMobile ? 10 : screenHeight * 0.02,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Close',
                style: TextStyle(
                  fontSize: isMobile ? 14 : screenHeight * 0.035,
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
}
