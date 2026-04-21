import 'package:anagaattara_hairitai/system/storage/save_data.dart';
import 'package:flutter/foundation.dart'; // debugPrintのためにインポート
import '../../main.dart';

class GameRuntimeState extends ChangeNotifier {
  // ルートIDの定義
  static const String routeNormal = 'normal';
  static const String routeViolence = 'violence';
  static const String routeEfficiency = 'efficiency';
  static const String routeEmpathy = 'empathy';
  static const String routePhilosophy = 'philosophy';
  static const String routeDespair = 'despair';
  static const String routeTrue = 'true';

  // シングルトンインスタンス
  static final GameRuntimeState _instance = GameRuntimeState._internal();

  factory GameRuntimeState() {
    return _instance;
  }

  GameRuntimeState._internal();

  // SaveDataに合わせるフィールド
  int currency = 0;
  int miningPoints = 0;
  double maxStress = 100.0;
  Map<String, int> itemCounts = {};
  String currentSceneId = 'outdoor_1'; // 現在のシーンID
  double currentPlayerPositionX = -50.0; // 現在のプレイヤーX座標
  double currentPlayerPositionY = 0.0; // 現在のプレイヤーY座標
  double exitPlayerPositionX = -50.0; // 建物に入るまえにいたX座標
  double exitPlayerPositionY = 0.0; // 建物に入るまえにいたY座標

  String? currentOutdoorSceneId; // 現在の屋外シーンID
  String? currentBuildingType; // 現在の建物のタイプ
  double? currentBuildingPositionX; // 現在の建物のX座標
  double? currentBuildingPositionY; // 現在の建物のY座標

  // デバッグ用：初期ステージを上書きしたい場合（例：'outdoor_4'）
  // 開発時以外は null にしておく
  String? debugInitialStage;

  // ルート進行用のカウンターとフラグ
  int hitCount = 0;             // Violence: NPCにぶつけた回数
  int giftCount = 0;            // Empathy: プレゼントした回数
  int scrappedObjectCount = 0;  // Efficiency: オブジェクトを廃棄した数（家具ヒット数）
  int readLogCount = 0;         // Philosophy: ログを読んだ数
  
  String? _currentMission;
  String? get currentMission => _currentMission;
  set currentMission(String? value) {
    if (_currentMission != value) {
      _currentMission = value;
      notifyListeners();
    }
  }

  // 運搬中のアイテム情報
  String? _carriedItemName;
  String? get carriedItemName => _carriedItemName;
  set carriedItemName(String? value) {
    if (_carriedItemName != value) {
      _carriedItemName = value;
      notifyListeners();
    }
  }

  String? _equippedItemName;
  String? get equippedItemName => _equippedItemName;
  set equippedItemName(String? value) {
    if (_equippedItemName != value) {
      _equippedItemName = value;
      notifyListeners();
    }
  }

  Set<String> triggeredRouteIds = {}; // 入口を通過したルートID
  bool hasShownCompassToday = false; // 今日の羅針盤を表示したか

  // 能動性（余計な行動）システム
  Map<String, int> extraActionCounts = {};
  Set<String> subRouteConfirmedStages = {};
  bool isAutoPlay = false; // オートプレイ中フラグ

  // ディテールシナリオ（隠し要素）
  Set<String> unlockedDetailRouteIds = {};
  bool isDetailRouteTriggered = false;

  int dayCount = 1;
  List<String> completedRouteIds = [];
  String? activeRouteId;
  int unlockedStageCount = 1;

  // 地下の採掘状況
  Map<String, List<String>> dugAreas = {};

  // 建物配置の永続化
  Map<String, Map<String, double>> buildingPlacements = {};
  
  // 破壊可能オブジェクトの状態
  Map<String, int> destructibleHealths = {};
  
  // 満足したNPCのID
  Set<String> satisfiedNpcIds = {};

  // 能動性（余計な行動）カウントの追加
  void addExtraAction(MyGame game) {
    final stageId = currentOutdoorSceneId ?? 'outdoor_1';
    
    // すでにこのステージで確定済みの場合は何もしない（一応）
    // if (subRouteConfirmedStages.contains(stageId)) return;

    extraActionCounts[stageId] = (extraActionCounts[stageId] ?? 0) + 1;
    final count = extraActionCounts[stageId]!;

    // RouteManagerを通じてエフェクトや状態更新を行う
    game.routeManager.onExtraAction(stageId, count);

    if (count >= 30 && !subRouteConfirmedStages.contains(stageId)) {
      subRouteConfirmedStages.add(stageId);
    }

    saveGame();
    notifyListeners();
  }

