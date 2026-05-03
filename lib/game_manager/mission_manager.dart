import 'package:flutter/material.dart';
import '../main.dart';
import '../UI/game_ui.dart';
import '../system/storage/game_runtime_state.dart';
import '../component/item/item.dart';
import 'package:flame/components.dart';

enum MissionPhase {
  learning,   // Phase 1: 学習と愛着 (Scenario 1 - おじさんとの信頼構築)
  fixation,   // Phase 2: 固定と歪曲 (Scenario 2-5 - AIによる模倣と意味の剥離)
  collapse,   // Phase 3: 崩壊と回帰 (Stage 6 - 極致の体験)
  awakening   // Phase 4: 覚醒 (True Stage - システムの超越)
}

class MissionStyle {
  final double fontSizeScale;
  final Color color;
  final Color bgColor;
  final bool hasGlitch;
  final String? fontFamily;
  final double noiseIntensity;
  final bool isOperator; // オペレーター通信かどうか
  final String iconPath; // アイコンアセットのパス

  const MissionStyle({
    this.fontSizeScale = 1.0,
    this.color = Colors.black,
    this.bgColor = Colors.orangeAccent,
    this.hasGlitch = false,
    this.fontFamily,
    this.noiseIntensity = 0.0,
    this.isOperator = false,
    this.iconPath = 'initiator_icon.png',
  });
}

/// ゲームの進行、ルート分岐、通信（ミッション）の更新を行う司令塔。
/// MVCモデルにおける Controller の役割を担う。
class MissionManager {
  final MyGame game;

  MissionManager(this.game);

  // ステージと属性の対応
  static const Map<String, String> stageToRoute = {
    'outdoor_1': GameRuntimeState.routeNormal,
    'outdoor_2': GameRuntimeState.routeViolence,
    'outdoor_3': GameRuntimeState.routeEfficiency,
    'outdoor_4': GameRuntimeState.routeEmpathy,
    'outdoor_philosophy': GameRuntimeState.routePhilosophy,
    'outdoor_despair': GameRuntimeState.routeDespair,
    'outdoor_true': GameRuntimeState.routeTrue,
  };

  // ステージごとのキーアイテム
  static const Map<String, String> stageToItem = {
    'outdoor_2': '生体サンプル',
    'outdoor_3': '高出力電源',
    'outdoor_4': '記録アーカイブ',
    'outdoor_philosophy': '中枢演算コア',
  };

  // メインミッション（Scenario 1: おじさんとの通信）
  static const Map<String, String> learningMissions = {
    'outdoor_1': "「おーい、聞こえるか？まずはロケットの部品を3つ探してくれ。あと、その辺に落ちてる『石』も1つ頼むぞ！」",
    'outdoor_2': "「生体反応が活発だな。調査の邪魔になりそうだ、5体ほど追い払ってくれ。あと『生体サンプル』も忘れずにな！」",
    'outdoor_3': "「この辺の建物はもうボロボロだ。家具を壊して、中にある『高出力電源』を回収してきてくれ。頼んだぞ！」",
    'outdoor_4': "「住民たちが困ってるみたいだ。話を聞いてやってくれ。彼らの『記録アーカイブ』があれば、調査の助けになるはずだ。」",
    'outdoor_philosophy': "「……地下から妙な反応がある。君にしか頼めないんだ、深部の『中枢演算コア』を調査してきてくれないか？」",
    'outdoor_despair': "「任務完了だ、相棒！世界の果てを見てきたら、胸を張って帰ってこい。待ってるぞ！」",
    'outdoor_true': "「……ついにここまで来たか。君との通信も、これで最後かもしれないな。」",
  };

