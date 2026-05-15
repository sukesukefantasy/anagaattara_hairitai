import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../../main.dart';
import '../../../system/storage/game_runtime_state.dart';
import '../../../system/automation_shop_catalog.dart';
import '../../../UI/window_manager.dart';
import '../../../UI/windows/automation_shop_window.dart';
import '../../common/hitboxes/interact_hitbox.dart';
import '../../effect/residue_pickup.dart';
import '../../item/item.dart';

/// 自動化キット
///
/// `automationKitStage` 4 = ドキュメント §5 の **C-2**（意志の核自動供給）に相当。
/// 自動化ショップの Tier A〜B は [AutomationShopCatalog] 経由でも購入可能。
class AutomationKit extends PositionComponent
    with HasGameReference<MyGame>, CollisionCallbacks {
  static const double _stage2Interval = 60.0;
  static const double _stage3Interval = 30.0;
  static const double _stage4Interval = 15.0;

  static const int _stage2CurrencyGain = 10;
  static const int _stage2MiningGain = 2;
  static const int _stage3CurrencyGain = 15;
  static const int _stage3MiningGain = 3;
  static const int _stage4CurrencyGain = 20;
  static const int _stage4MiningGain = 5;

  double _cycleTimer = 0.0;
  double _pulseTimer = 0.0;
  late RectangleComponent _body;
  late RectangleComponent _pulseOverlay;
  TextComponent? _stageLabel;
  InteractHitbox? _interactHitbox;

  AutomationKit({required super.position})
      : super(size: Vector2(40, 40), anchor: Anchor.bottomCenter);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _body = RectangleComponent(
      size: size,
      paint: Paint()..color = const Color(0xFF1a1a3e),
    );
    add(_body);
    _pulseOverlay = RectangleComponent(
      size: size,
      paint: Paint()..color = Colors.transparent,
    );
    add(_pulseOverlay);
    _stageLabel = TextComponent(
      text: _stageText(),
      position: Vector2(size.x / 2, size.y + 4),
      anchor: Anchor.topCenter,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.tealAccent,
          fontSize: 8,
          fontFamily: 'Nosutaru-dotMPlusH-10-Regular',
        ),
      ),
    );
    add(_stageLabel!);
    _interactHitbox = InteractHitbox(
      size: Vector2(size.x + 20, size.y + 20),
      position: Vector2(-10, -10),
      onInteract: _onInteract,
    );
    add(_interactHitbox!);
  }

  String _stageText() {
    final stage = game.gameRuntimeState.automationKitStage;
    switch (stage) {
      case 0:
        return '[未起動]';
      case 1:
        return '[手動稼働]';
      case 2:
        return '[自動Lv1]';
      case 3:
        return '[自動Lv2]';
      case 4:
        return '[意志の核/C-2]';
      default:
        return '';
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final state = game.gameRuntimeState;
    final stage = state.automationKitStage;
    if (stage < 2) return;

    final interval = stage == 4
        ? _stage4Interval
        : (stage == 3 ? _stage3Interval : _stage2Interval);
    _cycleTimer += dt;
    if (_cycleTimer >= interval) {
      _cycleTimer = 0.0;
      _runAutoCycle(state, stage);
    }

    if (stage == 4) {
      state.automationKitTotalRuntime += dt;
    }
    _pulseTimer += dt;
    _updatePulseVisual(stage);
    _stageLabel?.text = _stageText();
  }

  static const List<String> _fatherVoiceFragments = [
    '…この機械は、誰が作ったんだろう…',
    '…効率的だ。…それだけだ。',
    '…便利だから、使っている。…それだけなのか？',
    '…何かが、こちらを見ている…',
    '…（ノイズ）…キミは、まだ…そこに……',
  ];

  void _runAutoCycle(GameRuntimeState state, int stage) {
    int currencyGain;
    int miningGain;
    switch (stage) {
      case 4:
        currencyGain = _stage4CurrencyGain;
        miningGain = _stage4MiningGain;
        break;
      case 3:
        currencyGain = _stage3CurrencyGain;
        miningGain = _stage3MiningGain;
        break;
      default:
        currencyGain = _stage2CurrencyGain;
        miningGain = _stage2MiningGain;
    }

    state.currency += currencyGain;
    state.miningPoints += miningGain;
    ResiduePickup.emitCargo(game, ResiduePickup.worldEmitOrigin(this), life: 1);
    state.noteMicroCategoryFarm(1);
    state.tryBoostAutomationAutoPickupFromAutoCycle();
    debugPrint('AutomationKit[Lv$stage]: +$currencyGain通貨 +$miningGain採掘Pt');

    if (stage == 4) {
      _maybeTriggerFatherVoice(state);
    }
  }

  void _maybeTriggerFatherVoice(GameRuntimeState state) {
    final probability =
        (0.1 + (state.automationKitTotalRuntime / 3600.0) * 0.3).clamp(0.1, 0.4);

    if (Random().nextDouble() < probability) {
      final fragment = _fatherVoiceFragments[
          Random().nextInt(_fatherVoiceFragments.length)];
      ResiduePickup.emitCargo(
        game,
        ResiduePickup.worldEmitOrigin(this),
        history: 1,
      );
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!game.windowManager.isShowing(GameWindowType.message)) {
          game.windowManager.showDialog(['〔ログ断片〕', fragment]);
        }
      });
    }
  }

  void _updatePulseVisual(int stage) {
    if (stage == 0) return;
    final pulse = (sin(_pulseTimer * 2.0) + 1) / 2;
    Color overlayColor;
    if (stage == 4) {
      overlayColor = Color.fromARGB((pulse * 80).toInt(), 100, 0, 180);
    } else if (stage == 3) {
      overlayColor = Color.fromARGB((pulse * 50).toInt(), 0, 200, 180);
    } else {
      overlayColor = Color.fromARGB((pulse * 30).toInt(), 0, 180, 200);
    }
    _pulseOverlay.paint.color = overlayColor;
  }

  void _openAutomationShop(WindowManager wm, GameRuntimeState state) {
    wm.hideWindow();
    wm.showWindow(
      GameWindowType.automationShop,
      AutomationShopWindow(game: game, windowManager: wm),
    );
  }

  void _runManualCycle(GameRuntimeState state, WindowManager wm) {
    state.currency += _stage2CurrencyGain;
    state.miningPoints += _stage2MiningGain;
    ResiduePickup.emitCargo(game, ResiduePickup.worldEmitOrigin(this), life: 1);
    state.tryStartAutomationAutoPickupWindow();
    state.codexIncrementAutomationOps();
    wm.showDialog([
      '手を動かした。\n通貨+${_stage2CurrencyGain}、採掘Pt+${_stage2MiningGain}。',
      '…もっと効率よくできないだろうか。',
    ]);
  }

  void _grantFlamethrowerReward() {
    final it =
        ItemFactory.createItemByName('火炎放射器', Vector2.zero());
    if (it != null) {
      game.itemBag.addItem(it);
    }
  }

  void _onInteract() {
    final state = game.gameRuntimeState;
    final wm = game.windowManager;
    final stage = state.automationKitStage;

    if (stage == 0) {
      wm.showDialog([
        '〔自動化キット〕',
        '起動しますか？\n手動で動かすことで通貨と採掘ポイントを生産できます。',
      ], options: ['起動する', 'やめておく'], onSelect: (index) {
        if (index == 0) {
          state.automationKitStage = 1;
          state.saveGame();
          wm.hideWindow();
          wm.showDialog(['キットが起動した。手で動かすと何か出てくるらしい。']);
        } else {
          wm.hideWindow();
        }
      });
    } else if (stage == 1) {
      wm.showDialog([
        '手動でサイクルを回すか、ショップを開くか選べる。',
      ], options: ['稼働する', '自動化ショップ'], onSelect: (index) {
        if (index == 0) {
          wm.hideWindow();
          _runManualCycle(state, wm);
        } else {
          _openAutomationShop(wm, state);
        }
      });
    } else if (stage == 2 || stage == 3) {
      wm.showDialog([
        '強化ダイアログを開くか、ショップを開くか選べ。',
      ], options: ['強化メニュー', '自動化ショップ'], onSelect: (index) {
        if (index == 0) {
          wm.hideWindow();
          _showUpgradeDialog(state, wm, stage);
        } else {
          _openAutomationShop(wm, state);
        }
      });
    } else if (stage == 4) {
      wm.showDialog([
        '〔C-2 契約済み〕',
        'このキットはあなたの意志の核を燃やして自律している。',
      ], options: ['閉じる', '自動化ショップ'], onSelect: (index) {
        if (index == 1) {
          _openAutomationShop(wm, state);
        } else {
          wm.hideWindow();
        }
      });
    }
  }

  void _showUpgradeDialog(GameRuntimeState state, WindowManager wm, int stage) {
    final nextStage = stage + 1;
    final cost = stage == 2 ? 30 : 0;

    if (nextStage == 4) {
      if (state.maxWillCoreValue <= 1e-9 ||
          state.maxWillCoreValue <= GameRuntimeState.willCoreUnit + 1e-9) {
        wm.showDialog([
          '意志の核が足りない。',
          'もっと経験を積まないといけない。',
        ]);
        return;
      }

      wm.showDialog([
        '〔自動化:C-2 契約〕',
        '意志の核を1つ挿入すると、機械が自律機動する。',
        '一度挿入したら取り出せない。',
        '不可逆点を越える。この先、マクロ Nourishment 側へ寄ったまま戻せない。',
        '…それでも進めるか？',
      ], options: ['契約する', 'やめておく'], onSelect: (index) async {
        if (index == 0) {
          state.maxWillCoreValue -= GameRuntimeState.willCoreUnit;
          state.clampCurrentWillpowerToCapacity();
          state.automationKitStage = 4;
          state.registerAutomationContractC2();
          _grantFlamethrowerReward();
          wm.hideWindow();
          wm.showDialog([
            '星の側があなたの核を自動で回収できるようになった気がする。',
            '（報酬として「火炎放射器」をインベントリに追加した）',
          ], bodyTextColor: Colors.white);
        } else {
          wm.hideWindow();
        }
      });
    } else {
      if (state.currency < cost) {
        wm.showDialog(['通貨が足りない。(必要: $cost)']);
        return;
      }
      state.currency -= cost;
      state.automationKitStage = nextStage;
      state.saveGame();
      wm.showDialog([
        'キットが強化された。',
        '生産サイクルが速くなった。',
      ]);
    }
  }
}
