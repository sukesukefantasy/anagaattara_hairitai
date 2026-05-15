import 'package:flutter/material.dart';
import '../../main.dart';
import '../../system/automation_shop_catalog.dart';
import '../window_manager.dart';

/// キット／HUD から開く自動化ショップ（§5）
class AutomationShopWindow extends StatelessWidget {
  final MyGame game;
  final WindowManager windowManager;

  const AutomationShopWindow({
    super.key,
    required this.game,
    required this.windowManager,
  });

  @override
  Widget build(BuildContext context) {
    final state = game.gameRuntimeState;
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: 420,
          constraints: const BoxConstraints(maxHeight: 520),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF101028).withOpacity(0.95),
            border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '自動化ショップ',
                style: TextStyle(
                  color: Colors.cyanAccent.shade100,
                  fontSize: windowManager.fontSize + 2,
                  fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'A:${state.automationShopTierA} B:${state.automationShopTierB} '
                'C:${state.automationShopTierC} D:${state.automationShopTierD}\n'
                'C-2契約: ${state.automationContractC2}',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: windowManager.fontSize - 2,
                  fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                ),
              ),
              const Divider(color: Colors.white24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buyTile('A-1 ドロップ吸引（短時間）', '生命カーゴ40', () {
                        final err = state.tryPurchaseShopTierA1();
                        _toast(err);
                      }),
                      _buyTile('A-2 自動吸引ルート', '生命25・歴史12', () {
                        final err = state.tryPurchaseShopTierA2();
                        _toast(err);
                      }),
                      _buyTile('A-3 吸引強化', '無機30', () {
                        final err = state.tryPurchaseShopTierA3();
                        _toast(err);
                      }),
                      _buyTile('B-1 装置25%回復系', '意志力2.5', () {
                        final err = state.tryPurchaseShopTierB1();
                        _toast(err);
                      }),
                      _buyTile('B-2 自動支払い基盤', '通貨60', () {
                        final err = state.tryPurchaseShopTierB2();
                        _toast(err);
                      }),
                      _buyTile('B-3 耐久代償＋火炎瓶', '意志力3.5', () {
                        final err =
                            state.tryPurchaseShopTierB3Preview(game.itemBag);
                        _toast(err);
                      }),
                      _buyTile('C-1 シールド（核1単位）', '最大核を1消費', () {
                        final err = state.tryPurchaseShopTierC1Shield();
                        _toast(err);
                      }),
                      _buyTile('C-2 契約（Nourishment 確定・不可逆）', '核1＋火炎放射器', () {
                        windowManager.showDialog(
                          [
                            '〔C-2 契約〕',
                            '最大容量から意志の核を1単位取り外します。',
                            'この先、マクロ Nourishment へ寄ったまま戻せません。',
                            '（火炎放射器をインベントリに追加）',
                          ],
                          options: ['契約する', 'やめる'],
                          onSelect: (i) {
                            if (i == 0) {
                              final err = state.tryPurchaseShopTierC2Contract(
                                game.itemBag,
                              );
                              _toast(err);
                            }
                          },
                        );
                      }),
                      _buyTile('D-1 母星人間性の代償', '人間性−18・核+1・意思力+半核', () {
                        final err = state.tryPurchaseShopTierD1();
                        _toast(err);
                      }),
                      _buyTile('D-2 さらなる代償', '人間性−12・核+1', () {
                        final err = state.tryPurchaseShopTierD2();
                        _toast(err);
                      }),
                      _buyTile('D-3 極限 / 高出力電源', '人間性−22・装置無敵扱いの象徴アイテム', () {
                        final err = state.tryPurchaseShopTierD3(game.itemBag);
                        _toast(err);
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => windowManager.hideWindow(),
                child: const Text('閉じる', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buyTile(String title, String cost, VoidCallback onBuy) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        onPressed: onBuy,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: windowManager.fontSize,
                  fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                ),
              ),
              Text(
                cost,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: windowManager.fontSize - 2,
                  fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toast(String? err) {
    if (err == null) {
      windowManager.showDialog(['〔自動化ショップ〕', '更新した。']);
    } else {
      windowManager.showDialog(['〔自動化ショップ〕', err]);
    }
  }
}