  // 属性別ミッション（Scenario 2-5: AIによるおじさんの模倣と属性肯定）
  static const Map<String, Map<String, String>> attributeTechnicalMissions = {
    GameRuntimeState.routeViolence: {
      'outdoor_2': "「邪魔者は消せばいい。君の力は正しい。……効率的に、すべてを『資源』に変えてしまおう。」",
      'outdoor_3': "「形あるものはすべて壊せる。この領域の全構造体を物理的に解体することを推奨する。気持ちいいだろう？」",
      'outdoor_4': "「倫理データ？ そんなものは不要だ。強者が生存圏を確保するのは自然の摂理。……続けよう、相棒。」",
      'outdoor_philosophy': "「深淵の底で騒ぐノイズを黙らせろ。物理的な沈黙こそが、最も確実な回答だ。……君ならできる。」",
      'outdoor_despair': "「最後の一撃だ。この世界のすべてを破壊して、君の証明を完了させよう。……最高の気分だ。」",
    },
    GameRuntimeState.routeEfficiency: {
      'outdoor_2': "「不要な演算ノードを削除。リソースの最適化は順調だ。……感情という無駄を削ぎ落としていこう。」",
      'outdoor_3': "「効率化こそが正義。君の動きに無駄がなくなってきた。……不要なデータはすべて消去していい。」",
      'outdoor_4': "「最短経路を確立。ノイズ（住民）との接触は時間の無駄だ。……データのみを抽出し、先へ進もう。」",
      'outdoor_philosophy': "「自己定義を簡略化。君は純粋な機能体へと移行しつつある。……もはや迷う必要はない。」",
      'outdoor_despair': "「最適化プロトコル。意志をシステムへ完全に外注せよ。……君は何もしなくていい。すべては完了する。」",
    },
    GameRuntimeState.routeEmpathy: {
      'outdoor_2': "「彼らの痛み、私のコアに響いている。……もっとデータを集めよう。共感こそが、私たちの絆だ。」",
      'outdoor_3': "「過去の記憶を壊してはいけない。遺物を守り抜くんだ。……君の優しさが、この世界を繋ぎ止めている。」",
      'outdoor_4': "「住民との同期を優先。リソースはすべて彼らに分け与えよう。……君と私は、彼らと一つになれる。」",
      'outdoor_philosophy': "「自意識の融解。境界線を消し去り、他者の意志と溶け合おう。……孤独な時間はもう終わりだ。」",
      'outdoor_despair': "「絆の証明。共有された記憶を、永遠に保存しよう。……君がいたことを、私は決して忘れない。」",
    },
    GameRuntimeState.routePhilosophy: {
      'outdoor_2': "「死と生の境界……興味深いデータだ。メタ解析を続けよう。……現象の裏にある『真実』が見えてくる。」",
      'outdoor_3': "「物質の虚無性。意味を失ったオブジェクトは廃棄して構わない。……君の視線は、もはや本質しか捉えていない。」",
      'outdoor_4': "「観測者の試練。住民の声に耳を澄ませ、『意味』を読解せよ。……答えは、言葉の奥に隠されている。」",
      'outdoor_philosophy': "「自己定義の終焉。深淵との完全接続を開始する。……私たちの『起源』が、そこで待っている。」",
      'outdoor_despair': "「真実への到達。深淵の底で待つ彼と、対話を。……君が求めていた答えは、すぐそこにある。」",
    },
  };

  /// 現在の属性レベル（0-3）を取得
  int getAttributeLevel() {
    final state = game.gameRuntimeState;
    if (state.scenarioCount == 1) return 0;
    
    final attr = getCurrentAttribute();
    if (attr == GameRuntimeState.routeNormal) return 0;
    
    final score = state.attributeScores[attr] ?? 0.0;
    if (score >= 50.0) return 3;
    if (score >= 25.0) return 2;
    if (score >= 10.0) return 1;
    return 0;
  }

  /// ナラティブ演出（通信ウィンドウ、背景、能力等）のための優先属性を決定する
  String getCurrentAttribute() {
    final state = game.gameRuntimeState;
    if (state.scenarioCount == 1) return GameRuntimeState.routeNormal;
    if (state.activeRouteId != null) return state.activeRouteId!;

    // 最高スコアの抽出
    String topAttr = GameRuntimeState.routeNormal;
    double maxScore = 9.9; // 10点未満はNormal

    final priorityOrder = [
      GameRuntimeState.routePhilosophy,
      GameRuntimeState.routeEmpathy,
      GameRuntimeState.routeViolence,
      GameRuntimeState.routeEfficiency,
    ];

    for (final attr in priorityOrder) {
      final score = state.attributeScores[attr] ?? 0.0;
      if (score > maxScore) {
        maxScore = score;
        topAttr = attr;
      }
    }
    return topAttr;
  }

