import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class SaveData {
  int currency;
  int miningPoints;
  double maxStress;
  double currentStress;
  double maxIntegrity;
  double currentIntegrity;
  Map<String, int> itemCounts;

  String lastSceneId; // 最後にいたシーンのID
  double lastPlayerPositionX; // ゲーム終了時にいたプレイヤーのX座標
  double lastPlayerPositionY; // ゲーム終了時にいたプレイヤーのY座標

  double exitPlayerPositionX; // 建物から出たときのプレイヤーのX座標
  double exitPlayerPositionY; // 建物から出たときのプレイヤーのY座標

  String? lastOutdoorSceneId; // 最後にいた屋外シーンのID
  String? lastBuildingType; // 最後にいた建物のタイプ
  double? lastBuildingPositionX; // 最後にいた建物のX座標
  double? lastBuildingPositionY; // 最後にいた建物のY座標

  String? carriedItemName;
  String? equippedItemName;

  String? currentMission;
  int scenarioCount;

  int dayCount;

  // 地下の採掘状況（シーンIDごとの座標文字列リスト）
  Map<String, List<String>> dugAreas;

  /// 経路ベース掘削スタンプ（シーンID → [{x,y,r}, ...]）
  Map<String, List<Map<String, dynamic>>> carveStamps;

  /// 地下に設置した床板（シーンID → [{l,t,r,b}, ...]）
  Map<String, List<Map<String, dynamic>>> placedFloors;

  /// プレイヤー定義の掘削断面型（null なら円デフォルト）。
  Map<String, dynamic>? digShapeTemplate;

  bool hasShownCompassToday; // 今日の羅針盤を表示したか
  Map<String, Map<String, double>> buildingPlacements; // シーンごとの建物配置 (sceneId -> {buildingType: x})
  Map<String, int> destructibleHealths; // 破壊可能オブジェクトの状態 (uniqueId -> health)
  List<String> satisfiedNpcIds; // 満足したNPCのIDリスト
  List<String> unlockedAchievements; // 解放済みアチーブメント
  Map<String, String> missionTrueLogs; // 真実のログ

  double hpCalibrationScale;
  double speedCalibrationScale;
  double powerCalibrationScale;
  double stressCalibrationScale;

  int youngUncleDialogueStep;
  bool hasIdentifiedYoungUncle;
  /// 父のメモ・日記等。父のメモはキー `father_memo_*` 推奨（v8.3 §7・§16）。
  List<String> unlockedDiaryEntries;

  double currentWillpower;
  double maxWillCoreValue;
  double willpowerSpentInStage;
  int destructionPointsInStage;

  // 母星ステータスと星の警戒度
  double homePlanetHumanity;
  double homePlanetEfficiency;
  double homePlanetRealism;
  double starAlertLevel;

  /// ガソリン缶の燃料残量
  double gasolineCanFuel;

  // プレイヤーが現在所持している資源
  int playerLifeCount;
  int playerHistoryCount;
  int playerInorganicCount;

  // カーゴに蓄積された資源（拠点に預けた分）
  int cargoLifeCount;
  int cargoHistoryCount;
  int cargoInorganicCount;
  bool isCargoLaunched;

  /// 次のステージで出現させる支援物資（Toolbox）の予約フラグ
  bool pendingToolboxReward;

  // 送信済み資源カウント（発射後に移動される）
  int sentLifeResourceCount;
  int sentHistoryResourceCount;
  int sentInorganicResourceCount;

  // 自動化キット
  int automationKitStage;
  double automationKitTotalRuntime;

  /// 自動化ショップ C-2 契約（意志の核自動供給）。`automationKitStage >= 4` と同期させる。
  bool automationContractC2;

  /// §11 チュートリアル：母星で「搬入経路」を接続したか。
  bool hasConnectedSupplyRoute;

  /// v8.3 マクロルート到達記録（例: macro_nourishment, macro_destroy）。
  List<String> completedMacroRoutes;

  /// Destroy 系マクロへの「資格」が一度付いたか（C-2 未契約時のみ成立しうる）。
  bool destroyMacroPathQualified;

  /// 通算敵撃破（`EnemyBase.dieAndDropItem` 系）。
  int lifetimeEnemyKills;

  /// 累計「生命」カーゴ加算（換算前の素朴カウント）。
  int lifetimeLifeCargoAccumulated;

  /// 累計意志力消費（§6.1 特殊トリガー用。`resetStageState` では消さない）。
  double totalWillpowerConsumed;

  /// 屋外→屋外遷移時の微細ログ（上限はランタイム側でカット）。
  List<Map<String, dynamic>> stageMicroLogEntries;

  bool hasShownAutomationShopUnlockMessage;

  /// 対象星初回入場オンボーディング済み
  bool hasShownTargetStarAutomationIntro;

  /// 警戒狩人から自動化キットを初回取得済み
  bool hasReceivedAutomationKitFromHunter;

  /// 最後に警戒狩人をスポーンした警戒ティア
  int lastAlertHunterSpawnTier;

  /// バッグにキットを入れたあと1回だけ表示
  bool hasShownKitBagHint;

  /// 設置済み自動化キット（1台・グローバル・レガシー）
  String? automationKitSceneId;
  double? automationKitPositionX;
  double? automationKitPositionY;

  List<Map<String, dynamic>> automationToolPlacementsJson;
  Map<String, dynamic> automationUnlocksJson;
  Map<String, dynamic> automationUpgradeLevelsJson;
  Map<String, dynamic> harvestStorageJson;
  List<String> hunterToolsGranted;
  int automationUpgradeStageTier;
  double upkeepToolFuel;
  double harvestToolFuel;
  double wardToolFuel;
  String? harvestTankFuelRank;
  String? upkeepTankFuelRank;
  String? wardTankFuelRank;
  bool automationAutoWillRefuel;

  /// 自動化ショップ段階（§5）。既存 `automationKitStage` とは別表現。C-2 はキット挿入とも同期。
  int automationShopTierA;
  int automationShopTierB;
  int automationShopTierC;
  int automationShopTierD;

  int automationShopGradeHarvest;
  int automationShopGradeUpkeep;
  int automationShopGradeWard;
  int automationShopGradeCommon;
  int automationFuelEfficiencyTier;

  /// [CodexSnapshot.toJson] を格納。
  Map<String, dynamic> codexSnapshotJson;

  /// §13 開示段階（0=序, 1=中, 2=終）。
  int disclosureTier;

  /// 累計カーゴ射出回数（開示・ログ用途）。
  int totalCargoLaunches;

  /// True 深層進行 0=未開始, 1=廊下, 2=金庫, 3=終盤戦, 4=完了。
  int trueSequencePhase;

  /// §6.1 ナラティブ（次シーンで消費する短い青メッセージ用）。永続は任意。
  List<String> pendingNarrativeMessages;

  /// B-2 相当：意志力の自動支払い基盤が有効か。
  bool automationShopWillpowerAutoPay;

  /// 6 桁ダイヤル正解のセーブ別シード（初回生成）。
  int? trueDialSalt;

  /// 現在シナリオ周回開始時点の `sentLifeResourceCount`（Normal 判定用）。
  int sentLifeScenarioBaseline;

  /// ファーム駆け引き（§ ファーム駆け引き v0.1）
  int farmPrimaryRoleIndex;
  int farmSubModuleIndex;
  double farmRoiMultiplier;
  int farmInterventionBonusCount;
  int farmCostLife;
  int farmCostHistory;
  int farmCostInorganic;
  double farmCostWillpower;
  int farmCostCurrency;
  int farmOutputCurrency;
  int farmOutputMining;
  int farmOutputCargoLife;
  int farmOutputCargoHistory;
  int farmOutputCargoInorganic;

  SaveData({
    this.currency = 0,
    this.miningPoints = 0,
    this.maxStress = 100.0,
    this.currentStress = 0.0,
    this.maxIntegrity = 1000.0,
    this.currentIntegrity = 1000.0,
    Map<String, int>? itemCounts,
    this.lastSceneId = 'outdoor_0',
    this.lastPlayerPositionX = -50.0,
    this.lastPlayerPositionY = 0.0,
    this.exitPlayerPositionX = -50.0,
    this.exitPlayerPositionY = 0.0,
    this.lastOutdoorSceneId = 'outdoor_0',
    this.lastBuildingType = 'shop',
    this.lastBuildingPositionX = -50.0,
    this.lastBuildingPositionY = 0.0,
    this.carriedItemName,
    this.equippedItemName,
    this.currentMission,
    this.scenarioCount = 1,
    this.dayCount = 1,
    Map<String, List<String>>? dugAreas,
    Map<String, List<Map<String, dynamic>>>? carveStamps,
    Map<String, List<Map<String, dynamic>>>? placedFloors,
    this.digShapeTemplate,
    this.hasShownCompassToday = false,
    Map<String, Map<String, double>>? buildingPlacements,
    Map<String, int>? destructibleHealths,
    List<String>? satisfiedNpcIds,
    List<String>? unlockedAchievements,
    Map<String, String>? missionTrueLogs,
    this.hpCalibrationScale = 1.0,
    this.speedCalibrationScale = 1.0,
    this.powerCalibrationScale = 1.0,
    this.stressCalibrationScale = 1.0,
    this.youngUncleDialogueStep = 0,
    this.hasIdentifiedYoungUncle = false,
    List<String>? unlockedDiaryEntries,
    this.currentWillpower = 10.0,
    this.maxWillCoreValue = 10.0,
    this.willpowerSpentInStage = 0.0,
    this.destructionPointsInStage = 0,
    this.homePlanetHumanity = 0.0,
    this.homePlanetEfficiency = 0.0,
    this.homePlanetRealism = 0.0,
    this.starAlertLevel = 0.0,
    this.gasolineCanFuel = 0.0,
    this.playerLifeCount = 0,
    this.playerHistoryCount = 0,
    this.playerInorganicCount = 0,
    this.cargoLifeCount = 0,
    this.cargoHistoryCount = 0,
    this.cargoInorganicCount = 0,
    this.isCargoLaunched = false,
    this.pendingToolboxReward = false,
    this.sentLifeResourceCount = 0,
    this.sentHistoryResourceCount = 0,
    this.sentInorganicResourceCount = 0,
    this.automationKitStage = 0,
    this.automationKitTotalRuntime = 0.0,
    this.automationContractC2 = false,
    this.hasConnectedSupplyRoute = false,
    List<String>? completedMacroRoutes,
    this.destroyMacroPathQualified = false,
    this.lifetimeEnemyKills = 0,
    this.lifetimeLifeCargoAccumulated = 0,
    this.totalWillpowerConsumed = 0.0,
    List<Map<String, dynamic>>? stageMicroLogEntries,
    this.hasShownAutomationShopUnlockMessage = false,
    this.hasShownTargetStarAutomationIntro = false,
    this.hasReceivedAutomationKitFromHunter = false,
    this.lastAlertHunterSpawnTier = 0,
    this.hasShownKitBagHint = false,
    this.automationKitSceneId,
    this.automationKitPositionX,
    this.automationKitPositionY,
    List<Map<String, dynamic>>? automationToolPlacementsJson,
    Map<String, dynamic>? automationUnlocksJson,
    Map<String, dynamic>? automationUpgradeLevelsJson,
    Map<String, dynamic>? harvestStorageJson,
    List<String>? hunterToolsGranted,
    this.automationUpgradeStageTier = 1,
    this.upkeepToolFuel = 40.0,
    this.harvestToolFuel = 40.0,
    this.wardToolFuel = 40.0,
    this.harvestTankFuelRank,
    this.upkeepTankFuelRank,
    this.wardTankFuelRank,
    this.automationAutoWillRefuel = false,
    this.automationShopTierA = 0,
    this.automationShopTierB = 0,
    this.automationShopTierC = 0,
    this.automationShopTierD = 0,
    this.automationShopGradeHarvest = 0,
    this.automationShopGradeUpkeep = 0,
    this.automationShopGradeWard = 0,
    this.automationShopGradeCommon = 0,
    this.automationFuelEfficiencyTier = 0,
    Map<String, dynamic>? codexSnapshotJson,
    this.disclosureTier = 0,
    this.totalCargoLaunches = 0,
    this.trueSequencePhase = 0,
    List<String>? pendingNarrativeMessages,
    this.automationShopWillpowerAutoPay = false,
    this.trueDialSalt,
    this.sentLifeScenarioBaseline = 0,
    this.farmPrimaryRoleIndex = 0,
    this.farmSubModuleIndex = 0,
    this.farmRoiMultiplier = 1.0,
    this.farmInterventionBonusCount = 0,
    this.farmCostLife = 0,
    this.farmCostHistory = 0,
    this.farmCostInorganic = 0,
    this.farmCostWillpower = 0,
    this.farmCostCurrency = 0,
    this.farmOutputCurrency = 0,
    this.farmOutputMining = 0,
    this.farmOutputCargoLife = 0,
    this.farmOutputCargoHistory = 0,
    this.farmOutputCargoInorganic = 0,
  }) : itemCounts = itemCounts ?? {},
       dugAreas = dugAreas ?? {},
       carveStamps = carveStamps ?? {},
       placedFloors = placedFloors ?? {},
       buildingPlacements = buildingPlacements ?? {},
       destructibleHealths = destructibleHealths ?? {},
       satisfiedNpcIds = satisfiedNpcIds ?? [],
       unlockedAchievements = unlockedAchievements ?? [],
       missionTrueLogs = missionTrueLogs ?? {},
       unlockedDiaryEntries = unlockedDiaryEntries ?? [],
       completedMacroRoutes = completedMacroRoutes ?? [],
       stageMicroLogEntries = stageMicroLogEntries ?? [],
       codexSnapshotJson = codexSnapshotJson ?? {},
       pendingNarrativeMessages = pendingNarrativeMessages ?? [],
       automationToolPlacementsJson = automationToolPlacementsJson ?? [],
       automationUnlocksJson = automationUnlocksJson ?? {},
       automationUpgradeLevelsJson = automationUpgradeLevelsJson ?? {},
       harvestStorageJson = harvestStorageJson ?? {},
       hunterToolsGranted = hunterToolsGranted ?? [];

  // JSONからSaveDataオブジェクトを生成するファクトリコンストラクタ
  factory SaveData.fromJson(Map<String, dynamic> json) {
    return SaveData(
      currency: json['currency'] as int? ?? 0,
      miningPoints: json['miningPoints'] as int? ?? 0,
      maxStress: json['maxStress'] as double? ?? 100.0,
      currentStress: json['currentStress'] as double? ?? 0.0,
      maxIntegrity: json['maxIntegrity'] as double? ?? 1000.0,
      currentIntegrity: json['currentIntegrity'] as double? ?? 1000.0,
      itemCounts: (json['itemCounts'] as Map<dynamic, dynamic>?)?.map(
            (key, value) => MapEntry(key.toString(), value as int),
          ),
      lastSceneId: json['lastSceneId'] as String? ?? 'outdoor_0',
      lastPlayerPositionX: json['lastPlayerPositionX'] as double? ?? -50.0,
      lastPlayerPositionY: json['lastPlayerPositionY'] as double? ?? 0.0,
      exitPlayerPositionX: json['exitPlayerPositionX'] as double? ?? -50.0,
      exitPlayerPositionY: json['exitPlayerPositionY'] as double? ?? 0.0,
      lastOutdoorSceneId: json['lastOutdoorSceneId'] as String? ?? 'outdoor_0',
      lastBuildingType: json['lastBuildingType'] as String?,
      lastBuildingPositionX: json['lastBuildingPositionX'] as double?,
      lastBuildingPositionY: json['lastBuildingPositionY'] as double?,
      carriedItemName: json['carriedItemName'] as String?,
      equippedItemName: json['equippedItemName'] as String?,
      currentMission: json['currentMission'] as String?,
      scenarioCount: json['scenarioCount'] as int? ?? 1,
      dayCount: json['dayCount'] as int? ?? 1,
      dugAreas: (json['dugAreas'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, List<String>.from(value as List)),
          ),
      carveStamps: (json['carveStamps'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(
              key,
              (value as List)
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList(),
            ),
          ),
      placedFloors: (json['placedFloors'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(
              key,
              (value as List)
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList(),
            ),
          ),
      digShapeTemplate: json['digShapeTemplate'] as Map<String, dynamic>?,
      hasShownCompassToday: json['hasShownCompassToday'] as bool? ?? false,
      buildingPlacements: (json['buildingPlacements'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, Map<String, double>.from(value as Map)),
      ),
      destructibleHealths: (json['destructibleHealths'] as Map<String, dynamic>?)?.cast<String, int>(),
      satisfiedNpcIds: (json['satisfiedNpcIds'] as List<dynamic>?)?.cast<String>(),
      unlockedAchievements: (json['unlockedAchievements'] as List<dynamic>?)?.cast<String>(),
      missionTrueLogs: (json['missionTrueLogs'] as Map<dynamic, dynamic>?)?.cast<String, String>(),
      hpCalibrationScale: json['hpCalibrationScale'] as double? ?? 1.0,
      speedCalibrationScale: json['speedCalibrationScale'] as double? ?? 1.0,
      powerCalibrationScale: json['powerCalibrationScale'] as double? ?? 1.0,
      stressCalibrationScale: json['stressCalibrationScale'] as double? ?? 1.0,
      youngUncleDialogueStep: json['youngUncleDialogueStep'] as int? ?? 0,
      hasIdentifiedYoungUncle: json['hasIdentifiedYoungUncle'] as bool? ?? false,
      unlockedDiaryEntries: (json['unlockedDiaryEntries'] as List<dynamic>?)?.cast<String>(),
      currentWillpower: json['currentWillpower'] as double? ?? 10.0,
      maxWillCoreValue: json['maxWillCoreValue'] as double? ?? 10.0,
      willpowerSpentInStage: json['willpowerSpentInStage'] as double? ?? 0.0,
      destructionPointsInStage: json['destructionPointsInStage'] as int? ?? 0,
      homePlanetHumanity: json['homePlanetHumanity'] as double? ?? 0.0,
      homePlanetEfficiency: json['homePlanetEfficiency'] as double? ?? 0.0,
      homePlanetRealism: json['homePlanetRealism'] as double? ?? 0.0,
      starAlertLevel: json['starAlertLevel'] as double? ?? 0.0,
      gasolineCanFuel: (json['gasolineCanFuel'] as num?)?.toDouble() ?? 0.0,
      playerLifeCount: json['playerLifeCount'] as int? ?? 0,
      playerHistoryCount: json['playerHistoryCount'] as int? ?? 0,
      playerInorganicCount: json['playerInorganicCount'] as int? ?? 0,
      cargoLifeCount: json['cargoLifeCount'] as int? ?? 0,
      cargoHistoryCount: json['cargoHistoryCount'] as int? ?? 0,
      cargoInorganicCount: json['cargoInorganicCount'] as int? ?? 0,
      isCargoLaunched: json['isCargoLaunched'] as bool? ?? false,
      pendingToolboxReward: json['pendingToolboxReward'] as bool? ?? false,
      sentLifeResourceCount: json['sentLifeResourceCount'] as int? ?? 0,
      sentHistoryResourceCount: json['sentHistoryResourceCount'] as int? ?? 0,
      sentInorganicResourceCount: json['sentInorganicResourceCount'] as int? ?? 0,
      automationKitStage: json['automationKitStage'] as int? ?? 0,
      automationKitTotalRuntime: json['automationKitTotalRuntime'] as double? ?? 0.0,
      automationContractC2: json['automationContractC2'] as bool? ?? false,
      hasConnectedSupplyRoute: json['hasConnectedSupplyRoute'] as bool? ?? false,
      completedMacroRoutes:
          (json['completedMacroRoutes'] as List<dynamic>?)?.cast<String>(),
      destroyMacroPathQualified:
          json['destroyMacroPathQualified'] as bool? ?? false,
      lifetimeEnemyKills: json['lifetimeEnemyKills'] as int? ?? 0,
      lifetimeLifeCargoAccumulated:
          json['lifetimeLifeCargoAccumulated'] as int? ?? 0,
      totalWillpowerConsumed:
          json['totalWillpowerConsumed'] as double? ?? 0.0,
      stageMicroLogEntries: (json['stageMicroLogEntries'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      hasShownAutomationShopUnlockMessage:
          json['hasShownAutomationShopUnlockMessage'] as bool? ?? false,
      hasShownTargetStarAutomationIntro:
          json['hasShownTargetStarAutomationIntro'] as bool? ??
              (json['hasShownAutomationShopUnlockMessage'] as bool? ?? false),
      hasReceivedAutomationKitFromHunter:
          json['hasReceivedAutomationKitFromHunter'] as bool? ?? false,
      lastAlertHunterSpawnTier:
          json['lastAlertHunterSpawnTier'] as int? ?? 0,
      hasShownKitBagHint: json['hasShownKitBagHint'] as bool? ?? false,
      automationKitSceneId: json['automationKitSceneId'] as String?,
      automationKitPositionX:
          (json['automationKitPositionX'] as num?)?.toDouble(),
      automationKitPositionY:
          (json['automationKitPositionY'] as num?)?.toDouble(),
      automationToolPlacementsJson: (json['automationToolPlacements'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      automationUnlocksJson:
          Map<String, dynamic>.from(json['automationUnlocks'] as Map? ?? {}),
      automationUpgradeLevelsJson: Map<String, dynamic>.from(
          json['automationUpgradeLevels'] as Map? ?? {}),
      harvestStorageJson:
          Map<String, dynamic>.from(json['harvestStorage'] as Map? ?? {}),
      hunterToolsGranted:
          (json['hunterToolsGranted'] as List<dynamic>?)?.cast<String>() ?? [],
      automationUpgradeStageTier:
          json['automationUpgradeStageTier'] as int? ?? 1,
      upkeepToolFuel: (json['upkeepToolFuel'] as num?)?.toDouble() ?? 40.0,
      harvestToolFuel: (json['harvestToolFuel'] as num?)?.toDouble() ?? 40.0,
      wardToolFuel: (json['wardToolFuel'] as num?)?.toDouble() ?? 40.0,
      harvestTankFuelRank: json['harvestTankFuelRank'] as String?,
      upkeepTankFuelRank: json['upkeepTankFuelRank'] as String?,
      wardTankFuelRank: json['wardTankFuelRank'] as String?,
      automationAutoWillRefuel:
          json['automationAutoWillRefuel'] as bool? ?? false,
      automationShopTierA: json['automationShopTierA'] as int? ?? 0,
      automationShopTierB: json['automationShopTierB'] as int? ?? 0,
      automationShopTierC: json['automationShopTierC'] as int? ?? 0,
      automationShopTierD: json['automationShopTierD'] as int? ?? 0,
      automationShopGradeHarvest:
          json['automationShopGradeHarvest'] as int? ?? 0,
      automationShopGradeUpkeep:
          json['automationShopGradeUpkeep'] as int? ?? 0,
      automationShopGradeWard: json['automationShopGradeWard'] as int? ?? 0,
      automationShopGradeCommon:
          json['automationShopGradeCommon'] as int? ?? 0,
      automationFuelEfficiencyTier:
          json['automationFuelEfficiencyTier'] as int? ?? 0,
      codexSnapshotJson: (json['codexSnapshotJson'] as Map<String, dynamic>?) ??
          {},
      disclosureTier: json['disclosureTier'] as int? ?? 0,
      totalCargoLaunches: json['totalCargoLaunches'] as int? ?? 0,
      trueSequencePhase: json['trueSequencePhase'] as int? ?? 0,
      pendingNarrativeMessages:
          (json['pendingNarrativeMessages'] as List<dynamic>?)?.cast<String>() ??
              [],
      automationShopWillpowerAutoPay:
          json['automationShopWillpowerAutoPay'] as bool? ?? false,
      trueDialSalt: json['trueDialSalt'] as int?,
      sentLifeScenarioBaseline:
          json['sentLifeScenarioBaseline'] as int? ?? 0,
      farmPrimaryRoleIndex: json['farmPrimaryRoleIndex'] as int? ?? 0,
      farmSubModuleIndex: json['farmSubModuleIndex'] as int? ?? 0,
      farmRoiMultiplier: json['farmRoiMultiplier'] as double? ?? 1.0,
      farmInterventionBonusCount:
          json['farmInterventionBonusCount'] as int? ?? 0,
      farmCostLife: json['farmCostLife'] as int? ?? 0,
      farmCostHistory: json['farmCostHistory'] as int? ?? 0,
      farmCostInorganic: json['farmCostInorganic'] as int? ?? 0,
      farmCostWillpower: json['farmCostWillpower'] as double? ?? 0,
      farmCostCurrency: json['farmCostCurrency'] as int? ?? 0,
      farmOutputCurrency: json['farmOutputCurrency'] as int? ?? 0,
      farmOutputMining: json['farmOutputMining'] as int? ?? 0,
      farmOutputCargoLife: json['farmOutputCargoLife'] as int? ?? 0,
      farmOutputCargoHistory: json['farmOutputCargoHistory'] as int? ?? 0,
      farmOutputCargoInorganic: json['farmOutputCargoInorganic'] as int? ?? 0,
    );
  }

  // SaveDataオブジェクトをJSONに変換するメソッド
  Map<String, dynamic> toJson() {
    return {
      'currency': currency,
      'miningPoints': miningPoints,
      'maxStress': maxStress,
      'currentStress': currentStress,
      'maxIntegrity': maxIntegrity,
      'currentIntegrity': currentIntegrity,
      'itemCounts': itemCounts,
      'lastSceneId': lastSceneId,
      'lastPlayerPositionX': lastPlayerPositionX,
      'lastPlayerPositionY': lastPlayerPositionY,
      'exitPlayerPositionX': exitPlayerPositionX,
      'exitPlayerPositionY': exitPlayerPositionY,
      'lastOutdoorSceneId': lastOutdoorSceneId,
      'lastBuildingType': lastBuildingType,
      'lastBuildingPositionX': lastBuildingPositionX,
      'lastBuildingPositionY': lastBuildingPositionY,
      'carriedItemName': carriedItemName,
      'equippedItemName': equippedItemName,
      'currentMission': currentMission,
      'scenarioCount': scenarioCount,
      'dayCount': dayCount,
      'dugAreas': dugAreas,
      'carveStamps': carveStamps,
      'placedFloors': placedFloors,
      if (digShapeTemplate != null) 'digShapeTemplate': digShapeTemplate,
      'hasShownCompassToday': hasShownCompassToday,
      'buildingPlacements': buildingPlacements,
      'destructibleHealths': destructibleHealths,
      'satisfiedNpcIds': satisfiedNpcIds,
      'unlockedAchievements': unlockedAchievements,
      'missionTrueLogs': missionTrueLogs,
      'hpCalibrationScale': hpCalibrationScale,
      'speedCalibrationScale': speedCalibrationScale,
      'powerCalibrationScale': powerCalibrationScale,
      'stressCalibrationScale': stressCalibrationScale,
      'youngUncleDialogueStep': youngUncleDialogueStep,
      'hasIdentifiedYoungUncle': hasIdentifiedYoungUncle,
      'unlockedDiaryEntries': unlockedDiaryEntries,
      'currentWillpower': currentWillpower,
      'maxWillCoreValue': maxWillCoreValue,
      'willpowerSpentInStage': willpowerSpentInStage,
      'destructionPointsInStage': destructionPointsInStage,
      'homePlanetHumanity': homePlanetHumanity,
      'homePlanetEfficiency': homePlanetEfficiency,
      'homePlanetRealism': homePlanetRealism,
      'starAlertLevel': starAlertLevel,
      'gasolineCanFuel': gasolineCanFuel,
      'playerLifeCount': playerLifeCount,
      'playerHistoryCount': playerHistoryCount,
      'playerInorganicCount': playerInorganicCount,
      'cargoLifeCount': cargoLifeCount,
      'cargoHistoryCount': cargoHistoryCount,
      'cargoInorganicCount': cargoInorganicCount,
      'isCargoLaunched': isCargoLaunched,
      'pendingToolboxReward': pendingToolboxReward,
      'sentLifeResourceCount': sentLifeResourceCount,
      'sentHistoryResourceCount': sentHistoryResourceCount,
      'sentInorganicResourceCount': sentInorganicResourceCount,
      'automationKitStage': automationKitStage,
      'automationKitTotalRuntime': automationKitTotalRuntime,
      'automationContractC2': automationContractC2,
      'hasConnectedSupplyRoute': hasConnectedSupplyRoute,
      'completedMacroRoutes': completedMacroRoutes,
      'destroyMacroPathQualified': destroyMacroPathQualified,
      'lifetimeEnemyKills': lifetimeEnemyKills,
      'lifetimeLifeCargoAccumulated': lifetimeLifeCargoAccumulated,
      'totalWillpowerConsumed': totalWillpowerConsumed,
      'stageMicroLogEntries': stageMicroLogEntries,
      'hasShownAutomationShopUnlockMessage':
          hasShownAutomationShopUnlockMessage,
      'hasShownTargetStarAutomationIntro': hasShownTargetStarAutomationIntro,
      'hasReceivedAutomationKitFromHunter': hasReceivedAutomationKitFromHunter,
      'lastAlertHunterSpawnTier': lastAlertHunterSpawnTier,
      'hasShownKitBagHint': hasShownKitBagHint,
      if (automationKitSceneId != null)
        'automationKitSceneId': automationKitSceneId,
      if (automationKitPositionX != null)
        'automationKitPositionX': automationKitPositionX,
      if (automationKitPositionY != null)
        'automationKitPositionY': automationKitPositionY,
      'automationToolPlacements': automationToolPlacementsJson,
      'automationUnlocks': automationUnlocksJson,
      'automationUpgradeLevels': automationUpgradeLevelsJson,
      'harvestStorage': harvestStorageJson,
      'hunterToolsGranted': hunterToolsGranted,
      'automationUpgradeStageTier': automationUpgradeStageTier,
      'upkeepToolFuel': upkeepToolFuel,
      'harvestToolFuel': harvestToolFuel,
      'wardToolFuel': wardToolFuel,
      if (harvestTankFuelRank != null)
        'harvestTankFuelRank': harvestTankFuelRank,
      if (upkeepTankFuelRank != null)
        'upkeepTankFuelRank': upkeepTankFuelRank,
      if (wardTankFuelRank != null)
        'wardTankFuelRank': wardTankFuelRank,
      'automationAutoWillRefuel': automationAutoWillRefuel,
      'automationShopTierA': automationShopTierA,
      'automationShopTierB': automationShopTierB,
      'automationShopTierC': automationShopTierC,
      'automationShopTierD': automationShopTierD,
      'automationShopGradeHarvest': automationShopGradeHarvest,
      'automationShopGradeUpkeep': automationShopGradeUpkeep,
      'automationShopGradeWard': automationShopGradeWard,
      'automationShopGradeCommon': automationShopGradeCommon,
      'automationFuelEfficiencyTier': automationFuelEfficiencyTier,
      'codexSnapshotJson': codexSnapshotJson,
      'disclosureTier': disclosureTier,
      'totalCargoLaunches': totalCargoLaunches,
      'trueSequencePhase': trueSequencePhase,
      'pendingNarrativeMessages': pendingNarrativeMessages,
      'automationShopWillpowerAutoPay': automationShopWillpowerAutoPay,
      'trueDialSalt': trueDialSalt,
      'sentLifeScenarioBaseline': sentLifeScenarioBaseline,
      'farmPrimaryRoleIndex': farmPrimaryRoleIndex,
      'farmSubModuleIndex': farmSubModuleIndex,
      'farmRoiMultiplier': farmRoiMultiplier,
      'farmInterventionBonusCount': farmInterventionBonusCount,
      'farmCostLife': farmCostLife,
      'farmCostHistory': farmCostHistory,
      'farmCostInorganic': farmCostInorganic,
      'farmCostWillpower': farmCostWillpower,
      'farmCostCurrency': farmCostCurrency,
      'farmOutputCurrency': farmOutputCurrency,
      'farmOutputMining': farmOutputMining,
      'farmOutputCargoLife': farmOutputCargoLife,
      'farmOutputCargoHistory': farmOutputCargoHistory,
      'farmOutputCargoInorganic': farmOutputCargoInorganic,
    };
  }
}

class SaveDataManager {
  static const String _fileName = 'save_data.json';

  Future<String> get _localPath async {
    if (kIsWeb) {
      return ''; // Webではパスは不要（LocalStorage等を使用するため）
    }
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<dynamic> get _localFile async {
    if (kIsWeb) {
      return null;
    }
    final path = await _localPath;
    return File('$path/$_fileName');
  }

  Future<SaveData> loadSaveData() async {
    try {
      if (kIsWeb) {
        // Web用の簡易的な永続化（LocalStorage）
        // 実際には shared_preferences 等を使うのが一般的ですが、
        // ここではデバッグ用にデフォルト値を返すか、簡易実装を行います。
        return SaveData();
      }
      final file = await _localFile;
      if (file != null && await file.exists()) {
        final contents = await file.readAsString();
        final json = jsonDecode(contents) as Map<String, dynamic>;
        final loadedData = SaveData.fromJson(json);
        return loadedData;
      }
    } catch (e) {
      // エラーが発生した場合はデフォルト値を返す
      return SaveData();
    }
    return SaveData();
  }

  Future<void> saveGameData(SaveData data) async {
    try {
      if (kIsWeb) {
        // Webでは保存処理をスキップ（またはLocalStorageへ）
        return;
      }
      final file = await _localFile;
      if (file != null) {
        final json = jsonEncode(data.toJson());
        await file.writeAsString(json);
      }
    } catch (e) {
      debugPrint('Error saving game data: $e');
    }
  }

  Future<void> deleteSaveData() async {
    try {
      if (kIsWeb) return;
      final file = await _localFile;
      if (file != null && await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting save data: $e');
    }
  }
}
