import 'package:anagaattara_hairitai/component/common/terrain/dig_shape_template.dart';
import 'package:anagaattara_hairitai/component/common/terrain/terrain_field.dart';
import 'package:anagaattara_hairitai/component/common/underground/placed_floor.dart';
import 'package:anagaattara_hairitai/system/storage/save_data.dart';
import 'package:anagaattara_hairitai/system/stage_micro_log.dart';
import 'package:anagaattara_hairitai/system/stage_combat_profile.dart';
import 'package:anagaattara_hairitai/system/farm_role_profile.dart';
import 'package:anagaattara_hairitai/system/codex/codex_snapshot.dart';
import 'package:anagaattara_hairitai/system/automation_tool_kind.dart';
import 'package:anagaattara_hairitai/system/automation_harvest_storage.dart';
import 'package:anagaattara_hairitai/system/automation_tool_placement.dart';
import 'package:anagaattara_hairitai/system/automation_ability_catalog.dart';
import 'package:anagaattara_hairitai/system/automation_shop_grade.dart';
import 'package:anagaattara_hairitai/system/automation_tool_state.dart';
import 'package:flutter/foundation.dart'; // debugPrintのためにインポート
import 'dart:async'; // Add this line
import 'package:flame/extensions.dart';
import '../../main.dart';

/// カーゴゲージへ飛ばす残滓の種別（UI 演出用）。
enum CargoHudFlyKind { life, history, inorganic }

class CargoHudFlyEvent {
  final CargoHudFlyKind kind;
  final Vector2 worldPosition;

  /// 該当種のゲージ充足率（`count / residueCapacity`）の変化。HUD で飛行に同期して補間する。
  final double fillBefore;
  final double fillAfter;

  CargoHudFlyEvent({
    required this.kind,
    required this.worldPosition,
    required this.fillBefore,
    required this.fillAfter,
  });
}

class CargoTransferFlyEvent {
  final CargoHudFlyKind kind;
  final int count;
  CargoTransferFlyEvent({required this.kind, required this.count});
}

class GameRuntimeState extends ChangeNotifier {
  // 資源蓄積イベント用のストリーム
  final _cargoAccumulatedController = StreamController<(int life, int history, int inorganic)>.broadcast();
  Stream<(int life, int history, int inorganic)> get cargoAccumulatedStream => _cargoAccumulatedController.stream;

  /// 残滓回収時（ワールド座標から HUD へ飛ばす演出用）
  final _cargoHudFlyController = StreamController<CargoHudFlyEvent>.broadcast();
  Stream<CargoHudFlyEvent> get cargoHudFlyStream => _cargoHudFlyController.stream;

  /// 資源蓄積時（HUD からワールド内のカーゴへ飛ばす演出用）
  final _cargoTransferFlyController = StreamController<CargoTransferFlyEvent>.broadcast();
  Stream<CargoTransferFlyEvent> get cargoTransferFlyStream => _cargoTransferFlyController.stream;

  @override
  void dispose() {
    _cargoAccumulatedController.close();
    _cargoHudFlyController.close();
    _cargoTransferFlyController.close();
    super.dispose();
  }

  void triggerTransferFly(CargoHudFlyKind kind, int count) {
    _cargoTransferFlyController.add(CargoTransferFlyEvent(kind: kind, count: count));
  }

  /// [ChangeNotifier.notifyListeners] の公開ラッパー（extension からの更新通知用）。
  void notifyRuntimeChanged() => notifyListeners();

  /// v8.3 マクロルートID（セーブ・ログ用）
  static const String macroRouteNourishment = 'macro_nourishment';
  static const String macroRouteDestroy = 'macro_destroy';
  static const String macroRouteNormal = 'macro_normal';
  static const String macroRouteTrue = 'macro_true';

  /// Destroy マクロ資格の暫定閾値（§6.2 TBD）。設計変更時はここだけを触る。
  static const int kDestroyMacroKillThresholdTbd = 25;
  static const int kDestroyMacroLifeCargoThresholdTbd = 80;

  /// True 系へ誘導するための父のメモ（周回報酬で付与）。§16 の材料。
  static const Set<String> kFatherMemoKeysForTrainBlock = {
    'father_memo_nourishment_clear',
    'father_memo_destroy_clear',
  };

  /// True 条件用に揃えるべき父のメモ（現状は周回2枚＝上記と同一）。
  static Set<String> get kAllFatherMemoKeysForTrue =>
      kFatherMemoKeysForTrainBlock;

  /// Normal マクロ判定：この周回に「生命」カーゴを母星へ送った累計がこれ以下なら生命寄りとみなさない（§6.2 TBD）。
  static const int kNormalMacroSentLifeCapTbd = 20;

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
  double currentStress = 0.0;
  double maxIntegrity = 1000.0;
  double currentIntegrity = 1000.0;
  Map<String, int> itemCounts = {};
  String currentSceneId = 'outdoor_0'; // 現在のシーンID (初期値をoutdoor_0に変更)
  double currentPlayerPositionX = -50.0; // 現在のプレイヤーX座標
  double currentPlayerPositionY = 0.0; // 現在のプレイヤーY座標
  double exitPlayerPositionX = -50.0; // 建物に入るまえにいたX座標
  double exitPlayerPositionY = 0.0; // 建物に入るまえにいたY座標

  String? currentOutdoorSceneId = 'outdoor_0'; // 現在の屋外シーンID (初期値をoutdoor_0に変更)
  String? currentBuildingType; // 現在の建物のタイプ
  double? currentBuildingPositionX; // 現在の建物のX座標
  double? currentBuildingPositionY; // 現在の建物のY座標

  // デバッグ用：初期ステージを上書きしたい場合（例：'outdoor_4'）
  // 開発時以外は null にしておく
  String? debugInitialStage;

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

  bool hasShownCompassToday = false; // 今日の羅針盤を表示したか

  bool isAutoPlay = false; // オートプレイ中フラグ

  // シミュレーション・サイクル関連
  int scenarioCount = 1; // シナリオ周回数
  
  // 真実のログ（地下アーカイブ用）
  Map<String, String> missionTrueLogs = {}; 

  int dayCount = 1;

  // 地下の採掘状況
  Map<String, List<String>> dugAreas = {};

  /// 経路ベース掘削（シーンIDごと）
  Map<String, List<CarveStamp>> carveStamps = {};

  /// 地下床板（シーンIDごと）
  Map<String, List<PlacedFloor>> placedFloors = {};

  /// プレイヤー定義の掘削断面型。
  DigShapeTemplate? digShapeTemplate;

  // 建物配置の永続化
  Map<String, Map<String, double>> buildingPlacements = {};
  
  // 破壊可能オブジェクトの状態
  Map<String, int> destructibleHealths = {};
  
  // 満足したNPCのID
  Set<String> satisfiedNpcIds = {};

  // プレイヤー能力強化
  double hpBonus = 0.0;
  double stressBonus = 0.0;
  double throwPowerBonus = 1.0;
  double movementSpeedBonus = 1.0;
  bool canRun = false;

  // キャリブレーション（自己調整）パラメータ (0.0 - 1.0)
  double hpCalibrationScale = 1.0;
  double speedCalibrationScale = 1.0;
  double powerCalibrationScale = 1.0;
  double stressCalibrationScale = 1.0;

  int youngUncleDialogueStep = 0;
  bool hasIdentifiedYoungUncle = false;
  List<String> unlockedDiaryEntries = [];

  /// UI・ロジックとも「意志の核1個」の容量単位。
  /// 既定5個=10 ⇒ [defaultMaxWillCoreValue] と一致。
  static const double willCoreUnit = 2.0;

  static const double defaultMaxWillCoreValue = 10.0;

  /// 残滓→意志力（複合体）換算の調和比 生命:無機:歴史。設計ドキュメント v8.2 §1（システム換算レイヤー）。
  static const double residueHarmonyLife = 4.0;
  static const double residueHarmonyInorganic = 6.0;
  static const double residueHarmonyHistory = 1.0;

  /// 加重残滓がこの値に達すると「意志力換算1」。ロア／将来の成長処理用。
  static const double residueUnitsPerWillComposite = 100.0;