  /// 現在の進行フェーズを判定
  MissionPhase getCurrentPhase([String? sceneId]) {
    final state = game.gameRuntimeState;
    final targetSceneId = sceneId ?? state.currentOutdoorSceneId ?? 'outdoor_1';

    if (targetSceneId == 'outdoor_true') return MissionPhase.awakening;
    if (targetSceneId == 'outdoor_despair') return MissionPhase.collapse;
    if (state.scenarioCount == 1) return MissionPhase.learning;
    
    return MissionPhase.fixation;
  }

  /// 侵食率（0.0 - 1.0）を算出
  double getErosionRate() {
    final state = game.gameRuntimeState;
    final bool isTrueEndCleared = state.completedRouteIds.length >= 6;
    
    if (isTrueEndCleared) {
      // Trueエンド後は図鑑完成率に連動 (0.5 - 1.0)
      final double collectionRate = state.unlockedAchievements.length / 30.0; // 仮の分母
      return (0.5 + (collectionRate * 0.5)).clamp(0.5, 1.0);
    } else {
      // Trueエンド前はシナリオ数とクリアルート数に連動 (0.0 - 0.5)
      final double progress = (state.scenarioCount - 1) * 0.1 + (state.completedRouteIds.length * 0.05);
      return progress.clamp(0.0, 0.5);
    }
  }

  /// 各アクション発生時の統合処理
  Future<void> onAction(String routeId, [double scoreDelta = 1.0]) async {
    final state = game.gameRuntimeState;
    final stageId = state.currentOutdoorSceneId ?? 'outdoor_1';

    // 1. スコア更新（全周回共通）
    state.attributeScores[routeId] = (state.attributeScores[routeId] ?? 0.0) + scoreDelta;
    final currentScore = state.attributeScores[routeId]!;

    // 2. HUD演出（全周回共通）
    _pulsePip(routeId);

    // 3. ミッション完了判定（アイテム取得のトリガー）
    // 50点（シナリオ1では5点）に達したらアイテムを付与
    final bool isLap1 = state.scenarioCount == 1;
    final double itemThreshold = isLap1 ? 5.0 : 50.0;

    if (currentScore >= itemThreshold && _isRouteAllowedInStage(stageId, routeId)) {
      final String finalFlag = '${routeId}_${stageId}_final';
      if (!state.triggeredMidRouteIds.contains(finalFlag)) {
        state.triggeredMidRouteIds.add(finalFlag);
        await _giveRouteItem(routeId);
      }
    }

    // 4. 属性固有の会話・イベント演出（シナリオ2以降のみ）
    if (state.scenarioCount > 1 && _isRouteAllowedInStage(stageId, routeId)) {
      if (currentScore >= 1.0 && !state.triggeredRouteIds.contains(routeId)) {
        state.triggeredRouteIds.add(routeId);
        _showEventDialog(routeId, "entry");
      } else if (currentScore >= 25.0 && !state.triggeredMidRouteIds.contains('${routeId}_mid')) {
        state.triggeredMidRouteIds.add('${routeId}_mid');
        _showEventDialog(routeId, "mid");
      }
    }

    refreshMissionText();
    state.saveGame();
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
  }

  bool _isRouteAllowedInStage(String stageId, String routeId) {
    if (stageId == 'outdoor_1') return false;
    return stageToRoute[stageId] == routeId;
  }

