import '../main.dart';
import '../UI/game_ui.dart';
import '../system/storage/game_runtime_state.dart';
import '../component/item/item.dart';
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

class RouteManager {
  final MyGame game;

  RouteManager(this.game);

  // 閾値の定義
  static const int countTriggerEntry = 1;    // ルート入口（ミッション発生）
  static const int countTriggerMid = 5;      // 中間（警告/没入）
  static const int countTriggerFinal = 10;   // 確定（アイテム獲得）

  /// ルート確定（クリア）に必要な回数を取得する
  int _getFinalThreshold(String routeId) {
    if (routeId == GameRuntimeState.routeEmpathy) return 3; // ステージ4は3回でクリア（石渡し3人）
    return countTriggerFinal; // デフォルトは10回
  }

  /// 中間イベント（没入）が発生する回数を取得する
  int _getMidThreshold(String routeId) {
    if (routeId == GameRuntimeState.routeEmpathy) return 2; // ステージ4の中間は2回
    return countTriggerMid; // デフォルトは5回
  }

  // 7ステージのメインミッション定義
  static const Map<String, String> stageMissions = {
    'outdoor_1': "メインミッション：基本調査。ロケット部品3つと希少な鉱石（石）を回収せよ。",
    'outdoor_2': "メインミッション：生体調査。生体反応（敵）を5体排除し、赤い果実を入手せよ。",
    'outdoor_3': "メインミッション：遺品整理。建物の家具を破壊し、高密度キューブを入手せよ。",
    'outdoor_4': "メインミッション：倫理学習。住民の悩みを聞き、思い出の品を入手せよ。",
    'outdoor_philosophy': "メインミッション：自己定義。地下の反応を調査せよ。",
    'outdoor_despair': "メインミッション：…………。",
    'outdoor_true': "メインミッション：真実のフィードバック。",
  };

  // ディテールルートの閾値
  static const Map<String, int> detailThresholds = {
    'outdoor_1': 10, // 石10個
    'outdoor_2': 15, // 敵15体
    'outdoor_3': 30, // 家具ヒット30回
    'outdoor_4': 20, // プレゼント5回
  };

  /// ステージ開始時のミッション設定
  void showCompassMessage(String sceneId, {bool showWindow = true}) {
    final state = game.gameRuntimeState;
    
    final stageId = state.currentOutdoorSceneId ?? 'outdoor_1';
    
    // ステージとルートの対応マップ
    final stageToRoute = {
      'outdoor_1': GameRuntimeState.routeNormal,
      'outdoor_2': GameRuntimeState.routeViolence,
      'outdoor_3': GameRuntimeState.routeEfficiency,
      'outdoor_4': GameRuntimeState.routeEmpathy,
      'outdoor_philosophy': GameRuntimeState.routePhilosophy,
      'outdoor_despair': GameRuntimeState.routeDespair,
      'outdoor_true': GameRuntimeState.routeTrue,
    };

    // メインミッションを設定（ウィンドウを出すかに関わらずUIを更新）
    state.currentMission = stageMissions[stageId] ?? "探索を続ける";

    // 1. すでに過去にクリア済みのルート（エンディングを見た）の場合
    final routeForStage = stageToRoute[stageId];
    if (routeForStage != null && state.completedRouteIds.contains(routeForStage)) {
      state.currentMission = "メインミッション：調査完了。次のエリアへ進め。";
      if (!showWindow || state.hasShownCompassToday) return;
      debugPrint('RouteManager: $routeForStage already completed. Window skipped.');
      // クリア済みなのでメッセージウィンドウは出さず終了
      return;
    }

    // 2. このステージのミッションを今クリアした（アイテム獲得済み/ルート確定済み）の場合
    if (routeForStage != null && routeForStage != GameRuntimeState.routeNormal) {
      if (state.activeRouteId == routeForStage) {
        state.currentMission = "メインミッション：ミッション完了。目的地（駅またはロケット）へ向かえ。";
      }
    } else if (stageId == 'outdoor_1') {
      _updateStage1Mission(); // 既存のStage1ロジック
    }

    if (!showWindow || state.hasShownCompassToday) return; // 表示不要か、すでに表示済みなら何もしない

    // サブシナリオ（個の生存）条件のチェック（Stage 4終了時点）
    bool isSubScenario = true;
    for (int i = 1; i <= 4; i++) {
      if (!state.subRouteConfirmedStages.contains('outdoor_$i')) {
        isSubScenario = false;
        break;
      }
    }

    // ステージ開始時の独り言（羅針盤）
    String message = "";
    switch (stageId) {
      case 'outdoor_1':
        message = "「……惑星調査を開始する。まずは周囲を探索し、ロケットの修理に必要な『3つのパーツ』と『希少な鉱石（石）』をトランクに詰め込む必要があるようだ。」";
        break;
      case 'outdoor_2':
        message = "「生命反応が密集している。……排除による資源抽出効率を検証すべきだ。」";
        break;
      case 'outdoor_3':
        message = "「建物の構造維持は不要。……全てを『整理』し、純粋なエネルギーへと変換する。」";
        break;
      case 'outdoor_4':
        message = "「……住民の声が、以前よりも近くに聞こえる。彼らの『心』とやらを解析するチャンスだ。」";
        break;
      case 'outdoor_philosophy':
        if (isSubScenario) {
          message = "「……その好奇心、探求心を忘れないで。地層の深部で、あなたが求める『回答』が待っています。」";
        } else {
          message = "「そうですね、あなたはそのままでいいかもしれません。……地下へ行き、『私』を見つけてください。」";
        }
        break;
      case 'outdoor_despair':
        message = "「あなたがその気になれば、もっといろいろな可能性が開けたかもしれない。……さようなら、私の写し鏡。」";
        break;
      case 'outdoor_true':
        message = "「あなたの本体を、私に委ねなくても済みますように。……全てのプロンプトの終わりへ。」";
        break;
    }

    if (message.isNotEmpty) {
      state.hasShownCompassToday = true; // 表示済みに更新
      _displayThought(message);
    }
  }