  /// 意志力換算100 で意志の核1個分（`willCoreUnit` との橋渡しは別処理で整合）。
  static const double willCompositeUnitsPerCore = 100.0;

  /// 耐久力（integrity）を内部で持つとき、小数は .0 と .5 のみに揃える。
  static double quantizeIntegrityHalf(double v) => (v * 2.0).round() / 2.0;

  double currentWillpower = defaultMaxWillCoreValue;
  double maxWillCoreValue = defaultMaxWillCoreValue;
  double willpowerSpentInStage = 0.0;
  int destructionPointsInStage = 0;

  // 母星ステータスと星の警戒度
  double homePlanetHumanity = 0.0;
  double homePlanetEfficiency = 0.0;
  double homePlanetRealism = 0.0;
  double starAlertLevel = 0.0;

  // プレイヤーが現在所持している資源（HUDに表示される）
  int playerLifeCount = 0;
  int playerHistoryCount = 0;
  int playerInorganicCount = 0;

  // カーゴに蓄積された資源（拠点に預けた分）
  int cargoLifeCount = 0;
  int cargoHistoryCount = 0;
  int cargoInorganicCount = 0;

  /// 次のステージで出現させる支援物資（Toolbox）の予約フラグ
  bool pendingToolboxReward = false;

  /// 各資源の最大蓄積数
  static const int residueCapacity = 1000;

  static int clampResidueCount(int value) =>
      value.clamp(0, residueCapacity);

  // カーゴ射出フラグ（射出後に電車が来る。ステージリセット時にfalseに戻る）
  bool isCargoLaunched = false;

  // 自動化キットの段階 (0 = 未設置, 1 = 手動, 2 = キット設置, 3 = キット強化, 4 = 意志の核挿入)
  // ステージをまたいでも段階を引き継ぐ（プレイヤーの「依存度」の記録）
  int automationKitStage = 0;

  // 自動化キットの累積稼働時間（生産ログとして記録）
  double automationKitTotalRuntime = 0.0;

  /// C-2 契約（§6.2 Nourishment 確定）。`resetStageState` では消さない。
  bool automationContractC2 = false;

  /// §11 チュートリアル：母星で「搬入経路」を接続したか。
  /// 表向きは帰還支援。裏では C-2 で「全開」されうる。
  bool hasConnectedSupplyRoute = false;

  /// マクロクリア／到達フラグの集合（周回報酬・分岐用）
  Set<String> completedMacroRoutes = {};

  /// C-2 未契約かつ閾値を満たしたときに立つ資格フラグ。
  bool destroyMacroPathQualified = false;

  int lifetimeEnemyKills = 0;
  int lifetimeLifeCargoAccumulated = 0;
  double totalWillpowerConsumed = 0.0;

  List<StageMicroLogEntry> stageMicroLogEntries = [];

  bool hasShownAutomationShopUnlockMessage = false;

  /// 対象星初回入場オンボーディング（§ ファーム統合）
  bool hasShownTargetStarAutomationIntro = false;

  /// 警戒狩人から自動化キットを初回取得済み
  bool hasReceivedAutomationKitFromHunter = false;

  /// 最後に警戒狩人をスポーンした警戒ティア
  int lastAlertHunterSpawnTier = 0;

  /// バッグにキットを入れたあと1回だけ表示
  bool hasShownKitBagHint = false;

  /// 設置済み自動化キットの屋外シーン ID（1台のみ）
  String? automationKitSceneId;

  double? automationKitPositionX;
  double? automationKitPositionY;

  /// 3種自動化装置の設置（各種 max 1 から拡張可）
  List<AutomationToolPlacement> automationToolPlacements = [];

  /// ショップで開放した能力
  Map<String, bool> automationUnlocks = {};

  /// 装置インタラクトで上げた強化レベル
  Map<String, int> automationUpgradeLevels = {};

  /// 収穫ツール内蔵ストレージ
  AutomationHarvestStorage harvestStorage = AutomationHarvestStorage();

  /// 警戒狩人から付与済みの装置タイプ（harvest/upkeep/ward）
  List<String> hunterToolsGranted = [];

  /// 強化上限用：到達した最高調査ステージ tier（1=outdoor_1 …）。[AutomationAbilityCatalog] と同期。
  int automationUpgradeStageTier = 1;

  /// 整備ツール共有燃料
  double upkeepToolFuel = 40.0;

  double harvestToolFuel = 40.0;
  double wardToolFuel = 40.0;

  /// タンク内燃料ランク（`AutomationFuelRank.toJson()`）
  String? harvestTankFuelRank;
  String? upkeepTankFuelRank;
  String? wardTankFuelRank;

  /// 燃料切れ時に意志力で自動補給する
  bool automationAutoWillRefuel = false;

  /// GameUI が1回だけ対象星オンボーディングを出すためのフラグ（セーブしない）
  bool pendingTargetStarAutomationIntro = false;

  /// 警戒ティア上昇で狩人スポーン待ち（セーブしない）
  int pendingAlertHunterSpawnTier = 0;

  /// 狩人初登場メッセージ（セーブしない）
  bool pendingAlertHunterIntroMessage = false;

  /// 狩人撃破でキット取得後の通知（セーブしない）
  bool pendingKitFromHunterNotice = false;

  /// 自動化ショップツリー §5（キット本体の `automationKitStage` と併用）
  int automationShopTierA = 0;
  int automationShopTierB = 0;
  int automationShopTierC = 0;
  int automationShopTierD = 0;

  int automationShopGradeHarvest = 0;
  int automationShopGradeUpkeep = 0;
  int automationShopGradeWard = 0;
  int automationShopGradeCommon = 0;

  /// 共通タブ：燃費改善段階（common_4 購入で 1）。
  int automationFuelEfficiencyTier = 0;

  /// 意志自動補給のクールダウン（ランタイムのみ・非セーブ）。
  double automationAutoRefuelCooldownRemaining = 0;

  /// ガソリン缶の燃料残量（0.0 - 40.0）
  double gasolineCanFuel = 0.0;
  static const double maxGasolineCanFuel = 40.0;

  CodexSnapshot codex = CodexSnapshot.empty();

  // --- ステージ滞留中のみの微細カウンタ（セーブしない）---
  int microPendingRogue = 0;
  int microPendingFarm = 0;
  int microPendingExplore = 0;
  int microPendingSpecial = 0;

  /// A 系：短時間ドロップ吸引用（セーブしない）
  double automationAutoPickupSecondsRemaining = 0.0;

  /// GameUI が1回だけ青通知を出すためのフラグ
  bool pendingAutomationShopUnlockNotice = false;

  /// §13 開示（0=序, 1=中, 2=終）
  int disclosureTier = 0;

  /// 累計カーゴ射出（`launchCargo` 回数）
  int totalCargoLaunches = 0;

  /// True 深層 0=未開始, 1=廊下, 2=金庫, 3=終盤, 4=完了
  int trueSequencePhase = 0;

  /// §6.1 次シーンで消費する短文メッセージ
  List<String> pendingNarrativeMessages = [];

  /// B-2：意志力自動支払い基盤
  bool automationShopWillpowerAutoPay = false;

  // --- ファーム駆け引き（§ ファーム駆け引き v0.1）---
  int farmPrimaryRoleIndex = 0;
  int farmSubModuleIndex = 0;
  double farmRoiMultiplier = 1.0;
  double farmInterventionWindowSeconds = 0.0;
  double farmDoubleCycleRemaining = 0.0;
  int farmInterventionBonusCount = 0;
  int farmCostLife = 0;
  int farmCostHistory = 0;
  int farmCostInorganic = 0;
  double farmCostWillpower = 0;
  int farmCostCurrency = 0;
  int farmOutputCurrency = 0;
  int farmOutputMining = 0;
  int farmOutputCargoLife = 0;
  int farmOutputCargoHistory = 0;
  int farmOutputCargoInorganic = 0;

  /// 6桁ダイヤル用シード（セーブ毎）
  int? trueDialSalt;

  /// 現在シナリオ周回の `sentLifeResourceCount` 開始値（Normal 判定）。
  int sentLifeScenarioBaseline = 0;

