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
  String? carriedItemDescription;
  String? carriedItemSpritePath;
  double? carriedItemSizeX;
  double? carriedItemSizeY;
  int? carriedItemValue;

  // 今後追加される可能性のあるその他のデータ

  SaveData({
    this.currency = 0,
    this.miningPoints = 0,
    this.maxStress = 100.0, // Playerクラスの初期値に合わせる
    Map<String, int>? itemCounts,
    this.lastSceneId = 'outdoor', // デフォルトは屋外シーン
    this.lastPlayerPositionX = -50.0, // デフォルトのプレイヤーX座標
    this.lastPlayerPositionY = 0.0, // デフォルトのプレイヤーY座標（OutdoorSceneで設定される）
    this.exitPlayerPositionX = -50.0, // 建物に入る前のX座標
    this.exitPlayerPositionY = 0.0, // 建物に入る前のY座標
    this.lastOutdoorSceneId = 'outdoor',
    this.lastBuildingType = 'shop',
    this.lastBuildingPositionX = -50.0,
    this.lastBuildingPositionY = 0.0,
    this.carriedItemName,
    this.carriedItemDescription,
    this.carriedItemSpritePath,
    this.carriedItemSizeX,
    this.carriedItemSizeY,
    this.carriedItemValue,
  }) : itemCounts = itemCounts ?? {};

  // JSONからSaveDataオブジェクトを生成するファクトリコンストラクタ
  factory SaveData.fromJson(Map<String, dynamic> json) {
    return SaveData(
      currency: json['currency'] as int? ?? 0,
      miningPoints: json['miningPoints'] as int? ?? 0,
      maxStress: json['maxStress'] as double? ?? 100.0,
      itemCounts: Map<String, int>.from(
        (json['itemCounts'] as Map<dynamic, dynamic>?)?.map(
              (key, value) => MapEntry(key.toString(), value as int),
            ) ??
            {},
      ),
      lastSceneId: json['lastSceneId'] as String? ?? 'outdoor',
      lastPlayerPositionX: json['lastPlayerPositionX'] as double? ?? -50.0,
      lastPlayerPositionY: json['lastPlayerPositionY'] as double? ?? 0.0,
      exitPlayerPositionX: json['exitPlayerPositionX'] as double? ?? -50.0,
      exitPlayerPositionY: json['exitPlayerPositionY'] as double? ?? 0.0,
      lastOutdoorSceneId: json['lastOutdoorSceneId'] as String?,
      lastBuildingType: json['lastBuildingType'] as String?,
      lastBuildingPositionX: json['lastBuildingPositionX'] as double?,
      lastBuildingPositionY: json['lastBuildingPositionY'] as double?,
      carriedItemName: json['carriedItemName'] as String?,
      carriedItemDescription: json['carriedItemDescription'] as String?,
      carriedItemSpritePath: json['carriedItemSpritePath'] as String?,
      carriedItemSizeX: json['carriedItemSizeX'] as double?,
      carriedItemSizeY: json['carriedItemSizeY'] as double?,
      carriedItemValue: json['carriedItemValue'] as int?,
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
      'carriedItemDescription': carriedItemDescription,
      'carriedItemSpritePath': carriedItemSpritePath,
      'carriedItemSizeX': carriedItemSizeX,
      'carriedItemSizeY': carriedItemSizeY,
      'carriedItemValue': carriedItemValue,
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
    return SaveData(); // ファイルが存在しないか、読み込みに失敗した場合はデフォルト値を返す
  }

  Future<void> saveGameData(SaveData data) async {
    try {
      final file = await _localFile;
      final jsonString = jsonEncode(data.toJson());
      await file.writeAsString(jsonString);
    } catch (e) {
      debugPrint('save_data.dart: Error saving game data: $e');
    }
  }
}