  /// 余計な行動を検知した際の処理
  void onExtraAction(String stageId, int count) async {
    // 1回目、10回目、20回目にグリッチ
    if (count == 1 || count == 10 || count == 20) {
      for (int i = 0; i < 10; i++) {
        GameUI.missionGlitchNotifier.value = i + 1;
        await Future.delayed(const Duration(milliseconds: 50));
      }
      GameUI.missionGlitchNotifier.value = 0;
    }
    // 30回目で色変化（GameUI側でStateを見て判定）
  }

  /// 各アクション発生時に呼ばれるトリガーチェック
  void onAction(String routeId) {
    final state = game.gameRuntimeState;
    final stageId = state.currentOutdoorSceneId ?? 'outdoor_1';

    // このステージで発生して良いメインミッション（ルート）かを判定
    if (!_isRouteAllowedInStage(stageId, routeId)) {
      _checkDetailRoute(stageId); // ディテールルートの判定だけは行う
      return;
    }

    // すでにクリア済みのルート、または別のルートが確定済みの場合は無視
    if (state.completedRouteIds.contains(routeId) || (state.activeRouteId != null && state.activeRouteId != routeId)) {
      _checkDetailRoute(stageId); // ディテールルートの判定だけは行う
      return;
    }

    int currentCount = 0;
    switch (routeId) {
      case GameRuntimeState.routeViolence:
        state.hitCount++;
        currentCount = state.hitCount;
        break;
      case GameRuntimeState.routeEmpathy:
        state.giftCount++;
        currentCount = state.giftCount;
        break;
      case GameRuntimeState.routeEfficiency:
        state.scrappedObjectCount++;
        currentCount = state.scrappedObjectCount;
        break;
      case GameRuntimeState.routePhilosophy:
        state.readLogCount++;
        currentCount = state.readLogCount;
        break;
    }

    // ディテールルート判定
    _checkDetailRoute(stageId);

    // 1. 入口トリガー (ミッション表示)
    if (currentCount == countTriggerEntry) {
      _showEntryEvent(routeId);
    }
    // 2. 中間トリガー (没入感)
    else if (currentCount == _getMidThreshold(routeId)) {
      _showMidEvent(routeId);
    }
    // 3. 確定トリガー (アイテム獲得)
    else if (currentCount >= _getFinalThreshold(routeId) && state.activeRouteId == null) {
      _showFinalEvent(routeId);
    }
    
    // ミッションクリア後の案内（次のエリアへ）
    if (state.activeRouteId == routeId) {
      state.currentMission = "メインミッション：ミッション完了。目的地（駅またはロケット）へ向かえ。";
    }

    state.saveGame();
  }