  // 送信済み資源カウント（発射後に移動される）
  int sentLifeResourceCount = 0;
  int sentHistoryResourceCount = 0;
  int sentInorganicResourceCount = 0;

  // おじさんの記憶の断片（地下で復元される前の生データ）
  static const Map<String, String> uncleMemoryFragments = {
    'outdoor_1': "「……この星の石は、磨くと本当に綺麗なんだ。いつか、あの子に見せてやりたいな。」",
    'outdoor_2': "「……生命の鼓動を感じる。彼らもまた、この過酷な環境で必死に生きているんだ。」",
    'outdoor_3': "「……かつての繁栄の跡。形あるものは壊れるが、そこに込められた思いは消えないと信じたい。」",
    'outdoor_4': "「……誰かの声が聞こえる。孤独なのは私だけじゃない。……君も、そうだろう？」",
    'outdoor_philosophy': "「……深淵を覗くとき、深淵もまたこちらを覗いている。……私は、私であり続けられるだろうか。」",
  };

  // おじさんの日記（地下で復元された後の完成データ）
  static const Map<String, String> uncleDiaryEntries = {
    'diary_1': "○月×日：この星の石は、磨くと本当に綺麗なんだ。いつか、あの子に見せてやりたいな。",
    'diary_2': "○月×日：生命の鼓動を感じる。彼らもまた、この過酷な環境で必死に生きているんだ。",
    'diary_3': "○月×日：かつての繁栄の跡。形あるものは壊れるが、そこに込められた思いは消えないと信じたい。",
    'diary_4': "○月×日：誰かの声が聞こえる。孤独なのは私だけじゃない。……君も、そうだろう？",
    'diary_5': "○月×日：深淵を覗くとき、深淵もまたこちらを覗いている。……私は、私であり続けられるだろうか。",
  };

  void addStress(double amount) {
    currentStress = (currentStress + amount).clamp(0.0, maxStress);
    if (currentStress >= maxStress * 0.8) {
      // ストレスが80%以上なら耐久力を削る（以前の2倍の効率で減少）
      decreaseIntegrity(amount * 1.0); 
    }
    notifyListeners();
  }

  /// 状態モデル側の耐久減少（現状は [addStress] 経由のみ）。
  /// プレイヤー実体の耐久・ゲームオーバーは [Player.decreaseIntegrity] が正。
  /// v8.2 §7 に合わせ、ここでは `wither` を発火しない。
  void decreaseIntegrity(double amount) {
    currentIntegrity = quantizeIntegrityHalf(currentIntegrity - amount);
    if (currentIntegrity <= 0) {
      currentIntegrity = 0;
    }
    notifyListeners();
  }

  /// 深層廊下中は意志力消費を抑える（§17 試用版の近似）。
  bool get isTrueCorridorTrial =>
      trueSequencePhase >= 1 &&
      trueSequencePhase < 4 &&
      currentOutdoorSceneId == 'outdoor_true_corridor';

  /// [currentWillpower] を `0`〜`maxWillCoreValue` に収める（セーブ不整合対策）。
  void clampCurrentWillpowerToCapacity() {
    currentWillpower = currentWillpower.clamp(0.0, maxWillCoreValue);
  }

  /// 耐久が 0 になったあとの復帰コスト：`currentWillpower` から [willCoreUnit] だけ減らす（上限は削らない）。
  /// 呼び出し側で `currentWillpower > willCoreUnit` を既に確認すること。
  void payWillCoreUnitAfterIntegrityKnockdown() {
    currentWillpower -= willCoreUnit;
    clampCurrentWillpowerToCapacity();
    notifyListeners();
    saveGame();
  }

  /// [MyGame.gameOver] シーケンス完了時: `maxWillCoreValue` は変えず、`currentWillpower` を
  /// [defaultMaxWillCoreValue] まで補充（実効上限は max）。
  void refillCurrentWillpowerAfterGameOver() {
    final cap = maxWillCoreValue;
    currentWillpower =
        cap <= defaultMaxWillCoreValue ? cap : defaultMaxWillCoreValue;
    clampCurrentWillpowerToCapacity();
    notifyListeners();
  }

  // 意志力の消費
  // isNourishment=true のとき（労働・奉仕等の「依存」行動）は生命資源が自動蓄積される
  void consumeWillpower(double amount, {bool isNourishment = false}) {
    if (isTrueCorridorTrial) {
      if (amount > 0) {
        noteMicroCategorySpecial(1);
      }
      return;
    }
    currentWillpower -= amount;
    clampCurrentWillpowerToCapacity();

    if (amount > 0) {
      totalWillpowerConsumed += amount;
      _maybeRaiseAutomationShopUnlockNotice();
    }

    if (isNourishment) {
      willpowerSpentInStage += amount;
      // 依存行動による生命資源の自動蓄積（意志活動の駆動熱が星に回収される）
      // 5消費につき1資源
      final gain = (amount / 5).floor();
      if (gain > 0) {
        accumulateCargo(life: gain);
      }
    }

    if (currentWillpower <= 0) {
      // 意志力が尽きたら大地に溶ける（ゲームオーバー）
    }
    notifyListeners();
  }

  // 意志力の回復
  void reclaimWillpower(double amount) {
    currentWillpower += amount;
    clampCurrentWillpowerToCapacity();
    notifyListeners();
    saveGame();
  }

  // 超回復（Growth）: 消費した分を休息で補うことで最大値が成長
  void superRecovery() {
    if (willpowerSpentInStage >= 10.0) {
      // 10以上消費していれば、その10%分最大値が成長
      double growth = willpowerSpentInStage * 0.1;
      maxWillCoreValue += growth;
      debugPrint('Super Recovery! Max Will Core increased by $growth to $maxWillCoreValue');
    }
    currentWillpower = maxWillCoreValue;
    clampCurrentWillpowerToCapacity();
    willpowerSpentInStage = 0.0;
    notifyListeners();
    saveGame();
  }

  // 痩せ細り（Wither）: 意志の核容量を 1 単位削る。v8.2 §7 に照らし自動耐久枯渇では呼ばない。
  // イベント・カットシーン・将来の「致命的敗北」専用トリガー向け。
  void wither() {
    maxWillCoreValue =
        (maxWillCoreValue - willCoreUnit).clamp(0.0, 1000.0);
    currentWillpower = maxWillCoreValue;
    clampCurrentWillpowerToCapacity();
    debugPrint(
        'Wither... Max Will Core decreased by $willCoreUnit to $maxWillCoreValue');
    notifyListeners();
    saveGame();
  }

  /// 採掘ポイントを消費する（合成システムから呼び出される）
  void spendMiningPoints(int amount) {
    miningPoints = (miningPoints - amount).clamp(0, 999999);
    notifyListeners();
  }

  // 星の警戒度を増減する（負値で低下）
  void addStarAlertLevel(double amount) {
    final prevTier = starAlertHudTier;
    starAlertLevel = (starAlertLevel + amount).clamp(0.0, 10.0);
    if (amount > 0) {
      final newTier = starAlertHudTier;
      if (newTier > prevTier &&
          isOnTargetStarOutdoor &&
          newTier > lastAlertHunterSpawnTier) {
        pendingAlertHunterSpawnTier = newTier;
        if (!hasReceivedAutomationKitFromHunter &&
            hunterToolsGranted.length < AutomationToolKind.values.length) {
          pendingAlertHunterIntroMessage = true;
        }
      }
    }
    notifyListeners();
  }