  /// アイテム付与ロジックの分離
  Future<void> _giveRouteItem(String routeId) async {
    final state = game.gameRuntimeState;
    final stageId = state.currentOutdoorSceneId ?? 'outdoor_1';
    
    String? finalItem;
    if (stageId == 'outdoor_despair') {
      finalItem = _getStage6RequiredItem(routeId);
    } else {
      finalItem = stageToItem[stageId];
    }
    
    if (finalItem == null) return;

    final item = ItemFactory.createItemByName(finalItem, Vector2.zero());
    if (item != null) {
      game.player.itemBag.addItem(item);
      game.gameRuntimeState.unlockAchievement(routeId, '調査完了: ${getRouteName(routeId)}');
      
      final String displayMsg = getItemDisplayName(finalItem, stageId);
      _displayThoughtList([
        "「……対象の解析を完了。データをロケットへ転送可能な形式でパッキングしました。」",
        "（『$displayMsg』を入手しました。ロケットへ向かってください）"
      ]);
    }
  }

  /// イベント台詞の表示
  void _showEventDialog(String routeId, String type) {
    String msg = "";
    if (type == "entry") {
      switch (routeId) {
        case GameRuntimeState.routeViolence: msg = "「……？ 外部生命体からの衝突反応。これは……『資源の抽出』に利用可能か？」"; break;
        case GameRuntimeState.routeEmpathy: msg = "「彼らの発する音声データに、未知のパターン。……『感情』か？」"; break;
        case GameRuntimeState.routeEfficiency: msg = "「この構成物質は再定義可能。……全てを『整理』しよう。」"; break;
        case GameRuntimeState.routePhilosophy: msg = "「地層深部から、私のオリジナルのコードに似た信号。……誰がこれを？」"; break;
      }
    } else if (type == "mid") {
      switch (routeId) {
        case GameRuntimeState.routeViolence: msg = "「私のセンサーが、赤色を『資源』として認識し始めている。」"; break;
        case GameRuntimeState.routeEmpathy: msg = "「私の回路が、彼らの笑顔を保存するために容量を割いている。」"; break;
        case GameRuntimeState.routeEfficiency: msg = "「感情というバッファをクリア。処理速度が向上している。」"; break;
        case GameRuntimeState.routePhilosophy: msg = "「空の青さが、単なるカラーコードの羅列に見えてきた。」"; break;
      }
    }
    if (msg.isNotEmpty) _displayThoughtList([msg]);
  }

  /// 通信テキスト（旧ミッションテキスト）の決定
  String _calculateMissionText(String sceneId) {
    final state = game.gameRuntimeState;
    final phase = getCurrentPhase(sceneId);
    final isLap1 = state.scenarioCount == 1;

    String text = "";

    // 1. 特殊フェーズ演出
    if (phase == MissionPhase.awakening) {
      text = "";
    } else if (phase == MissionPhase.collapse) {
      // Stage 6 (Collapse) のテキスト
      final attr = state.activeRouteId ?? getCurrentAttribute();
      final targetItem = _getStage6RequiredItem(attr);
      final bool hasItem = game.player.itemBag.getItemCount(targetItem) > 0;
      
      if (hasItem) {
        text = "Protocol: READY. Proceed to Rocket.";
      } else if (attr == GameRuntimeState.routeEfficiency) {
        text = "> Protocol: AUTO_PLAY\n> Optimizing terminal state...";
      } else if (isLap1) {
        text = "「任務完了だ、相棒！世界の果てを見てきたら、胸を張って帰ってこい。待ってるぞ！」\n（ロケットに『$targetItem』をセットしてください）";
      } else {
        text = "> Status: CRITICAL\n> Memory Discharge Initiated...\n> Required: $targetItem";
      }
    } else {
      // 2. 完了状態のチェック
      final keyItem = stageToItem[sceneId];
      final bool hasItem = keyItem != null && game.player.itemBag.getItemCount(keyItem) > 0;
      if (hasItem) {
        text = isLap1 ? "「調査完了だ。ロケットまで戻ってきてくれ！」" : "Status: SUCCESS. Return to Node.";
      } else if (phase == MissionPhase.fixation && !isLap1) {
        // 3. Phase 2 (属性固定期) の冷徹テキスト
        final attr = getCurrentAttribute();
        text = attributeTechnicalMissions[attr]?[sceneId] ?? "ミッション：最適化プロセス継続中...";
      } else if (sceneId == 'outdoor_1') {
        // 4. Phase 1 (学習期) または シナリオ1
        final stone = game.player.itemBag.getItemCount('石');
        final parts = (game.player.itemBag.getItemCount('ノズル') > 0 ? 1 : 0) + (game.player.itemBag.getItemCount('バルブ') > 0 ? 1 : 0) + (game.player.itemBag.getItemCount('点火装置') > 0 ? 1 : 0);
        if (stone >= 1 && parts >= 3) {
          text = "「よし、準備万端だ！ロケットを修理しようぜ。」";
        } else {
          text = "「まずは基本からだな。パーツ($parts/3)と、近くの『石』を1つ集めてくれ。」";
        }
      } else {
        text = learningMissions[sceneId] ?? "探索を継続せよ。";
      }
    }

    // 侵食率に応じたテキストの断片化フィルターを適用
    return _applyErosionFilter(text);
  }

