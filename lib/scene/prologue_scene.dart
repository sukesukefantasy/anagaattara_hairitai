import 'package:flutter/material.dart';
import 'abstract_outdoor_scene.dart';
import 'package:flame/components.dart';
import '../component/npc/ghost_echo.dart';
import '../component/npc/npc.dart';
import '../component/item/item.dart';
import '../component/game_stage/gamestage_component.dart';
import '../component/common/hitboxes/interact_hitbox.dart';
import 'dart:ui' show lerpDouble;

import '../system/storage/game_runtime_state.dart';

/// プロローグ [spawnGhostEchoes]（v8.3 マクロID）
const Map<String, Color> _prologueGhostEchoPalette = {
  'normal': Colors.white,
  GameRuntimeState.macroRouteNourishment: Colors.tealAccent,
  GameRuntimeState.macroRouteDestroy: Colors.redAccent,
  GameRuntimeState.macroRouteNormal: Colors.blueGrey,
  GameRuntimeState.macroRouteTrue: Colors.amberAccent,
};

class PrologueScene extends AbstractOutdoorScene {
  PrologueScene({required super.sceneId, super.initialPlayerPosition}) {
    gravityMultiplier = 0.33; // 重力を3分の1に設定
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // プロローグではプレイヤーを -50 から開始させる
    game.player.teleportTo(Vector2(-50, game.initialGameCanvasSize.y - game.player.size.y / 2));

    // デバッグ用: 棒を最初から所持
    final stick = ItemFactory.createItemByName('棒', Vector2.zero());
    if (stick != null) game.player.itemBag.addItem(stick);
  }

  @override
  double get groundHeight => 20.0;

  @override
  Future<void> initializeScene(dynamic data) async {
    final state = game.gameRuntimeState;
    
    // プロローグでは建物の位置を固定する（演出のため）
    if (!state.buildingPlacements.containsKey('outdoor_0')) {
      state.buildingPlacements['outdoor_0'] = {
        'home': -300.0,
        'garage': -800.0,
      };
    }

    await super.initializeScene(data);

    // ロケットにインタラクトで出発
    if (rocket != null) {
      rocket!.add(InteractHitbox(
        position: Vector2.zero(),
        size: rocket!.size,
        onInteract: () {
          _startCrashSequence();
        },
        icon: Icons.flight_takeoff,
      ));
    }

    // プロローグ固有のNPC配置
    _spawnPrologueNpcs();

    // プロローグ固有のNPC配置 (シナリオ1の場合のみ。シナリオ2以降は _spawnNpc 内で spawnGhostEchoes が呼ばれる)
    if (state.scenarioCount == 1) {
      // シナリオ1: おじさんのガレージ（温かい雰囲気）
      // おじさんの GhostEcho を配置
      final girl = GhostEcho(
        routeId: 'normal',
        color: Colors.orangeAccent,
        position: Vector2(-300, game.initialGameCanvasSize.y - 32),
      );
      girl.priority = 40;
      add(girl);
    }

    // 地下の入り口を1つだけ用意（チュートリアル用）
    underGround.addDiggableEntrances([-500.0]);
    
    debugPrint('PrologueScene initializeScene complete');
  }

  @override
  void update(double dt) {
    super.update(dt);

    // プレイヤーのX座標に基づいて宇宙への遷移率 (0.0 - 1.0) を計算
    // 開始地点 (-50) から ロケット/駅 (-3000) へ向かうにつれて上昇
    final playerX = game.player.position.x;
    final double transitionStart = -100.0;
    final double transitionEnd = -2500.0;
    
    final double transitionFactor = ((playerX - transitionStart) / (transitionEnd - transitionStart)).clamp(0.0, 1.0);

    // 1. 地面の色を遷移 (緑 -> 黒/灰)
    if (ground != null) {
      final Color startColor = Colors.green.withOpacity(0.3);
      final Color endColor = Colors.black.withOpacity(0.8);
      
      final r = lerpDouble(startColor.red.toDouble(), endColor.red.toDouble(), transitionFactor)!.toInt();
      final g = lerpDouble(startColor.green.toDouble(), endColor.green.toDouble(), transitionFactor)!.toInt();
      final b = lerpDouble(startColor.blue.toDouble(), endColor.blue.toDouble(), transitionFactor)!.toInt();
      final a = lerpDouble(startColor.alpha.toDouble(), endColor.alpha.toDouble(), transitionFactor)!.toInt();
      
      ground!.overlayColor = Color.fromARGB(a, r, g, b);
    }

    // 2. 背景の不透明度を調整
    final backgrounds = children.whereType<GameStageComponent>();
    for (final bg in backgrounds) {
      if (bg.priority == 2) {
        // 母星の背景: 1.0 -> 0.0
        bg.opacity = 1.0 - transitionFactor;
      } else if (bg.priority == 1) {
        // 宇宙の背景: 0.0 -> 1.0
        bg.opacity = transitionFactor;
      }
    }
  }