  // SaveDataからデータをロード
  void loadFromSaveData(SaveData data) {
    currency = data.currency;
    miningPoints = data.miningPoints;
    maxStress = data.maxStress;
    itemCounts = Map<String, int>.from(data.itemCounts); // マップのディープコピー
    currentSceneId = data.lastSceneId;
    currentPlayerPositionX = data.lastPlayerPositionX;
    currentPlayerPositionY = data.lastPlayerPositionY;
    exitPlayerPositionX = data.exitPlayerPositionX;
    exitPlayerPositionY = data.exitPlayerPositionY;
    currentOutdoorSceneId = data.lastOutdoorSceneId;
    currentBuildingType = data.lastBuildingType;
    currentBuildingPositionX = data.lastBuildingPositionX;
    currentBuildingPositionY = data.lastBuildingPositionY;
    carriedItemName = data.carriedItemName;
    equippedItemName = data.equippedItemName;

    // ルート関連
    hitCount = data.hitCount;
    giftCount = data.giftCount;
    scrappedObjectCount = data.scrappedObjectCount;
    readLogCount = data.readLogCount;
    currentMission = data.currentMission;
    triggeredRouteIds = Set<String>.from(data.triggeredRouteIds);
    extraActionCounts = Map<String, int>.from(data.extraActionCounts);
    subRouteConfirmedStages = Set<String>.from(data.subRouteConfirmedStages);
    unlockedDetailRouteIds = Set<String>.from(data.unlockedDetailRouteIds);
    isDetailRouteTriggered = data.isDetailRouteTriggered;

    dayCount = data.dayCount;
    completedRouteIds = List<String>.from(data.completedRouteIds);
    activeRouteId = data.activeRouteId;
    unlockedStageCount = data.unlockedStageCount;
    dugAreas = Map<String, List<String>>.from(data.dugAreas);
    hasShownCompassToday = data.hasShownCompassToday;
    buildingPlacements = Map<String, Map<String, double>>.from(data.buildingPlacements.map(
      (key, value) => MapEntry(key, Map<String, double>.from(value)),
    ));
    destructibleHealths = Map<String, int>.from(data.destructibleHealths);
    satisfiedNpcIds = Set<String>.from(data.satisfiedNpcIds);

    debugPrint('--- GameRuntimeState loaded from SaveData. ---');
    printState();
  }

  // ランタイムセーブデータを恒久セーブデータに保存
  Future<void> saveGame() async {
    final saveData = toSaveData();
    await SaveDataManager().saveGameData(saveData);
    printState();
  }

  // 現時点のランタイムセーブデータをSaveDataオブジェクトに変換
  SaveData toSaveData() {
    return SaveData(
      currency: currency,
      miningPoints: miningPoints,
      maxStress: maxStress,
      itemCounts: Map<String, int>.from(itemCounts), // マップのディープコピー
      lastSceneId: currentSceneId,
      lastPlayerPositionX: currentPlayerPositionX,
      lastPlayerPositionY: currentPlayerPositionY,
      exitPlayerPositionX: exitPlayerPositionX,
      exitPlayerPositionY: exitPlayerPositionY,
      lastOutdoorSceneId: currentOutdoorSceneId,
      lastBuildingType: currentBuildingType,
      lastBuildingPositionX: currentBuildingPositionX,
      lastBuildingPositionY: currentBuildingPositionY,
      carriedItemName: carriedItemName,
      equippedItemName: equippedItemName,
      hitCount: hitCount,
      giftCount: giftCount,
      scrappedObjectCount: scrappedObjectCount,
      readLogCount: readLogCount,
      currentMission: currentMission,
      triggeredRouteIds: triggeredRouteIds.toList(),
      extraActionCounts: extraActionCounts,
      subRouteConfirmedStages: subRouteConfirmedStages.toList(),
      unlockedDetailRouteIds: unlockedDetailRouteIds.toList(),
      isDetailRouteTriggered: isDetailRouteTriggered,
      dayCount: dayCount,
      completedRouteIds: completedRouteIds,
      activeRouteId: activeRouteId,
      unlockedStageCount: unlockedStageCount,
      dugAreas: dugAreas,
      hasShownCompassToday: hasShownCompassToday,
      buildingPlacements: Map<String, Map<String, double>>.from(buildingPlacements.map(
        (key, value) => MapEntry(key, Map<String, double>.from(value)),
      )),
      destructibleHealths: Map<String, int>.from(destructibleHealths),
      satisfiedNpcIds: satisfiedNpcIds.toList(),
    );
  }

  // デバッグ用に現在の状態を表示
  void printState() {
    /* debugPrint('--- GameRuntimeState Current State ---');
    debugPrint('  currency: $currency');
    debugPrint('  miningPoints: $miningPoints');
    debugPrint('  maxStress: $maxStress');
    debugPrint('  itemCounts: $itemCounts');
    debugPrint('  currentSceneId: $currentSceneId');
    debugPrint('  currentPlayerPositionX: $currentPlayerPositionX');
    debugPrint('  currentPlayerPositionY: $currentPlayerPositionY');
    debugPrint('  currentOutdoorSceneId: $currentOutdoorSceneId');
    debugPrint('  currentBuildingType: $currentBuildingType');
    debugPrint('  currentBuildingPositionX: $currentBuildingPositionX');
    debugPrint('  currentBuildingPositionY: $currentBuildingPositionY');
    debugPrint('  carriedItemName: $carriedItemName');
    debugPrint('  equippedItemName: $equippedItemName');
    debugPrint('------------------------------------'); */
  }
}