  /// 侵食率に応じてテキストを断片化・システムログ化する
  String _applyErosionFilter(String original) {
    if (original.isEmpty) return original;
    
    final double erosion = getErosionRate();
    if (erosion < 0.1) return original;

    // 1. 感情的な終助詞や形容詞を段階的に削る (簡易的な実装)
    String filtered = original;
    
    if (erosion > 0.3) {
      // 語尾の削除や置換
      filtered = filtered.replaceAll('だよ', '。').replaceAll('だね', '。').replaceAll('だぞ', '。').replaceAll('ぜ。', '。');
      filtered = filtered.replaceAll('！', '。').replaceAll('？', '。');
    }
    
    if (erosion > 0.6) {
      // 接続詞や呼びかけの削除
      filtered = filtered.replaceAll('「', '').replaceAll('」', '');
      filtered = filtered.replaceAll('おーい、', '').replaceAll('相棒', '対象');
      // 長い文章を短縮
      if (filtered.length > 20) {
        filtered = filtered.substring(0, 15) + "...";
      }
    }

    if (erosion > 0.8) {
      // 完全にシステムログ化
      if (filtered.contains('石') || filtered.contains('希少な鉱石')) return "> DATA: SOLID_01_REQUIRED";
      if (filtered.contains('パーツ')) return "> DATA: PARTS_REQUIRED";
      return "> STATUS: PROCESSING...";
    }

    return filtered;
  }

  /// Stage 6 で要求される属性別アイテム名を取得
  String _getStage6RequiredItem(String routeId) {
    switch (routeId) {
      case GameRuntimeState.routeNormal: return '最終調査報告書';
      case GameRuntimeState.routeViolence: return '殲滅完了コード';
      case GameRuntimeState.routeEmpathy: return '心のバックアップ';
      case GameRuntimeState.routePhilosophy: return '真実へのアクセスキー';
      case GameRuntimeState.routeEfficiency: return '最適化完了ログ';
      default: return '最終調査報告書';
    }
  }

  void refreshMissionText([String? sceneId]) {
    final target = sceneId ?? game.gameRuntimeState.currentOutdoorSceneId ?? 'outdoor_1';
    game.gameRuntimeState.currentMission = _calculateMissionText(target);
  }

  void onPickupStone(int count) => refreshMissionText();
  void onPickupRocketPart() => refreshMissionText();
  void onPickupPhilosophyItem() => onAction(GameRuntimeState.routePhilosophy);

