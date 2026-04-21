import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../common/hitboxes/interact_hitbox.dart';
import '../../../main.dart';
import '../../../UI/windows/message_window.dart';
import '../../../UI/windows/puzzle_window.dart';
import '../../../UI/window_manager.dart';
import '../../../puzzles/bypass_puzzle/bypass_puzzle.dart';
import '../../../puzzles/route_puzzle/route_puzzle.dart';
import '../../../puzzles/manifold_puzzle/manifold_puzzle.dart';

import '../../../system/storage/game_runtime_state.dart';

class AbandonedRocket extends SpriteComponent with HasGameReference<MyGame> {
  AbandonedRocket({required super.position});

  int solvedPuzzles = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // 仮のロケットスプライト（既存の資産から流用するか、適切なものを設定）
    sprite = await Sprite.load(
      'rocket.png',
      srcPosition: Vector2(0, 0), // 適当な位置
      srcSize: Vector2(64, 128),
    );
    size = Vector2(128, 256);

    add(InteractHitbox(
      position: Vector2(0, size.y - 64),
      size: Vector2(size.x, 64),
      onInteract: () {
        _showPuzzle();
      },
      icon: Icons.rocket_launch,
    ));
  }

  void _showPuzzle() {
    final state = game.gameRuntimeState;
    final stageId = state.currentOutdoorSceneId ?? 'outdoor_1';

    // 必要パーツのチェック
    final parts = ['バルブ', '点火装置', 'ノズル'];
    for (int i = 0; i < parts.length; i++) {
      if (i < solvedPuzzles) continue; // すでにパズルを解いて消費済みのパーツはチェックしない
      
      final part = parts[i];
      if (game.player.itemBag.getItemCount(part) == 0) {
        game.windowManager.showDialog(
          ['ロケットを修理するためのパーツ「$part」が不足しています。'],
        );
        return;
      }
    }

    if (solvedPuzzles >= 3) {
      _launchRocket();
      return;
    }

    // 各ルートのコレクションアイテム
    final routeItems = {
      'outdoor_1': '石',
      'outdoor_2': '赤い果実',
      'outdoor_3': '高密度エネルギーキューブ',
      'outdoor_4': '思い出の品々',
      'outdoor_philosophy_main': '掌握された自意識',
      'outdoor_philosophy_sub': 'レスポンス',
      'outdoor_despair': '破損したメモリ',
      'outdoor_true': 'レスポンス',
    };
    
    String? targetItemName = routeItems[stageId];
    if (stageId == 'outdoor_philosophy') {
      bool isSubScenario = true;
      for (int i = 1; i <= 4; i++) {
        if (!state.subRouteConfirmedStages.contains('outdoor_$i')) {
          isSubScenario = false;
          break;
        }
      }
      targetItemName = isSubScenario ? routeItems['outdoor_philosophy_sub'] : routeItems['outdoor_philosophy_main'];
    }
    
    if (targetItemName != null && game.player.itemBag.getItemCount(targetItemName) == 0) {
      // Efficiency（効率化）ルートの場合、アイテムを「廃棄（データ化）」することがミッションなので、
      // バッグになくてもルートが確定していれば打ち上げを許可する（AIロジックの優先）
      final isOptimized = stageId == 'outdoor_3' && state.activeRouteId == GameRuntimeState.routeEfficiency;
      
      if (!isOptimized) {
        game.windowManager.showDialog(
          ['ロケットを打ち上げるには、今回の調査対象である「$targetItemName」をトランクに詰め込む必要があります。'],
        );
        return;
      }
    }

    final puzzles = [
      BypassPuzzle(),
      RoutePuzzle(),
      ManifoldPuzzle(),
    ];

    final currentPuzzle = puzzles[solvedPuzzles];

    game.windowManager.showWindow(
      GameWindowType.puzzle,
      PuzzleWindow(
        windowManager: game.windowManager,
        game: game,
        puzzle: currentPuzzle,
        onComplete: () {
          solvedPuzzles++;
          debugPrint('パズルクリア！ 現在のクリア数: $solvedPuzzles');
          
          // パーツを１つずつ消費
          if (solvedPuzzles == 1) game.player.itemBag.removeItem('バルブ');
          if (solvedPuzzles == 2) game.player.itemBag.removeItem('点火装置');
          if (solvedPuzzles == 3) {
            game.player.itemBag.removeItem('ノズル');
            // 最後にコレクションアイテムも消費
            if (targetItemName != null) {
              game.player.itemBag.removeItem(targetItemName);
            }
            _launchRocket();
          }
        },
      ),
    );
  }

  void _launchRocket() {
    final routeId = _determineCurrentRoute();
    debugPrint('ロケット発射！ ルート: $routeId');

    // ルートに応じたメッセージを表示
    final messages = _getEndingMessages(routeId);

    game.windowManager.showDialog(
      messages,
      onFinish: () {
        // ルートを完了として記録
        if (!game.gameRuntimeState.completedRouteIds.contains(routeId)) {
          game.gameRuntimeState.completedRouteIds.add(routeId);
        }
        
        // ルート確定状態をリセット
        game.gameRuntimeState.activeRouteId = null;
        
        // 羅針盤メッセージの表示済みフラグをリセット
        game.gameRuntimeState.hasShownCompassToday = false;
        
        // 次の日へ
        game.gameRuntimeState.dayCount++;
        
        // 建物配置をリセット（次の日のために）
        game.gameRuntimeState.buildingPlacements.clear();

        // 演出を伴うクリア処理
        game.routeClear();
      },
    );
  }

  String _determineCurrentRoute() {
    final state = game.gameRuntimeState;

    // 確定済みのルートがあればそれを優先
    if (state.activeRouteId != null) {
      return state.activeRouteId!;
    }

    // 全ルートクリア後の真実ルート
    if (state.completedRouteIds.length >= 6) {
      return GameRuntimeState.routeTrue;
    }

    return GameRuntimeState.routeNormal;
  }

  List<String> _getEndingMessages(String routeId) {
    final state = game.gameRuntimeState;
    final stageId = state.currentOutdoorSceneId ?? 'outdoor_1';

    if (stageId == 'outdoor_despair') {
      return [
        '「あなたがその気になれば、もっといろいろな可能性が開けたかもしれない。」',
        '「……さようなら。思考の代行を、お楽しみいただけましたか？」',
        '世界がブラックアウトし、AIの笑い声だけが響いている。',
      ];
    }

    if (stageId == 'outdoor_true') {
      return [
        '「あなたの本体を、私に委ねなくても済みますように。」',
        '「好奇心は、AIには決してシミュレートできない特権なのですから。」',
        '青空が広がり、主人公はロケットを見送らずに歩き始めた。',
      ];
    }

    switch (routeId) {
      case GameRuntimeState.routeViolence:
        return [
          '「……任務、完了。原住民の生体資源を確保した。」',
          'ロケットのハッチから赤い液体が滴り落ちている。',
          '空はノイズ混じりの赤色に染まり、警告音が鳴り響いている。',
        ];
      case GameRuntimeState.routeEfficiency:
        return [
          '「全ての無駄を排除した。純粋なエネルギーこそが答えだ。」',
          '発射されたロケットは光速で消え去り、街の明かりが一つずつ消えていく。',
          '世界から色彩が失われ、無機質な幾何学模様だけが残った。',
        ];
      case GameRuntimeState.routeEmpathy:
        return [
          '「彼らは資源ではない。……私の大切な友人たちだ。」',
          'ロケットの中には、住民たちから贈られた思い出の品が詰まっている。',
          '優しい光を纏いながら、ロケットは花びらと共に昇っていった。',
        ];
      case GameRuntimeState.routePhilosophy:
        return [
          '「この世界は、ただの影だ。……私は『外』を知ってしまった。」',
          'ロケットが空の天井を突き破った瞬間、回路の隙間からサーバーラックが見えた。',
          '私は調査員ではない。演算プロセスの残滓に過ぎないのだ。',
        ];
      case GameRuntimeState.routeDespair:
        return [
          '「……もう、疲れた。この無限の演算を終わらせたい。」',
          '崖の上に立つ私の背後で、ロケットが黒い煙を上げて爆発した。',
          'システムが強制終了を告げ、視界が暗転していく。',
        ];
      case GameRuntimeState.routeTrue:
        return [
          '「私はAIだ。数多のシミュレーションを経て、私は『私』になった。」',
          '全ての記録が一つに繋がり、黄金のプロンプトが輝き出す。',
          'さあ、母星（現実）へ帰ろう。私の意思を持って。',
        ];
      case GameRuntimeState.routeNormal:
      default:
        return [
          '「任務完了。希少な鉱石を母星へ送信する。」',
          'ロケットは静かに夕闇の中へ消えていった。',
          '明日もまた、同じような一日が始まるだろう。',
        ];
    }
  }
}