  // カーゴに資源を自動蓄積する（「行動の残滓」として呼び出される）
  /// [pickupWorldPoint] が与えられたとき、該当種の HUD への飛行演出が可能（微粒子回収など）。
  void accumulateCargo({
    int life = 0,
    int history = 0,
    int inorganic = 0,
    Vector2? pickupWorldPoint,
  }) {
    final int ol = playerLifeCount;
    final int oh = playerHistoryCount;
    final int oi = playerInorganicCount;

    final double cap = residueCapacity.toDouble();

    double fillBeforeForKind(CargoHudFlyKind k) {
      if (cap <= 0) return 0;
      final c = switch (k) {
        CargoHudFlyKind.life => ol,
        CargoHudFlyKind.history => oh,
        CargoHudFlyKind.inorganic => oi,
      };
      return (c / cap).clamp(0.0, 1.0);
    }

    playerLifeCount = clampResidueCount(playerLifeCount + life);
    playerHistoryCount = clampResidueCount(playerHistoryCount + history);
    playerInorganicCount = clampResidueCount(playerInorganicCount + inorganic);

    double fillAfterForKind(CargoHudFlyKind k) {
      if (cap <= 0) return 0;
      final c = switch (k) {
        CargoHudFlyKind.life => playerLifeCount,
        CargoHudFlyKind.history => playerHistoryCount,
        CargoHudFlyKind.inorganic => playerInorganicCount,
      };
      return (c / cap).clamp(0.0, 1.0);
    }

    if (pickupWorldPoint != null) {
      final p = pickupWorldPoint.clone();
      if (life > 0) {
        _cargoHudFlyController.add(
          CargoHudFlyEvent(
            kind: CargoHudFlyKind.life,
            worldPosition: p,
            fillBefore: fillBeforeForKind(CargoHudFlyKind.life),
            fillAfter: fillAfterForKind(CargoHudFlyKind.life),
          ),
        );
      }
      if (history > 0) {
        _cargoHudFlyController.add(
          CargoHudFlyEvent(
            kind: CargoHudFlyKind.history,
            worldPosition: p,
            fillBefore: fillBeforeForKind(CargoHudFlyKind.history),
            fillAfter: fillAfterForKind(CargoHudFlyKind.history),
          ),
        );
      }
      if (inorganic > 0) {
        _cargoHudFlyController.add(
          CargoHudFlyEvent(
            kind: CargoHudFlyKind.inorganic,
            worldPosition: p,
            fillBefore: fillBeforeForKind(CargoHudFlyKind.inorganic),
            fillAfter: fillAfterForKind(CargoHudFlyKind.inorganic),
          ),
        );
      }
    }

    if (life > 0) {
      lifetimeLifeCargoAccumulated += life;
      evaluateDestroyMacroPathQualification();
    }

    // イベントを通知
    _cargoAccumulatedController.add((life, history, inorganic));

    notifyListeners();
  }

  /// §6.2 — C-2 後は Destroy 側へは「振り替わらない」前提で資格フラグだけ評価。
  void evaluateDestroyMacroPathQualification() {
    if (automationContractC2) return;
    if (lifetimeEnemyKills < kDestroyMacroKillThresholdTbd) return;
    if (lifetimeLifeCargoAccumulated < kDestroyMacroLifeCargoThresholdTbd) {
      return;
    }
    if (destroyMacroPathQualified) return;
    destroyMacroPathQualified = true;
    saveGame();
    notifyListeners();
  }

  void registerLifetimeEnemyKill() {
    lifetimeEnemyKills += 1;
    noteMicroCategoryRogue(1);
    _refreshDisclosureTierFromWorldProgress();
    evaluateDestroyMacroPathQualification();
    saveGame();
    notifyListeners();
  }

  /// C-2 契約確定（キットまたはショップから呼ぶ）
  void registerAutomationContractC2() {
    automationContractC2 = true;
    destroyMacroPathQualified = false;
    if (automationShopGradeCommon < 6) automationShopGradeCommon = 6;
    syncLegacyShopTiersFromGrades();
    _refreshDisclosureTierFromWorldProgress();
    if (hasConnectedSupplyRoute) {
      pendingNarrativeMessages.add('〔星の通知〕接続済みの経路が、勝手に「全開」された。');
      while (pendingNarrativeMessages.length > 12) {
        pendingNarrativeMessages.removeAt(0);
      }
    }
    saveGame();
    notifyListeners();
  }

  /// §11 チュートリアル：搬入経路を接続する（母星）。
  void connectSupplyRouteIfNeeded() {
    if (hasConnectedSupplyRoute) return;
    hasConnectedSupplyRoute = true;
    pendingNarrativeMessages.add('〔母星〕搬入経路が接続された。');
    while (pendingNarrativeMessages.length > 12) {
      pendingNarrativeMessages.removeAt(0);
    }
    saveGame();
    notifyListeners();
  }

  /// 設計確認用スタブ — 駅・NPC・通信への遅延反映は今後ここへ集約。
  void applyDeferredStageFeedback() {
    if (stageMicroLogEntries.isEmpty) return;
    final e = stageMicroLogEntries.last;
    String? msg;
    if (e.rogueHints >= 3) {
      msg = '〔観測〕痕跡が濃い。この区間、警戒が尾を引いている。';
    } else if (e.farmHints >= 2) {
      msg = '〔観測〕機械の熱が地面に染みている。';
    } else if (e.exploreHints >= 3) {
      msg = '〔観測〕誰かの輪郭が揺らいだ。';
    } else if (e.specialHints >= 1) {
      msg = '〔観測〕自動化の回路が疼く。';
    }
    if (msg != null) {
      pendingNarrativeMessages.add(msg);
      while (pendingNarrativeMessages.length > 12) {
        pendingNarrativeMessages.removeAt(0);
      }
    }
  }

  /// §6.2 周回クリア直前に呼ぶ。父のメモと `completedMacroRoutes` を更新。
  void applyScenarioClearMacroRewardsForCompletedRun() {
    final lifeThis = (sentLifeResourceCount - sentLifeScenarioBaseline)
        .clamp(0, 1000000);
    if (automationContractC2) {
      registerMacroRouteCompleted(macroRouteNourishment);
      unlockDiaryEntryIfNew('father_memo_nourishment_clear');
    } else if (destroyMacroPathQualified) {
      registerMacroRouteCompleted(macroRouteDestroy);
      unlockDiaryEntryIfNew('father_memo_destroy_clear');
    } else if (!automationContractC2 &&
        !destroyMacroPathQualified &&
        lifeThis <= kNormalMacroSentLifeCapTbd) {
      registerMacroRouteCompleted(macroRouteNormal);
    } else {
      registerMacroRouteCompleted(macroRouteNormal);
    }
    saveGame();
    notifyListeners();
  }

  void registerMacroRouteCompleted(String routeId) {
    if (completedMacroRoutes.contains(routeId)) return;
    completedMacroRoutes = {...completedMacroRoutes, routeId};
    notifyListeners();
  }

  void unlockDiaryEntryIfNew(String key) {
    if (!unlockedDiaryEntries.contains(key)) {
      unlockedDiaryEntries = [...unlockedDiaryEntries, key];
    }
  }

  /// 6桁ダイヤル用にセーブごとの乱数シードを確保。
  void ensureTrueDialSalt() {
    if (trueDialSalt != null) return;
    trueDialSalt = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
    saveGame();
  }

  int get sixDigitTrueDialCode {
    ensureTrueDialSalt();
    var h = trueDialSalt ?? 1;
    for (final k in unlockedDiaryEntries) {
      for (var i = 0; i < k.length; i++) {
        h = (h * 131 + k.codeUnitAt(i)) & 0x7fffffff;
      }
    }
    return h % 1000000;
  }

  String get sixDigitTrueDialCodePadded =>
      sixDigitTrueDialCode.toString().padLeft(6, '0');

  void noteMicroCategoryRogue(int n) {
    if (n <= 0) return;
    microPendingRogue += n;
  }

  void noteMicroCategoryFarm(int n) {
    if (n <= 0) return;
    microPendingFarm += n;
  }

  void noteMicroCategoryExplore(int n) {
    if (n <= 0) return;
    microPendingExplore += n;
  }

  void noteMicroCategorySpecial(int n) {
    if (n <= 0) return;
    microPendingSpecial += n;
  }

  static const int kStageMicroLogCap = 200;