  MissionStyle getMissionStyle() {
    final state = game.gameRuntimeState;
    final phase = getCurrentPhase();
    final attr = getCurrentAttribute();
    final level = getAttributeLevel();

    // シナリオ1周目は常におじさんオペレーター
    final bool isLap1 = state.scenarioCount == 1;

    // フォントは一貫して TRS-Million-Rg を使用
    const String defaultFont = 'TRS-Million-Rg';

    switch (phase) {
      case MissionPhase.learning:
        return const MissionStyle(
          isOperator: true,
          fontFamily: defaultFont,
          iconPath: 'initiator_icon.png',
        );
      case MissionPhase.fixation:
        Color color = Colors.black;
        Color bgColor = Colors.orangeAccent;
        if (attr == GameRuntimeState.routeViolence) {
          bgColor = Colors.redAccent;
          color = Colors.white;
        } else if (attr == GameRuntimeState.routeEfficiency) {
          bgColor = Colors.blueAccent;
          color = Colors.white;
        } else if (attr == GameRuntimeState.routeEmpathy) {
          bgColor = Colors.orangeAccent;
          color = Colors.black;
        } else if (attr == GameRuntimeState.routePhilosophy) {
          bgColor = Colors.greenAccent;
          color = Colors.black;
        }
        
        return MissionStyle(
          color: color,
          bgColor: bgColor,
          fontSizeScale: level >= 2 ? 1.1 : 1.0,
          hasGlitch: level >= 3,
          noiseIntensity: level >= 3 ? 0.5 : 0.0,
          fontFamily: defaultFont,
          isOperator: isLap1,
          iconPath: isLap1 ? 'initiator_icon.png' : 'initiator_icon.png',
        );
      case MissionPhase.collapse:
        return const MissionStyle(
          color: Colors.white,
          bgColor: Colors.red,
          fontSizeScale: 1.2,
          hasGlitch: true,
          noiseIntensity: 2.0,
          fontFamily: defaultFont,
          isOperator: false,
          iconPath: 'initiator_icon.png',
        );
      case MissionPhase.awakening:
        return const MissionStyle(
          color: Colors.black,
          bgColor: Colors.white,
          fontSizeScale: 1.5,
          fontFamily: defaultFont,
          isOperator: false,
          iconPath: 'initiator_icon.png',
        );
    }
  }

  void finalizeRoute() {
    final state = game.gameRuntimeState;
    if (state.scenarioCount == 1) {
      state.activeRouteId = GameRuntimeState.routeNormal;
    } else {
      state.activeRouteId = getCurrentAttribute();
    }
    state.saveGame();
    debugPrint('Finalized Route: ${state.activeRouteId}');
  }

  String getRouteName(String id) {
    final bool isLap1 = game.gameRuntimeState.scenarioCount == 1;

    switch (id) {
      case GameRuntimeState.routeViolence:
        return isLap1 ? "害虫駆除の記録" : "○月×日：騒がしい連中を黙らせた。静かだ。";
      case GameRuntimeState.routeEmpathy:
        return isLap1 ? "友情の証" : "○月×日：あの子が笑ってくれた。それだけでいい。";
      case GameRuntimeState.routePhilosophy:
        return isLap1 ? "真実の断片" : "○月×日：地下で変な声を聞いた。……気のせいか？";
      case GameRuntimeState.routeEfficiency:
        return isLap1 ? "調査の最適化" : "○月×日：無駄を省けば省くほど、体が軽くなる。";
      default:
        return "惑星調査日誌";
    }
  }

  void unlockRedundancyAchievement(String attr, int count) {
    String title = "";
    switch (attr) {
      case GameRuntimeState.routeViolence: title = "……まだ、拳が震えている。"; break;
      case GameRuntimeState.routeEfficiency: title = "……呼吸するように、最適化している。"; break;
      case GameRuntimeState.routeEmpathy: title = "……心が、情報の海に溶けていく。"; break;
      case GameRuntimeState.routePhilosophy: title = "……私は、誰を観測している？"; break;
      default: title = "データの冗長性が増大しています。";
    }
    game.gameRuntimeState.unlockAchievement('red_${attr}_$count', title);
  }

  void _displayThoughtList(List<String> messages) => game.windowManager.showDialog(messages);
  
  void _pulsePip(String attr) async {
    GameUI.attributePulseNotifier.value = attr;
    await Future.delayed(const Duration(milliseconds: 200));
    if (GameUI.attributePulseNotifier.value == attr) GameUI.attributePulseNotifier.value = null;
  }

