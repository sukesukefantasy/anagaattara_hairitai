import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../common/hitboxes/interact_hitbox.dart';
import '../../../main.dart';
import '../../../UI/windows/puzzle_window.dart';
import '../../../UI/window_manager.dart';
import '../../../puzzles/fuel_puzzle/fuel_puzzle.dart';
import '../../../puzzles/bypass_puzzle/bypass_puzzle.dart';
import '../../../puzzles/route_puzzle/route_puzzle.dart';
import '../../../puzzles/manifold_puzzle/manifold_puzzle.dart';

import '../../../system/storage/game_runtime_state.dart';
import '../../enemy/enemy_base.dart';

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

    // 必要パーツのチェック (バルブ、点火装置、ノズル)
    final parts = ['バルブ', '点火装置', 'ノズル'];
    
    // 現在のステップに必要なパーツをチェック
    if (solvedPuzzles < 3) {
      final requiredPart = parts[solvedPuzzles];
      if (game.player.itemBag.getItemCount(requiredPart) == 0) {
        game.windowManager.showDialog(
          ['ロケットを修理するためのパーツ「$requiredPart」が不足しています。'],
        );
        return;
      }
    }

    // 各ルートのコレクションアイテム
    final routeItems = {
      'outdoor_1': '石',
      'outdoor_2': '生体サンプル',
      'outdoor_3': '高出力電源',
      'outdoor_4': '記録アーカイブ',
      'outdoor_philosophy': '中枢演算コア',
      'outdoor_despair': '最終調査報告書', // デフォルト
      'outdoor_true': '中枢演算コア',
    };
    
    String? targetItemName = routeItems[stageId];

    // Stage 6 (outdoor_despair) の場合は属性に応じて要求アイテムを変える
    if (stageId == 'outdoor_despair') {
      final attr = state.activeRouteId ?? game.missionManager.getCurrentAttribute();
      switch (attr) {
        case GameRuntimeState.routeViolence: targetItemName = '殲滅完了コード'; break;
        case GameRuntimeState.routeEmpathy: targetItemName = '心のバックアップ'; break;
        case GameRuntimeState.routePhilosophy: targetItemName = '真実へのアクセスキー'; break;
        case GameRuntimeState.routeEfficiency: targetItemName = '最適化完了ログ'; break;
        default: targetItemName = '最終調査報告書';
      }
    }

    // 4番目のパズル（Manifold）の前にコレクションアイテムをチェック
    if (solvedPuzzles == 3) {
      if (targetItemName != null && game.player.itemBag.getItemCount(targetItemName) == 0) {
        final isOptimized = stageId == 'outdoor_3' && state.activeRouteId == GameRuntimeState.routeEfficiency;
        if (!isOptimized) {
          game.windowManager.showDialog(
            ['ロケットを起動するには、今回の調査対象である「$targetItemName」を統合コアにセットする必要があります。'],
          );
          return;
        }
      }

      // Stage 6 固有の「極致」チェック
      if (stageId == 'outdoor_despair') {
        final attr = state.activeRouteId ?? game.missionManager.getCurrentAttribute();
        
        if (attr == GameRuntimeState.routeViolence) {
          // Violence: 敵が残っている場合は発射不可
          final enemyCount = game.world.children.whereType<EnemyBase>().length;
          if (enemyCount > 0) {
            game.windowManager.showDialog(
              ["「……警告。周辺にノイズ（生体反応）を検知。殲滅を推奨します。」", "（すべての敵を倒してください）"],
            );
            return;
          }
        } else if (attr == GameRuntimeState.routeEmpathy) {
          // Empathy: 特定の条件（ここでは簡略化してNPCへの満足度など）
          // 実際には「残影との対話」が終わっているかをチェックしたいが、現状は全NPC満足度で代用
          final satisfiedCount = state.satisfiedNpcIds.length;
          if (satisfiedCount < 3) { // 仮のしきい値
            game.windowManager.showDialog(
              ["「彼らはまだ、何かを伝えたがっているようです。」", "（NPCたちの願いを聞いてください）"],
            );
            return;
          }
        }
      }
    }

    if (solvedPuzzles >= 4) {
      _launchRocket();
      return;
    }

    final puzzles = [
      FuelPuzzle(),      // 1. 燃料補給
      BypassPuzzle(),    // 2. 電力接続
      RoutePuzzle(),     // 3. 航路設定
      ManifoldPuzzle(
        activeAttribute: state.activeRouteId ?? game.missionManager.getCurrentAttribute()
      ),  // 4. 意識統合
    ];

    final currentPuzzle = puzzles[solvedPuzzles];

    // Philosophy Stage 6 の場合はタイトルを「真理の読解」に変更
    if (stageId == 'outdoor_despair' && solvedPuzzles == 3 && (state.activeRouteId ?? game.missionManager.getCurrentAttribute()) == GameRuntimeState.routePhilosophy) {
      currentPuzzle.title = '真理の読解：システムへの直接介入';
      currentPuzzle.description = '論理の亀裂をこじ開け、世界の「外側」へ繋がるアクセスキーを確立してください。';
    }

    game.windowManager.showWindow(
      GameWindowType.puzzle,
      PuzzleWindow(
        windowManager: game.windowManager,
        game: game,
        puzzle: currentPuzzle,
        onComplete: () {
          solvedPuzzles++;
          debugPrint('ステップ $solvedPuzzles クリア！');
          
          // パーツを１つずつ消費
          if (solvedPuzzles == 1) game.player.itemBag.removeItem('バルブ');
          if (solvedPuzzles == 2) game.player.itemBag.removeItem('点火装置');
          if (solvedPuzzles == 3) game.player.itemBag.removeItem('ノズル');
          
          if (solvedPuzzles == 4) {
            // 最後にコレクションアイテムも消費
            if (targetItemName != null) {
              game.player.itemBag.removeItem(targetItemName);
            }
            _launchRocket();
          } else {
            // 次のパズルを連続して解くか、一旦戻るか
            game.windowManager.showDialog(
              ['修理ステップ $solvedPuzzles が完了しました。次の工程に進みます。'],
              onFinish: () {
                _showPuzzle(); // 連続して次のパズルを表示
              }
            );
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
        // 演出を伴うクリア処理（メインロジックは MyGame.routeClear に集約）
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
    final bool isLap1 = state.scenarioCount == 1;

    // シナリオ2以降は人格を剥ぎ取ったシステムログにする
    if (!isLap1) {
      return [
        "[SYSTEM] Protocol: LAUNCH. Node: $stageId.",
        "[LOG] Data transmission: 100% complete.",
        "[SYSTEM] Returning to initial state..."
      ];
    }

    if (stageId == 'outdoor_despair') {
      return [
        "「……あいつも、いつかはこうなる運命だったのかもしれないな。」",
        "「お疲れ様、相棒。君だけは、どうか最後まで君のままでいてくれ。」"
      ];
    }

    if (stageId == 'outdoor_true') {
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
          '次回の調査に備えよう。',
        ];
    }
  }
}