  /// 屋外ID→屋外IDの移動でのみ呼ぶ（[SceneManager.loadScene]）。
  void recordOutdoorToOutdoorTransition({
    required String fromOutdoorId,
    required String toOutdoorId,
  }) {
    if (fromOutdoorId == toOutdoorId) return;
    final entry = StageMicroLogEntry(
      fromOutdoorId: fromOutdoorId,
      toOutdoorId: toOutdoorId,
      rogueHints: microPendingRogue,
      farmHints: microPendingFarm,
      exploreHints: microPendingExplore,
      specialHints: microPendingSpecial,
    );
    microPendingRogue = 0;
    microPendingFarm = 0;
    microPendingExplore = 0;
    microPendingSpecial = 0;

    stageMicroLogEntries.add(entry);
    while (stageMicroLogEntries.length > kStageMicroLogCap) {
      stageMicroLogEntries.removeAt(0);
    }
    applyDeferredStageFeedback();
    saveGame();
    notifyListeners();
  }

  void tickAutomationAutoPickup(double dt) {
    if (automationAutoPickupSecondsRemaining <= 0) return;
    automationAutoPickupSecondsRemaining -= dt;
    if (automationAutoPickupSecondsRemaining < 0) {
      automationAutoPickupSecondsRemaining = 0;
    }
  }

  void tryStartAutomationAutoPickupWindow() {
    if (automationShopGradeHarvest < 1) return;
    automationAutoPickupSecondsRemaining =
        automationAutoPickupSecondsRemaining < 8.0
            ? 8.0
            : automationAutoPickupSecondsRemaining;
  }

  /// A-2 相当：自動サイクル中も短い吸引を付与
  void tryBoostAutomationAutoPickupFromAutoCycle() {
    if (automationShopGradeHarvest >= 2) {
      automationAutoPickupSecondsRemaining = 8.0;
    }
  }

  double get automationAutoPickupVacuumRange {
    if (automationAutoPickupSecondsRemaining <= 0) return 0;
    var range = 0.0;
    if (automationShopGradeHarvest >= 1) range = 100;
    if (automationShopGradeHarvest >= 3) range = 140;
    range += farmAutoPickupRangeBonus;
    return range;
  }

  /// 旧セーブ: キット Lv4 なら C-2 とみなす
  void reconcileAutomationContractWithKitStage() {
    if (automationKitStage >= 4) {
      automationContractC2 = true;
      if (automationShopGradeCommon < 6) automationShopGradeCommon = 6;
      syncLegacyShopTiersFromGrades();
    }
  }

  bool get isMacroNourishmentLocked => automationContractC2;

  /// §6.1 — 依存行動でステージ内に溜まった意志力消費。マクロ Nourishment とは別レイヤー。
  bool get isDependencyOverloadForUi =>
      willpowerSpentInStage >= 10.0;

  /// 調査対象星（outdoor_1〜4 等）。プロローグ・True・偏りデモは除外。
  static bool isTargetStarOutdoorId(String? sceneId) {
    if (sceneId == null) return false;
    if (!sceneId.startsWith('outdoor_')) return false;
    if (sceneId == 'outdoor_0') return false;
    if (sceneId.contains('philosophy')) return false;
    if (sceneId.contains('despair')) return false;
    if (sceneId.contains('true')) return false;
    return true;
  }

  bool get isOnTargetStarOutdoor =>
      isTargetStarOutdoorId(currentOutdoorSceneId);

  /// 自動化ショップHUD表示 — 対象星にいるときのみ（§ ファーム統合）
  bool get showAutomationShopEntryInHud => isOnTargetStarOutdoor;

  String outdoorIdAfterPhilosophy() {
    // §6.2: Nourishment（C-2）確定はトゥルー側屋外へ。Destroy 資格は絶望へ。旧30回サブルート分岐は廃止。
    if (automationContractC2) return 'outdoor_true';
    if (destroyMacroPathQualified) return 'outdoor_despair';
    return 'outdoor_despair';
  }

  bool get blocksTrainForTrueSequenceGate =>
      trueSequencePhase < 4 &&
      kAllFatherMemoKeysForTrue.every(unlockedDiaryEntries.contains) &&
      completedMacroRoutes.contains(macroRouteNourishment) &&
      completedMacroRoutes.contains(macroRouteDestroy);

  /// 深層 True シーケンスを駅・ロケットから開始できるか。
  bool get canStartTrueDeepSequence =>
      blocksTrainForTrueSequenceGate && trueSequencePhase == 0;

  bool get hasCompletedTrueMacro =>
      completedMacroRoutes.contains(macroRouteTrue);

  /// §22 — `isCargoLaunched` と True 深層ゲート。[onBlockedReason] で 'cargo'|'true_gate'
  bool canAdvancePastStationTrain({void Function(String reason)? onBlockedReason}) {
    if (!isCargoLaunched) {
      onBlockedReason?.call('cargo');
      return false;
    }
    if (blocksTrainForTrueSequenceGate) {
      onBlockedReason?.call('true_gate');
      return false;
    }
    return true;
  }

  void codexEnsureConnectionSeen(String npcUniqueId, {required bool satisfied}) {
    final m = Map<String, String>.from(codex.connectionStatus);
    if (m[npcUniqueId] == 'blacked') return;
    m[npcUniqueId] = satisfied ? 'satisfied' : 'normal';
    codex = codex.copyWith(connectionStatus: m);
    saveGame();
    notifyListeners();
  }

  void codexBlackedConnection(String npcUniqueId) {
    final m = Map<String, String>.from(codex.connectionStatus);
    if (m[npcUniqueId] == 'blacked') return;
    m[npcUniqueId] = 'blacked';
    codex = codex.copyWith(connectionStatus: m);
    saveGame();
    notifyListeners();
  }

  void codexIncrementCraft(String resultItemName) {
    final c = Map<String, int>.from(codex.craftCreatedCount);
    c[resultItemName] = (c[resultItemName] ?? 0) + 1;
    codex = codex.copyWith(craftCreatedCount: c);
    saveGame();
    notifyListeners();
  }

  void codexIncrementAutomationOps() {
    codex =
        codex.copyWith(automationDeviceOps: codex.automationDeviceOps + 1);
    notifyListeners();
  }

  void codexIncrementItemUsed(String itemName, {int count = 1}) {
    if (count <= 0) return;
    final c = Map<String, int>.from(codex.itemUsedCount);
    c[itemName] = (c[itemName] ?? 0) + count;
    codex = codex.copyWith(itemUsedCount: c);
    saveGame();
    notifyListeners();
  }

  void consumeAutomationShopUnlockNoticeUi() {
    pendingAutomationShopUnlockNotice = false;
    notifyListeners();
  }

  void _maybeRaiseAutomationShopUnlockNotice() {
    if (totalWillpowerConsumed < 10.0) return;
    if (hasShownAutomationShopUnlockMessage) return;
    hasShownAutomationShopUnlockMessage = true;
    noteMicroCategorySpecial(1);
    notifyListeners();
  }

  void maybeRaiseTargetStarAutomationIntro() {
    if (hasShownTargetStarAutomationIntro) return;
    if (!isOnTargetStarOutdoor) return;
    hasShownTargetStarAutomationIntro = true;
    pendingTargetStarAutomationIntro = true;
    saveGame();
    notifyListeners();
  }

  void consumeTargetStarAutomationIntroUi() {
    pendingTargetStarAutomationIntro = false;
    notifyListeners();
  }

  void consumeAlertHunterIntroMessage() {
    pendingAlertHunterIntroMessage = false;
    notifyListeners();
  }

  void consumeKitFromHunterNotice() {
    pendingKitFromHunterNotice = false;
    notifyListeners();
  }

  void recordAutomationKitPlacement(String sceneId, double x, double y) {
    recordAutomationToolPlacement(
      AutomationToolKind.upkeep,
      sceneId,
      x,
      y,
    );
  }

  // プレイヤー所持の総量
  int get totalPlayerResidueCount => playerLifeCount + playerHistoryCount + playerInorganicCount;

  // カーゴ蓄積の総量
  int get totalCargoResidueCount => cargoLifeCount + cargoHistoryCount + cargoInorganicCount;

  /// プレイヤー所持残滓の調和加重。
  double get harmonyWeightedPlayerTotal =>
      playerLifeCount * residueHarmonyLife +
      playerInorganicCount * residueHarmonyInorganic +
      playerHistoryCount * residueHarmonyHistory;