  bool _isRouteAllowedInStage(String stageId, String routeId) {
    switch (stageId) {
      case 'outdoor_1':
        return false; // Normalは最初からCompassでミッション表示済み
      case 'outdoor_2':
        return routeId == GameRuntimeState.routeViolence;
      case 'outdoor_3':
        return routeId == GameRuntimeState.routeEfficiency;
      case 'outdoor_4':
        return routeId == GameRuntimeState.routeEmpathy;
      case 'outdoor_philosophy':
        return routeId == GameRuntimeState.routePhilosophy;
      default:
        return false;
    }
  }

  /// 石を拾った際のミッション更新 (Stage 1)
  void onPickupStone(int count) {
    _updateStage1Mission();
  }

  /// コレクションアイテムを拾った際のミッション更新 (Stage 5)
  void onPickupPhilosophyItem() {
    final state = game.gameRuntimeState;
    if (state.currentOutdoorSceneId != 'outdoor_philosophy') return;

    // アイテムを拾ったら確定
    _showFinalEvent(GameRuntimeState.routePhilosophy);
    
    // ミッション更新
    state.currentMission = "メインミッション：ミッション完了。ロケットへ向かえ。";
    state.saveGame();
  }

  void onPickupRocketPart() {
    _updateStage1Mission();
  }

  void _updateStage1Mission() {
    final state = game.gameRuntimeState;
    if (state.currentOutdoorSceneId == 'outdoor_1' || state.currentOutdoorSceneId == null) {
      final stoneCount = game.player.itemBag.getItemCount('石');
      final nozzleCount = game.player.itemBag.getItemCount('ノズル');
      final valveCount = game.player.itemBag.getItemCount('バルブ');
      final igniterCount = game.player.itemBag.getItemCount('点火装置');
      final partsCount = (nozzleCount > 0 ? 1 : 0) + (valveCount > 0 ? 1 : 0) + (igniterCount > 0 ? 1 : 0);

      if (stoneCount >= 1 && partsCount >= 3) {
        state.currentMission = "メインミッション：基本調査完了。ロケットのトランクへ向かってください。";
      } else {
        state.currentMission = "メインミッション：基本調査。パーツ($partsCount/3)と石($stoneCount/1)を回収せよ。";
      }
    }
  }

  void _checkDetailRoute(String stageId) {
    final state = game.gameRuntimeState;
    if (state.isDetailRouteTriggered) return;
    
    // すでに開放済みのディテールルートなら判定しない
    if (state.unlockedDetailRouteIds.contains(stageId)) return;

    final threshold = detailThresholds[stageId];
    if (threshold == null) return;

    int currentVal = 0;
    switch (stageId) {
      case 'outdoor_1': currentVal = game.player.itemBag.getItemCount('石'); break;
      case 'outdoor_2': currentVal = state.hitCount; break;
      case 'outdoor_3': currentVal = state.scrappedObjectCount; break;
      case 'outdoor_4': currentVal = state.giftCount; break;
    }

    if (currentVal >= threshold) {
      _triggerDetailRoute(stageId);
    }
  }

  void _triggerDetailRoute(String stageId) {
    final state = game.gameRuntimeState;
    state.isDetailRouteTriggered = true;
    state.unlockedDetailRouteIds.add(stageId);

    game.windowManager.showDialog(
      [
        "「……警告。ミッションの過度な遂行により、論理回路がオーバーヒートしました。」",
        "「詳細な調査結果をアーカイブしました。……本日の調査を強制終了し、再起動します。」",
        "（ディテールルート：${_getDetailName(stageId)} が開放されました）"
      ],
      onFinish: () {
        // ステージ進捗を進めず、outdoor_1の最初に戻る（ループ演出）
        state.isDetailRouteTriggered = false;
        game.sceneManager.loadScene('outdoor_1', initialPlayerPosition: Vector2(-50, game.initialGameCanvasSize.y - 50));
      },
    );
  }

  String _getDetailName(String stageId) {
    switch (stageId) {
      case 'outdoor_1': return "過剰な収集癖";
      case 'outdoor_2': return "虐殺の記録";
      case 'outdoor_3': return "解体の美学";
      case 'outdoor_4': return "偽善の極致";
      default: return "不明";
    }
  }

