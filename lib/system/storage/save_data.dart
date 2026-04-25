import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class SaveData {
  int currency;
  int miningPoints;
  double maxStress;
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

  // ルート進行用のカウンターとフラグ
  int hitCount;
  int giftCount;
  int scrappedObjectCount;
  int readLogCount;
  int randomActionCount;
  String? currentMission;
  List<String> triggeredRouteIds;

  // 能動性（余計な行動）システム
  Map<String, int> extraActionCounts; // ステージごとのカウント
  List<String> subRouteConfirmedStages; // 30回達成したステージID

  int dayCount;
  List<String> completedRouteIds;
  String? activeRouteId;
  int unlockedStageCount;

  // 地下の採掘状況（シーンIDごとの座標文字列リスト）
  Map<String, List<String>> dugAreas;

  bool hasShownCompassToday; // 今日の羅針盤を表示したか
  Map<String, Map<String, double>> buildingPlacements; // シーンごとの建物配置 (sceneId -> {buildingType: x})
  Map<String, int> destructibleHealths; // 破壊可能オブジェクトの状態 (uniqueId -> health)
  List<String> satisfiedNpcIds; // 満足したNPCのIDリスト
  List<String> unlockedAchievements; // 解放済みアチーブメント

  SaveData({
    this.currency = 0,
    this.miningPoints = 0,
    this.maxStress = 100.0,
    Map<String, int>? itemCounts,
    this.lastSceneId = 'outdoor_1',
    this.lastPlayerPositionX = -50.0,
    this.lastPlayerPositionY = 0.0,
    this.exitPlayerPositionX = -50.0,
    this.exitPlayerPositionY = 0.0,
    this.lastOutdoorSceneId = 'outdoor_1',
    this.lastBuildingType = 'shop',
    this.lastBuildingPositionX = -50.0,
    this.lastBuildingPositionY = 0.0,
    this.carriedItemName,
    this.equippedItemName,
    this.hitCount = 0,
    this.giftCount = 0,
    this.scrappedObjectCount = 0,
    this.readLogCount = 0,
    this.randomActionCount = 0,
    this.currentMission,
    List<String>? triggeredRouteIds,
    Map<String, int>? extraActionCounts,
    List<String>? subRouteConfirmedStages,
    this.dayCount = 1,
    List<String>? completedRouteIds,
    this.activeRouteId,
    this.unlockedStageCount = 1,
    Map<String, List<String>>? dugAreas,
    this.hasShownCompassToday = false,
    Map<String, Map<String, double>>? buildingPlacements,
    Map<String, int>? destructibleHealths,
    List<String>? satisfiedNpcIds,
    List<String>? unlockedAchievements,
  }) : itemCounts = itemCounts ?? {},
       triggeredRouteIds = triggeredRouteIds ?? [],
       extraActionCounts = extraActionCounts ?? {},
       subRouteConfirmedStages = subRouteConfirmedStages ?? [],
       completedRouteIds = completedRouteIds ?? [],
       dugAreas = dugAreas ?? {},
       buildingPlacements = buildingPlacements ?? {},
       destructibleHealths = destructibleHealths ?? {},
       satisfiedNpcIds = satisfiedNpcIds ?? [],
       unlockedAchievements = unlockedAchievements ?? [];

  // JSONからSaveDataオブジェクトを生成するファクトリコンストラクタ
  factory SaveData.fromJson(Map<String, dynamic> json) {
    return SaveData(
      currency: json['currency'] as int? ?? 0,
      miningPoints: json['miningPoints'] as int? ?? 0,
      maxStress: json['maxStress'] as double? ?? 100.0,
      itemCounts: (json['itemCounts'] as Map<dynamic, dynamic>?)?.map(
            (key, value) => MapEntry(key.toString(), value as int),
          ),
      lastSceneId: json['lastSceneId'] as String? ?? 'outdoor_1',
      lastPlayerPositionX: json['lastPlayerPositionX'] as double? ?? -50.0,
      lastPlayerPositionY: json['lastPlayerPositionY'] as double? ?? 0.0,
      exitPlayerPositionX: json['exitPlayerPositionX'] as double? ?? -50.0,
      exitPlayerPositionY: json['exitPlayerPositionY'] as double? ?? 0.0,
      lastOutdoorSceneId: json['lastOutdoorSceneId'] as String?,
      lastBuildingType: json['lastBuildingType'] as String?,
      lastBuildingPositionX: json['lastBuildingPositionX'] as double?,
      lastBuildingPositionY: json['lastBuildingPositionY'] as double?,
      carriedItemName: json['carriedItemName'] as String?,
      equippedItemName: json['equippedItemName'] as String?,
      hitCount: json['hitCount'] as int? ?? 0,
      giftCount: json['giftCount'] as int? ?? 0,
      scrappedObjectCount: json['scrappedObjectCount'] as int? ?? 0,
      readLogCount: json['readLogCount'] as int? ?? 0,
      randomActionCount: json['randomActionCount'] as int? ?? 0,
      currentMission: json['currentMission'] as String?,
      triggeredRouteIds: (json['triggeredRouteIds'] as List<dynamic>?)?.cast<String>(),
      extraActionCounts: (json['extraActionCounts'] as Map<String, dynamic>?)?.cast<String, int>(),
      subRouteConfirmedStages: (json['subRouteConfirmedStages'] as List<dynamic>?)?.cast<String>(),
      dayCount: json['dayCount'] as int? ?? 1,
      completedRouteIds: (json['completedRouteIds'] as List<dynamic>?)?.cast<String>(),
      activeRouteId: json['activeRouteId'] as String?,
      unlockedStageCount: json['unlockedStageCount'] as int? ?? 1,
      dugAreas: (json['dugAreas'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, List<String>.from(value as List)),
          ),
      hasShownCompassToday: json['hasShownCompassToday'] as bool? ?? false,
      buildingPlacements: (json['buildingPlacements'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, Map<String, double>.from(value as Map)),
      ),
      destructibleHealths: (json['destructibleHealths'] as Map<String, dynamic>?)?.cast<String, int>(),
      satisfiedNpcIds: (json['satisfiedNpcIds'] as List<dynamic>?)?.cast<String>(),
      unlockedAchievements: (json['unlockedAchievements'] as List<dynamic>?)?.cast<String>(),
    );
  }

  // SaveDataオブジェクトをJSONに変換するメソッド
  Map<String, dynamic> toJson() {
    return {
      'currency': currency,
      'miningPoints': miningPoints,
      'maxStress': maxStress,
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
      'hitCount': hitCount,
      'giftCount': giftCount,
      'scrappedObjectCount': scrappedObjectCount,
      'readLogCount': readLogCount,
      'randomActionCount': randomActionCount,
      'currentMission': currentMission,
      'triggeredRouteIds': triggeredRouteIds,
      'extraActionCounts': extraActionCounts,
      'subRouteConfirmedStages': subRouteConfirmedStages,
      'dayCount': dayCount,
      'completedRouteIds': completedRouteIds,
      'activeRouteId': activeRouteId,
      'unlockedStageCount': unlockedStageCount,
      'dugAreas': dugAreas,
      'hasShownCompassToday': hasShownCompassToday,
      'buildingPlacements': buildingPlacements,
      'destructibleHealths': destructibleHealths,
      'satisfiedNpcIds': satisfiedNpcIds,
      'unlockedAchievements': unlockedAchievements,
    };
  }
}

class SaveDataManager {
  static const String _fileName = 'save_data.json';

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/$_fileName');
  }

  Future<SaveData> loadSaveData() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
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
      final file = await _localFile;
      final json = jsonEncode(data.toJson());
      await file.writeAsString(json);
    } catch (e) {
      debugPrint('Error saving game data: $e');
    }
  }

  Future<void> deleteSaveData() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting save data: $e');
    }
  }
}