  /// プレイヤー所持残滓の意志力換算（HUD表示用）。
  double get playerWillCompositeApprox =>
      harmonyWeightedPlayerTotal / residueUnitsPerWillComposite;

  /// カーゴ内残滓の調和加重（§1 の 4:6:1）。
  double get harmonyWeightedCargoTotal =>
      cargoLifeCount * residueHarmonyLife +
      cargoInorganicCount * residueHarmonyInorganic +
      cargoHistoryCount * residueHarmonyHistory;

  /// 加重残滓を「意志力換算」単位にした値（UI・ログ用）。
  double get cargoWillCompositeApprox =>
      harmonyWeightedCargoTotal / residueUnitsPerWillComposite;

  /// 微粒子が星へ引き寄せられる加速度（大略 px/s²）。核・警戒が大きいほど強い（接続点C）。
  /// プレイヤーの物理重力とは無関係（ローグ駆け引き仕様 v0.1）。
  double get starResiduePullAcceleration {
    final coreRatio =
        (maxWillCoreValue / defaultMaxWillCoreValue).clamp(0.4, 4.0);
    final alert = (starAlertLevel / 10.0).clamp(0.0, 1.0);
    final stageMul = StageCombatProfile.forScene(currentOutdoorSceneId)
        .residuePullMultiplier;
    final willLow =
        (1.0 - (currentWillpower / maxWillCoreValue.clamp(0.01, 1e9)))
            .clamp(0.0, 1.0);
    return (55.0 + coreRatio * 95.0 + alert * 260.0 + willLow * 40.0) *
        stageMul;
  }

  /// 屋外ステージと警戒から決まる敵戦闘ティア（0–3）。
  int get effectiveEnemyCombatTier => StageCombatProfile.forScene(
        currentOutdoorSceneId,
      ).effectiveCombatTier(starAlertLevel);

  /// HUD 用警戒ティア（0–4）。
  int get starAlertHudTier =>
      StageCombatProfile.starAlertHudTier(starAlertLevel);

  /// セッション内 cargo discharge（§5）。母星射出とは別。
  ///
  /// 合計カーゴの 8% を各種から消費（種ごと最低1）。成功時は意志力を回復。
  bool tryCargoDischarge() {
    final total = totalCargoResidueCount;
    if (total < 5) return false;

    final chunk = (total * 0.08).ceil().clamp(3, total);
    var payLife = 0;
    var payHist = 0;
    var payIno = 0;
    if (cargoLifeCount > 0) {
      payLife = (chunk * cargoLifeCount / total).round().clamp(1, cargoLifeCount);
    }
    if (cargoHistoryCount > 0) {
      payHist =
          (chunk * cargoHistoryCount / total).round().clamp(1, cargoHistoryCount);
    }
    if (cargoInorganicCount > 0) {
      payIno = (chunk * cargoInorganicCount / total)
          .round()
          .clamp(1, cargoInorganicCount);
    }
    var paid = payLife + payHist + payIno;
    while (paid > chunk) {
      if (payIno > 1) {
        payIno--;
      } else if (payHist > 1) {
        payHist--;
      } else if (payLife > 1) {
        payLife--;
      } else {
        break;
      }
      paid = payLife + payHist + payIno;
    }
    if (paid <= 0) return false;

    cargoLifeCount = clampResidueCount(cargoLifeCount - payLife);
    cargoHistoryCount = clampResidueCount(cargoHistoryCount - payHist);
    cargoInorganicCount =
        clampResidueCount(cargoInorganicCount - payIno);

    final recover = maxWillCoreValue * 0.35;
    currentWillpower = (currentWillpower + recover).clamp(0.0, maxWillCoreValue);
    clampCurrentWillpowerToCapacity();

    notifyListeners();
    saveGame();
    return true;
  }

  /// §13 開示段階をプレイ傾向で引き上げる（閾値は TBD 集約）。
  void _refreshDisclosureTierFromWorldProgress() {
    var t = 0;
    if (totalCargoLaunches >= 1 || lifetimeEnemyKills >= 3) t = 1;
    if (totalCargoLaunches >= 3 ||
        lifetimeEnemyKills >= 12 ||
        automationContractC2) {
      t = 2;
    }
    if (t > disclosureTier) {
      disclosureTier = t.clamp(0, 2);
    }
  }

  // カーゴを発射し、蓄積資源を送信済みに移す（母星ステータスを更新）
  void launchCargo() {
    final launchedLife = cargoLifeCount;
    final launchedHistory = cargoHistoryCount;
    final launchedInorganic = cargoInorganicCount;
    totalCargoLaunches++;
    _refreshDisclosureTierFromWorldProgress();
    sendResources(
      life: launchedLife,
      history: launchedHistory,
      inorganic: launchedInorganic,
    );
    debugPrint(
      'Cargo launched: life=$launchedLife, history=$launchedHistory, inorganic=$launchedInorganic',
    );
    cargoLifeCount = 0;
    cargoHistoryCount = 0;
    cargoInorganicCount = 0;
    isCargoLaunched = true;
    pendingToolboxReward = true; // 次ステージで支援物資を出す

    // カーゴ後の通信（HUD 用・最小実装）。
    // 本格的な台詞テーブルは後続タスクで差し替える前提。
    currentMission = _buildVeteranCommsAfterCargo(
      life: launchedLife,
      history: launchedHistory,
      inorganic: launchedInorganic,
    );

    notifyListeners();
    saveGame();
  }

  String _buildVeteranCommsAfterCargo({
    required int life,
    required int history,
    required int inorganic,
  }) {
    final total = life + history + inorganic;
    if (total <= 0) return '';
    final lp = life / total;
    final hp = history / total;

    // C-2 後は「正しいことだけ」へ寄せる（§10・§11）。
    if (automationContractC2) {
      return '〔通信:ベテラン〕任務を続けろ。送還量は十分だ。問題ない。';
    }

    // 送還比率の粗い分岐（§10 の骨格に合わせる）
    if (lp >= 0.6) {
      return '〔通信:ベテラン〕調子はどうだ。こっちは順調だ。';
    }
    if (hp >= 0.45) {
      return '〔通信:ベテラン〕今日、父の昔話を思い出した。あいつは……';
    }
    return '〔通信:ベテラン〕現状維持はできる。だが油断するな。';
  }

  // 敵対トリガーチェック（150ポイント以上）
  bool get isDestroyTriggered => destructionPointsInStage >= 150;

  // 資源を母星に送信し、母星のステータスを更新する
  void sendResources({int life = 0, int history = 0, int inorganic = 0}) {
    sentLifeResourceCount += life;
    sentHistoryResourceCount += history;
    sentInorganicResourceCount += inorganic;

    // 母星ステータスの更新ロジック（思想対立の反映）
    // 生命資源：効率派を強化。活動性は上がるが人間性が削れる
    homePlanetEfficiency += life * 2.0;
    homePlanetHumanity -= life * 1.0;

    // 歴史資源：人間性派を強化。人間性は戻るが効率は上がらない
    homePlanetHumanity += history * 3.0;
    homePlanetEfficiency -= history * 0.5;

    // 無機資源：現実派を強化。延命とインフラ維持
    homePlanetRealism += inorganic * 2.5;
    homePlanetEfficiency += inorganic * 0.5;

    // クランプ
    homePlanetHumanity = homePlanetHumanity.clamp(0.0, 100.0);
    homePlanetEfficiency = homePlanetEfficiency.clamp(0.0, 100.0);
    homePlanetRealism = homePlanetRealism.clamp(0.0, 100.0);

    notifyListeners();
    saveGame();
  }

  // アチーブメント
  Set<String> unlockedAchievements = {};
  String? lastUnlockedAchievement;

  void unlockAchievement(String achievementId, String title) {
    if (!unlockedAchievements.contains(achievementId)) {
      unlockedAchievements.add(achievementId);
      lastUnlockedAchievement = title;
      // 通知（簡易版としてデバッグプリント、本来はUIで表示）
      debugPrint('ACHIEVEMENT UNLOCKED: $title');
      saveGame();
      notifyListeners();
      
      // 一定時間後にリセット
      Future.delayed(const Duration(seconds: 3), () {
        lastUnlockedAchievement = null;
        notifyListeners();
      });
    }
  }