  @override
  void spawnGhostEchoes() {
    final state = game.gameRuntimeState;
    const ordered = [
      'normal',
      GameRuntimeState.macroRouteNourishment,
      GameRuntimeState.macroRouteDestroy,
      GameRuntimeState.macroRouteNormal,
      GameRuntimeState.macroRouteTrue,
    ];
    final show = <String>{'normal'};
    for (final id in state.completedMacroRoutes) {
      if (ordered.contains(id)) show.add(id);
    }
    var i = 0;
    for (final routeId in ordered) {
      if (!show.contains(routeId)) continue;
      final color =
          _prologueGhostEchoPalette[routeId] ?? Colors.white70;
      final ghost = GhostEcho(
        routeId: routeId,
        color: color,
        position: Vector2(-400 - (i * 150.0), game.initialGameCanvasSize.y - 32),
      );
      ghost.priority = 35;
      add(ghost);
      i++;
    }
  }

  void _spawnPrologueNpcs() {
    // 1. 子供のNPC
    add(Npc(
      name: "子供",
      talkMessages: ["おじさん、いつ帰ってくるのかなぁ……。", "最近、みんな色んなことをすぐに忘れちゃうんだ。怖いよ。"],
      giftResponse: "わぁ、ありがとう！ これ、忘れないようにしなきゃ。",
      uniqueId: "prologue_child",
      position: Vector2(-350, game.initialGameCanvasSize.y - 32),
      srcPosition: Vector2(392, 238), // TODO: 子供用スプライト
      srcSize: Vector2(17, 18),
    )..priority = 40);

    // 2. 大人のNPC
    add(Npc(
      name: "住人",
      talkMessages: [
        "あいつは優秀すぎた。だからあの星に『歴史』を気に入られてしまったんだ。",
        "母星も最近はおかしい。便利になればなるほど、みんな大事なことを手放していく。"
      ],
      giftResponse: "……助かる。これは、何に使うものだったかな。",
      uniqueId: "prologue_adult",
      position: Vector2(-850, game.initialGameCanvasSize.y - 32),
      srcPosition: Vector2(104, 108), // TODO: 住人用スプライト
      srcSize: Vector2(16, 20),
    )..priority = 40);

    // 3. 若返ったおじさん (Young Uncle)
    late final Npc youngUncle;
    youngUncle = Npc(
      name: "物静かな青年",
      talkMessages: [], // overrideで制御
      giftResponse: "……？ ありがとう。",
      uniqueId: "prologue_young_uncle",
      position: Vector2(-1200, game.initialGameCanvasSize.y - 32),
      spritePath: 'initiator.png',
      srcPosition: Vector2.zero(),
      srcSize: Vector2(50, 50),
      onTalkOverride: () {
        _handleYoungUncleTalk(youngUncle);
      },
    );

    add(youngUncle..priority = 40);

    // 4. ベテラン調査員
    add(Npc(
      name: "ベテラン調査員",
      talkMessages: [
        "準備はいいか？ あの星は、ただの無人惑星じゃない。",
        "人々の歴史を喰らい、模倣し、家畜化する……巨大な捕食者だ。",
        "お前の父親も、その『文脈』の濁流に飲まれた。……行くぞ、ロケットへ。"
      ],
      giftResponse: "……今はそんな場合じゃない。ロケットへ急げ。",
      uniqueId: "prologue_veteran",
      position: Vector2(-2200, game.initialGameCanvasSize.y - 32),
      srcPosition: Vector2(294, 70), // TODO: 調査員用スプライト
      srcSize: Vector2(20, 26),
    )..priority = 40);
  }