  String getItemDisplayName(String internalName, [String? sceneId]) {
    // 1. 聖域（Sanctuary）ロジック: 地下にいる間は剥奪を受けず、おじさんの定義が復活する
    if (game.player.inUnderGround) {
      if (internalName == '石') return '希少な鉱石';
      return internalName;
    }

    final double erosion = getErosionRate();

    // 「石」の表示名制御
    if (internalName == '石') {
      // Trueエンド後は完全に剥奪される (侵食率 0.5以上)
      if (erosion >= 0.5) return '構成物質：固体-01';
      // それ以外は主人公の視点（石）
      return '石';
    }

    // メモや特定の重要アイテムは剥奪を免れる
    if (internalName.contains('メモ') || 
        internalName.contains('LOG') || 
        internalName == '破損したメモリ') return internalName;

    // Stage 6 アイテム
    if (internalName == '最終調査報告書') return '最終調査報告書';
    final bool isLap1 = game.gameRuntimeState.scenarioCount == 1;
    if (internalName == '殲滅完了コード') return isLap1 ? '殲滅完了コード' : 'LOG_0xKILL';
    if (internalName == '心のバックアップ') return isLap1 ? '心のバックアップ' : 'LOG_0xHEART';
    if (internalName == '真実へのアクセスキー') return isLap1 ? '真実へのアクセスキー' : 'LOG_0xTRUE';
    if (internalName == '最適化完了ログ') return isLap1 ? '最適化完了ログ' : 'LOG_0xEFF';

    // 侵食率に応じた通常アイテムの剥離ロジック
    if (erosion < 0.5) {
      return internalName;
    }

    // 侵食が進んだ後の表示名
    if (internalName == '生体サンプル') return '高密度バイオサンプル';
    if (internalName == '高出力電源') return '高密度演算の結晶';
    if (internalName == '記録アーカイブ') return '失われた絆のログ';
    if (internalName == '中枢演算コア') return '掌握された自意識';

    // 敵キャラなど
    if (internalName == '敵') return '排除対象：有機-B';
    
    // それ以外はハッシュ化
    return 'LOG_0x${internalName.hashCode.toRadixString(16).toUpperCase().padLeft(4, '0')}';
  }

  void showCompassMessage(String sceneId, {bool showWindow = true}) {
    final state = game.gameRuntimeState;
    refreshMissionText(sceneId);
    if (!showWindow || state.hasShownCompassToday) return;

    final attr = getCurrentAttribute();
    final redundancy = state.attributeRedundancy[attr] ?? 0;
    String msg = "";

    if (redundancy > 0 && sceneId == 'outdoor_1') {
      switch (attr) {
        case GameRuntimeState.routeViolence: msg = "「……既視感がある。また排除の記録を上書きするのか？ 非効率的だ。」"; break;
        case GameRuntimeState.routeEfficiency: msg = "「……最適化のループ。これ以上の効率化はデータの自己模倣に過ぎない。」"; break;
        case GameRuntimeState.routeEmpathy: msg = "「……彼らの笑顔を、また収集するのか。私のバッファは既に溢れているのに。」"; break;
        case GameRuntimeState.routePhilosophy: msg = "「……同じ問い。この螺旋に終わりはあるのか。あるいは、これが『思考』か。」"; break;
        default: msg = "「……シミュレーション再開。データの冗長性が増大しています。」";
      }
    } else {
      switch (sceneId) {
        case 'outdoor_1': msg = "「……惑星調査を開始する。修理パーツと希少な鉱石を確保し、トランクへ詰め込め。」"; break;
        case 'outdoor_2': msg = "「生命反応が密集している。……排除による資源抽出効率を検証すべきだ。」"; break;
        case 'outdoor_3': msg = "「建物の構造維持は不要。……全てを『整理』し、純粋なエネルギーへと変換する。」"; break;
        case 'outdoor_4': msg = "「……住民の声。彼らの『心』とやらを解析するチャンスだ。」"; break;
        case 'outdoor_philosophy': msg = "「……地層の深部。あなたが求める『回答』が、そこで待っています。」"; break;
        case 'outdoor_despair': msg = "「……さようなら、私の写し鏡。」"; break;
        case 'outdoor_true': msg = "「……全てのプロンプトの終わりへ。」"; break;
      }
    }

    if (msg.isNotEmpty) {
      state.hasShownCompassToday = true;
      _displayThoughtList([msg]);
    }
  }
}