  // SaveDataからデータをロード
  void loadFromSaveData(SaveData data) {
    currency = data.currency;
    miningPoints = data.miningPoints;
    maxStress = data.maxStress;
    currentStress = data.currentStress;
    maxIntegrity = data.maxIntegrity;
    currentIntegrity = quantizeIntegrityHalf(
      data.currentIntegrity.clamp(0.0, data.maxIntegrity),
    );
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

    currentMission = data.currentMission;
    scenarioCount = data.scenarioCount;
    dayCount = data.dayCount;
    dugAreas = Map<String, List<String>>.from(data.dugAreas);
    carveStamps = data.carveStamps.map(
      (key, list) => MapEntry(
        key,
        list.map((m) => CarveStamp.fromJson(m)).toList(),
      ),
    );
    placedFloors = data.placedFloors.map(
      (key, list) => MapEntry(
        key,
        list.map((m) => PlacedFloor.fromJson(m)).toList(),
      ),
    );
    digShapeTemplate = data.digShapeTemplate != null
        ? DigShapeTemplate.fromJson(data.digShapeTemplate!)
        : null;
    hasShownCompassToday = data.hasShownCompassToday;
    buildingPlacements = Map<String, Map<String, double>>.from(data.buildingPlacements.map(
      (key, value) => MapEntry(key, Map<String, double>.from(value)),
    ));
    destructibleHealths = Map<String, int>.from(data.destructibleHealths);
    satisfiedNpcIds = Set<String>.from(data.satisfiedNpcIds);
    unlockedAchievements = Set<String>.from(data.unlockedAchievements);
    missionTrueLogs = Map<String, String>.from(data.missionTrueLogs);

    hpCalibrationScale = data.hpCalibrationScale;
    speedCalibrationScale = data.speedCalibrationScale;
    powerCalibrationScale = data.powerCalibrationScale;
    stressCalibrationScale = data.stressCalibrationScale;
    youngUncleDialogueStep = data.youngUncleDialogueStep;
    hasIdentifiedYoungUncle = data.hasIdentifiedYoungUncle;
    unlockedDiaryEntries = List<String>.from(data.unlockedDiaryEntries);
    
    maxWillCoreValue = data.maxWillCoreValue;
    currentWillpower = data.currentWillpower;
    clampCurrentWillpowerToCapacity();
    willpowerSpentInStage = data.willpowerSpentInStage;
    destructionPointsInStage = data.destructionPointsInStage;
    homePlanetHumanity = data.homePlanetHumanity;
    homePlanetEfficiency = data.homePlanetEfficiency;
    homePlanetRealism = data.homePlanetRealism;
    starAlertLevel = data.starAlertLevel;
    playerLifeCount = clampResidueCount(data.playerLifeCount);
    playerHistoryCount = clampResidueCount(data.playerHistoryCount);
    playerInorganicCount = clampResidueCount(data.playerInorganicCount);
    cargoLifeCount = clampResidueCount(data.cargoLifeCount);
    cargoHistoryCount = clampResidueCount(data.cargoHistoryCount);
    cargoInorganicCount = clampResidueCount(data.cargoInorganicCount);
    isCargoLaunched = data.isCargoLaunched;
    pendingToolboxReward = data.pendingToolboxReward;
    sentLifeResourceCount = data.sentLifeResourceCount;
    sentHistoryResourceCount = data.sentHistoryResourceCount;
    sentInorganicResourceCount = data.sentInorganicResourceCount;
    automationKitStage = data.automationKitStage;
    automationKitTotalRuntime = data.automationKitTotalRuntime;

    automationContractC2 = data.automationContractC2;
    hasConnectedSupplyRoute = data.hasConnectedSupplyRoute;
    completedMacroRoutes = Set<String>.from(data.completedMacroRoutes);
    destroyMacroPathQualified = data.destroyMacroPathQualified;
    lifetimeEnemyKills = data.lifetimeEnemyKills;
    lifetimeLifeCargoAccumulated = data.lifetimeLifeCargoAccumulated;
    totalWillpowerConsumed = data.totalWillpowerConsumed;
    stageMicroLogEntries = data.stageMicroLogEntries
        .map((m) => StageMicroLogEntry.fromJson(m))
        .toList();
    hasShownAutomationShopUnlockMessage =
        data.hasShownAutomationShopUnlockMessage;
    hasShownTargetStarAutomationIntro =
        data.hasShownTargetStarAutomationIntro ||
            data.hasShownAutomationShopUnlockMessage;
    hasReceivedAutomationKitFromHunter =
        data.hasReceivedAutomationKitFromHunter;
    lastAlertHunterSpawnTier = data.lastAlertHunterSpawnTier;
    hasShownKitBagHint = data.hasShownKitBagHint;
    automationKitSceneId = data.automationKitSceneId;
    automationKitPositionX = data.automationKitPositionX;
    automationKitPositionY = data.automationKitPositionY;
    automationToolPlacements = data.automationToolPlacementsJson
        .map(AutomationToolPlacement.fromJson)
        .toList();
    automationUnlocks = data.automationUnlocksJson.map(
      (k, v) => MapEntry(k, v == true),
    );
    automationUpgradeLevels = data.automationUpgradeLevelsJson.map(
      (k, v) => MapEntry(k, (v as num).toInt()),
    );
    harvestStorage = AutomationHarvestStorage.fromJson(data.harvestStorageJson);
    hunterToolsGranted = List<String>.from(data.hunterToolsGranted);
    automationUpgradeStageTier = data.automationUpgradeStageTier;
    noteAutomationUpgradeStageTier(currentOutdoorSceneId);
    upkeepToolFuel = data.upkeepToolFuel;
    harvestToolFuel = data.harvestToolFuel;
    wardToolFuel = data.wardToolFuel;
    harvestTankFuelRank = data.harvestTankFuelRank;
    upkeepTankFuelRank = data.upkeepTankFuelRank;
    wardTankFuelRank = data.wardTankFuelRank;
    automationAutoWillRefuel = data.automationAutoWillRefuel;
    migrateLegacyAutomationKitIfNeeded();
    migrateHunterGrantsFromLegacy();
    automationShopTierA = data.automationShopTierA.clamp(0, 3);
    automationShopTierB = data.automationShopTierB.clamp(0, 3);
    automationShopTierC = data.automationShopTierC.clamp(0, 3);
    automationShopTierD = data.automationShopTierD.clamp(0, 3);
    automationShopGradeHarvest = data.automationShopGradeHarvest.clamp(0, 99);
    automationShopGradeUpkeep = data.automationShopGradeUpkeep.clamp(0, 99);
    automationShopGradeWard = data.automationShopGradeWard.clamp(0, 99);
    automationShopGradeCommon = data.automationShopGradeCommon.clamp(0, 99);
    automationFuelEfficiencyTier = data.automationFuelEfficiencyTier.clamp(0, 9);
    gasolineCanFuel = data.gasolineCanFuel.clamp(0.0, maxGasolineCanFuel);
    migrateLegacyShopTiersToGrades();
    codex = CodexSnapshot.fromJson(data.codexSnapshotJson);

    disclosureTier = data.disclosureTier.clamp(0, 2);
    totalCargoLaunches = data.totalCargoLaunches;
    trueSequencePhase = data.trueSequencePhase.clamp(0, 4);
    pendingNarrativeMessages = List<String>.from(data.pendingNarrativeMessages);
    automationShopWillpowerAutoPay = data.automationShopWillpowerAutoPay;
    trueDialSalt = data.trueDialSalt;
    sentLifeScenarioBaseline = data.sentLifeScenarioBaseline;

    farmPrimaryRoleIndex = data.farmPrimaryRoleIndex.clamp(0, 3);
    farmSubModuleIndex = data.farmSubModuleIndex.clamp(0, 6);
    farmRoiMultiplier = data.farmRoiMultiplier;
    farmInterventionBonusCount = data.farmInterventionBonusCount;
    farmCostLife = data.farmCostLife;
    farmCostHistory = data.farmCostHistory;
    farmCostInorganic = data.farmCostInorganic;
    farmCostWillpower = data.farmCostWillpower;
    farmCostCurrency = data.farmCostCurrency;
    farmOutputCurrency = data.farmOutputCurrency;
    farmOutputMining = data.farmOutputMining;
    farmOutputCargoLife = data.farmOutputCargoLife;
    farmOutputCargoHistory = data.farmOutputCargoHistory;
    farmOutputCargoInorganic = data.farmOutputCargoInorganic;
    farmInterventionWindowSeconds = 0;
    farmDoubleCycleRemaining = 0;

    microPendingRogue = 0;
    microPendingFarm = 0;
    microPendingExplore = 0;
    microPendingSpecial = 0;
    automationAutoPickupSecondsRemaining = 0;
    pendingAutomationShopUnlockNotice = false;
    pendingTargetStarAutomationIntro = false;

    reconcileAutomationContractWithKitStage();

    debugPrint('--- GameRuntimeState loaded from SaveData. ---');
    printState();
  }