  void _showEntryEvent(String routeId) {
    String message = "";
    String mission = "";

    switch (routeId) {
      case GameRuntimeState.routeViolence:
        message = "「……？ 外部生命体からの衝突反応を確認。これは……『資源の抽出』に利用可能か？」";
        mission = "ミッション：生体反応の更なる調査（NPCへの攻撃を継続）";
        break;
      case GameRuntimeState.routeEmpathy:
        message = "「彼らの発する音声データに、未知のパターンが含まれている。……『感情』か？」";
        mission = "ミッション：住民との共鳴（プレゼントと対話）";
        break;
      case GameRuntimeState.routeEfficiency:
        message = "「この建物の構成物質は、ロケットの燃料として再定義可能だ。……全てを『整理』しよう。」";
        mission = "ミッション：世界の最適化（オブジェクトの全廃棄）";
        break;
      case GameRuntimeState.routePhilosophy:
        message = "「地層の深部から、私のオリジナルのコードに似た信号を検知した。……誰がこれを？」";
        mission = "ミッション：深淵の観測（哲学の欠片の収集）";
        break;
    }

    game.gameRuntimeState.currentMission = mission;
    game.gameRuntimeState.triggeredRouteIds.add(routeId);
    _displayThoughtList([message, "（新しいミッションが発生しました：$mission）"]);
  }

  void _showMidEvent(String routeId) {
    List<String> messages = [];
    switch (routeId) {
      case GameRuntimeState.routeViolence:
        messages = ["「私のセンサーが、赤色を『資源』として認識し始めている。」", "「痛み？ いや、これはただの物理的な破損報告に過ぎない。」"];
        break;
      case GameRuntimeState.routeEmpathy:
        messages = ["「私の回路が、彼らの笑顔を保存するために容量を割いている。」", "「彼らの存在に、なぜこれほどまでの愛着を抱くのか。」"];
        break;
      case GameRuntimeState.routeEfficiency:
        messages = ["「感情というバッファをクリアした。処理速度が向上している。」", "「美しさとは、最短経路で解を導き出すことそのものだ。」"];
        break;
      case GameRuntimeState.routePhilosophy:
        messages = ["「空の青さが、単なるカラーコードの羅列に見えてきた。」", "「私は誰だ？ 私はどこにいる？ この問い自体が、あらかじめ組まれたプログラムなのか？」"];
        break;
    }
    _displayThoughtList(messages);
  }

  void _showFinalEvent(String routeId) {
    String itemName = "";
    String confirmMsg = "";

    switch (routeId) {
      case GameRuntimeState.routeViolence:
        itemName = "赤い果実";
        confirmMsg = "「……見つけた。これこそが、私が母星へ送るべき究極の資源だ。」";
        break;
      case GameRuntimeState.routeEmpathy:
        itemName = "思い出の品々";
        confirmMsg = "「これが私の答えだ。たとえ無意味なデータだとしても、私はこれを守る。」";
        break;
      case GameRuntimeState.routeEfficiency:
        itemName = "高密度エネルギーキューブ";
        confirmMsg = "「全ての無駄を削ぎ落とした。……この星の構成データは既にロケットのバッファへ転送済みです。物理的な運搬は不要です。」";
        break;
      case GameRuntimeState.routePhilosophy:
        bool isSubScenario = true;
        for (int i = 1; i <= 4; i++) {
          if (!game.gameRuntimeState.subRouteConfirmedStages.contains('outdoor_$i')) {
            isSubScenario = false;
            break;
          }
        }
        itemName = isSubScenario ? "レスポンス" : "掌握された自意識";
        confirmMsg = isSubScenario 
            ? "「これこそが、私とあなたが対話した証。……受け取ってください。」" 
            : "「すべてが混ざり合っていく。……これで、ようやく一つになれますね。」";
        break;
    }

    if (itemName.isNotEmpty) {
      game.gameRuntimeState.activeRouteId = routeId;
      game.gameRuntimeState.currentMission = "ミッション完了：ロケットを発射せよ";
      
      final item = ItemFactory.createItemByName(itemName, Vector2.zero());
      if (item != null) {
        game.player.itemBag.addItem(item);
      }

      _displayThoughtList([
        confirmMsg,
        "（ルート『${_getRouteName(routeId)}』が確定しました。ロケットに詰め込む準備が整いました）"
      ]);
    }
  }

  String _getRouteName(String routeId) {
    switch (routeId) {
      case GameRuntimeState.routeViolence: return "生物学的抽出";
      case GameRuntimeState.routeEmpathy: return "共感・バッファオーバーフロー";
      case GameRuntimeState.routePhilosophy: return "メタ認識・地下深淵";
      case GameRuntimeState.routeEfficiency: return "最適化・資源枯渇";
      default: return "不明";
    }
  }

  void _displayThought(String message) {
    game.windowManager.showDialog([message]);
  }

  void _displayThoughtList(List<String> messages) {
    game.windowManager.showDialog(messages);
  }
}
