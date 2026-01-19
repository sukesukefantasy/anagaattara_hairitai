import 'package:anagaattara_hairitai/system/storage/save_data.dart';
import 'package:flutter/foundation.dart'; // debugPrintのためにインポート

class GameRuntimeState {
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
  String currentSceneId = 'outdoor'; // 現在のシーンID
  double currentPlayerPositionX = -50.0; // 現在のプレイヤーX座標
  double currentPlayerPositionY = 0.0; // 現在のプレイヤーY座標
  double exitPlayerPositionX = -50.0; // 建物に入るまえにいたX座標
  double exitPlayerPositionY = 0.0; // 建物に入るまえにいたY座標

  String? currentOutdoorSceneId; // 現在の屋外シーンID
  String? currentBuildingType; // 現在の建物のタイプ
  double? currentBuildingPositionX; // 現在の建物のX座標
  double? currentBuildingPositionY; // 現在の建物のY座標

  // 運搬中のアイテム情報
  String? carriedItemName;
  String? carriedItemDescription;
  String? carriedItemSpritePath;
  double? carriedItemSizeX;
  double? carriedItemSizeY;
  int? carriedItemValue;

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
    carriedItemDescription = data.carriedItemDescription;
    carriedItemSpritePath = data.carriedItemSpritePath;
    carriedItemSizeX = data.carriedItemSizeX;
    carriedItemSizeY = data.carriedItemSizeY;
    carriedItemValue = data.carriedItemValue;

    debugPrint('--- GameRuntimeState loaded from SaveData. ---');
    printState();
  }

  // SaveDataオブジェクトを生成
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
      carriedItemDescription: carriedItemDescription,
      carriedItemSpritePath: carriedItemSpritePath,
      carriedItemSizeX: carriedItemSizeX,
      carriedItemSizeY: carriedItemSizeY,
      carriedItemValue: carriedItemValue,
    );
  }

  // ランタイムセーブデータを恒久セーブデータに保存
  Future<void> saveGame() async {
    final saveData = toSaveData();
    await SaveDataManager().saveGameData(saveData);
    printState();
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
    debugPrint('  carriedItemDescription: $carriedItemDescription');
    debugPrint('  carriedItemSpritePath: $carriedItemSpritePath');
    debugPrint('  carriedItemSizeX: $carriedItemSizeX');
    debugPrint('  carriedItemSizeY: $carriedItemSizeY');
    debugPrint('  carriedItemValue: $carriedItemValue');
    debugPrint('------------------------------------'); */
  }
}