  void _handleYoungUncleTalk(Npc npc) {
    final state = game.gameRuntimeState;

    if (state.hasIdentifiedYoungUncle) {
      game.windowManager.showDialog([
        "[${npc.name}]",
        "「綺麗な空だ……。君のおかげで、少しだけ自分を取り戻せた気がするよ。」",
        "「またどこかで会おう。……相棒。」"
      ]);
      return;
    }

    // 段階的な対話
    switch (state.youngUncleDialogueStep) {
      case 0:
        game.windowManager.showDialog(
          ["[${npc.name}]", "「……綺麗な空だ。なんだか、ずっと昔からこうして空を眺めていたような気がするんだ。」", "「……何か、とても大切なことを忘れているような……。」"],
          options: ["何をしてるの？", "どこから来たの？"],
          onSelect: (index) {
            if (index == 0) {
              state.youngUncleDialogueStep = 1;
              state.saveGame();
            } else {
              game.windowManager.showDialog(["[${npc.name}]", "「さあ……。気づいたらここにいたんだ。名前も、思い出せない。」"]);
            }
          },
        );
        break;
      case 1:
        game.windowManager.showDialog(
          ["[${npc.name}]", "「空を眺めてるんだ。……君も、この空が好きかい？」"],
          options: ["おじさん？", "綺麗な空だね"],
          onSelect: (index) {
            if (index == 1) {
              state.youngUncleDialogueStep = 2;
              state.saveGame();
            } else {
              game.windowManager.showDialog(["[${npc.name}]", "「おじさん……？ 僕のことかな。……いや、違う気がする。」"]);
              state.youngUncleDialogueStep = 0; // リセット
              state.saveGame();
            }
          },
        );
        break;
      case 2:
        game.windowManager.showDialog(
          ["[${npc.name}]", "「……！ 君、今なんて言った？ その言葉、どこかで……」", "「……頭の中に、知らない誰かの記憶が流れ込んでくる……。濁流のように……。」"],
          options: ["おじさんの癖だよ", "ただの独り言"],
          onSelect: (index) {
            if (index == 0) {
              _identifyYoungUncle(npc);
            } else {
              game.windowManager.showDialog(["[${npc.name}]", "「そうか……。ただの空耳だったのかな。」"]);
              state.youngUncleDialogueStep = 0; // リセット
              state.saveGame();
            }
          },
        );
        break;
    }
  }

  void _identifyYoungUncle(Npc npc) {
    final state = game.gameRuntimeState;
    state.hasIdentifiedYoungUncle = true;
    state.saveGame();

    game.windowManager.showDialog(
      [
        "[${npc.name}]",
        "「おじさん……？ そうか、僕は……。」",
        "「……いや、まだはっきりとは思い出せない。でも、君のことは知っている気がする。」",
        "「……ポケットに、これが入っていたんだ。君に渡さなきゃいけない気がして。」"
      ],
      onClosed: () async {
        // アイテム付与
        final item = ItemFactory.createItemByName('意味を忘れないためのメモ', Vector2.zero());
        if (item != null) {
          game.player.itemBag.addItem(item);
          game.windowManager.showDialog(["（『意味を忘れないためのメモ』を受け取りました）"]);
        }
      },
    );
  }

  void _startCrashSequence() {
    game.windowManager.showDialog(
      [
        "[ベテラン調査員]",
        "「よし、全員乗り込んだな。……母星ともこれでおさらばだ。」",
        "「……見てみろ。あそこに見えるのが、我々の目的地……『歴史を喰らう惑星』だ。」",
        "「不気味なほどに美しいだろう？ あれは、犠牲になった数多の文明の輝きなんだ。」",
        "「……！？ なんだ、この揺れは！？」",
        "「吸引力が想定を超えている！ 重力スリングショットが効かない！ 墜落するぞ！！」",
        "（――激しい衝撃と、白い光が視界を覆う――）"
      ],
      onClosed: () async {
        // ステージ1へ遷移
        final state = game.gameRuntimeState;
        state.buildingPlacements.remove('outdoor_1');
        final resetPos = Vector2(-100, game.initialGameCanvasSize.y - game.player.size.y / 2);
        
        await game.sceneManager.loadScene(
          'outdoor_1',
          initialPlayerPosition: resetPos,
          onAfterLoad: () {
            game.windowManager.showDialog([
              "（……意識が戻る。周囲にはロケットの残骸が散らばっている）",
              "（……ザー……ザー……）",
              "[ベテラン調査員（通信）]",
              "「……おい、聞こえるか！？ 無事か！？」",
              "「ロケットはバラバラだ。私は少し離れた場所に不時着したらしい。……通信は生きているようだな。」",
              "「いいか、そこはもう星の胃袋の中だ。自分の『意志』をしっかり持て。さもないと……溶けるぞ。」"
            ]);
          },
        );
      },
    );
  }
}