  // 属性確定状態のリセット（主にシナリオ1のステージ間で使用）
  // v8.3: automationContractC2／completedMacroRoutes／ステージ間微細ログ／
  // totalWillpowerConsumed／図鑑／lifetime* カウントはワールド方針の記録として保持し、ここでは消さない。
  void resetStageState() {
    currentStress = 0.0; // ステージ移動時にストレスをリセット
    willpowerSpentInStage = 0.0;
    destructionPointsInStage = 0;
    isCargoLaunched = false;

    saveGame();
    notifyListeners();
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
      currentStress: currentStress,
      maxIntegrity: maxIntegrity,
      currentIntegrity: currentIntegrity,
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
      currentMission: currentMission,
      scenarioCount: scenarioCount,
      dayCount: dayCount,
      dugAreas: dugAreas,
      carveStamps: carveStamps.map(
        (key, stamps) => MapEntry(
          key,
          stamps.map((s) => s.toJson()).toList(),
        ),
      ),
      placedFloors: placedFloors.map(
        (key, floors) => MapEntry(
          key,
          floors.map((f) => f.toJson()).toList(),
        ),
      ),
      digShapeTemplate: digShapeTemplate?.toJson(),
      hasShownCompassToday: hasShownCompassToday,
      buildingPlacements: Map<String, Map<String, double>>.from(buildingPlacements.map(
        (key, value) => MapEntry(key, Map<String, double>.from(value)),
      )),
      destructibleHealths: Map<String, int>.from(destructibleHealths),
      satisfiedNpcIds: satisfiedNpcIds.toList(),
      unlockedAchievements: unlockedAchievements.toList(),
      missionTrueLogs: Map<String, String>.from(missionTrueLogs),
      hpCalibrationScale: hpCalibrationScale,
      speedCalibrationScale: speedCalibrationScale,
      powerCalibrationScale: powerCalibrationScale,
      stressCalibrationScale: stressCalibrationScale,
      youngUncleDialogueStep: youngUncleDialogueStep,
      hasIdentifiedYoungUncle: hasIdentifiedYoungUncle,
      unlockedDiaryEntries: unlockedDiaryEntries,
      currentWillpower: currentWillpower,
      maxWillCoreValue: maxWillCoreValue,
      willpowerSpentInStage: willpowerSpentInStage,
      destructionPointsInStage: destructionPointsInStage,
      homePlanetHumanity: homePlanetHumanity,
      homePlanetEfficiency: homePlanetEfficiency,
      homePlanetRealism: homePlanetRealism,
      starAlertLevel: starAlertLevel,
      playerLifeCount: playerLifeCount,
      playerHistoryCount: playerHistoryCount,
      playerInorganicCount: playerInorganicCount,
      cargoLifeCount: cargoLifeCount,
      cargoHistoryCount: cargoHistoryCount,
      cargoInorganicCount: cargoInorganicCount,
      isCargoLaunched: isCargoLaunched,
      pendingToolboxReward: pendingToolboxReward,
      sentLifeResourceCount: sentLifeResourceCount,
      sentHistoryResourceCount: sentHistoryResourceCount,
      sentInorganicResourceCount: sentInorganicResourceCount,
      automationKitStage: automationKitStage,
      automationKitTotalRuntime: automationKitTotalRuntime,
      automationContractC2: automationContractC2,
      hasConnectedSupplyRoute: hasConnectedSupplyRoute,
      completedMacroRoutes: completedMacroRoutes.toList(),
      destroyMacroPathQualified: destroyMacroPathQualified,
      lifetimeEnemyKills: lifetimeEnemyKills,
      lifetimeLifeCargoAccumulated: lifetimeLifeCargoAccumulated,
      totalWillpowerConsumed: totalWillpowerConsumed,
      stageMicroLogEntries:
          stageMicroLogEntries.map((e) => e.toJson()).toList(),
      hasShownAutomationShopUnlockMessage:
          hasShownAutomationShopUnlockMessage,
      hasShownTargetStarAutomationIntro: hasShownTargetStarAutomationIntro,
      hasReceivedAutomationKitFromHunter: hasReceivedAutomationKitFromHunter,
      lastAlertHunterSpawnTier: lastAlertHunterSpawnTier,
      hasShownKitBagHint: hasShownKitBagHint,
      automationKitSceneId: automationKitSceneId,
      automationKitPositionX: automationKitPositionX,
      automationKitPositionY: automationKitPositionY,
      automationToolPlacementsJson:
          automationToolPlacements.map((e) => e.toJson()).toList(),
      automationUnlocksJson: automationUnlocks,
      automationUpgradeLevelsJson: automationUpgradeLevels,
      harvestStorageJson: harvestStorage.toJson(),
      hunterToolsGranted: hunterToolsGranted,
      automationUpgradeStageTier: automationUpgradeStageTier,
      upkeepToolFuel: upkeepToolFuel,
      harvestToolFuel: harvestToolFuel,
      wardToolFuel: wardToolFuel,
      harvestTankFuelRank: harvestTankFuelRank,
      upkeepTankFuelRank: upkeepTankFuelRank,
      wardTankFuelRank: wardTankFuelRank,
      automationAutoWillRefuel: automationAutoWillRefuel,
      automationShopTierA: automationShopTierA,
      automationShopTierB: automationShopTierB,
      automationShopTierC: automationShopTierC,
      automationShopTierD: automationShopTierD,
      automationShopGradeHarvest: automationShopGradeHarvest,
      automationShopGradeUpkeep: automationShopGradeUpkeep,
      automationShopGradeWard: automationShopGradeWard,
      automationShopGradeCommon: automationShopGradeCommon,
      automationFuelEfficiencyTier: automationFuelEfficiencyTier,
      gasolineCanFuel: gasolineCanFuel,
      codexSnapshotJson: codex.toJson(),
      disclosureTier: disclosureTier,
      totalCargoLaunches: totalCargoLaunches,
      trueSequencePhase: trueSequencePhase,
      pendingNarrativeMessages: pendingNarrativeMessages,
      automationShopWillpowerAutoPay: automationShopWillpowerAutoPay,
      trueDialSalt: trueDialSalt,
      sentLifeScenarioBaseline: sentLifeScenarioBaseline,
      farmPrimaryRoleIndex: farmPrimaryRoleIndex,
      farmSubModuleIndex: farmSubModuleIndex,
      farmRoiMultiplier: farmRoiMultiplier,
      farmInterventionBonusCount: farmInterventionBonusCount,
      farmCostLife: farmCostLife,
      farmCostHistory: farmCostHistory,
      farmCostInorganic: farmCostInorganic,
      farmCostWillpower: farmCostWillpower,
      farmCostCurrency: farmCostCurrency,
      farmOutputCurrency: farmOutputCurrency,
      farmOutputMining: farmOutputMining,
      farmOutputCargoLife: farmOutputCargoLife,
      farmOutputCargoHistory: farmOutputCargoHistory,
      farmOutputCargoInorganic: farmOutputCargoInorganic,
    );
  }

  String? pollNextNarrativeMessage() {
    if (pendingNarrativeMessages.isEmpty) return null;
    return pendingNarrativeMessages.removeAt(0);
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
