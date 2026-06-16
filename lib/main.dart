import 'package:flame/extensions.dart';
import 'component/common/collision/family_filtered_collision_detection.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/effects.dart';
import 'package:flutter_soloud/flutter_soloud.dart'; // SoLoudをインポート
import 'dart:developer' as dev; // logging用
import 'package:logging/logging.dart'; // logging用
import 'package:flutter/foundation.dart'; // kDebugMode用
import 'dart:math'; // Random用にインポート
import 'component/player.dart';
import 'UI/game_ui.dart';
import 'component/effect/dig_effect_component.dart';
import 'game_manager/time_service.dart';
import 'system/storage/save_data.dart';
import 'component/item/item.dart';
import 'UI/window_manager.dart';
import 'UI/windows/pause_window.dart';
import 'component/item/item_bag.dart';
import 'UI/windows/title_window.dart';
import 'UI/windows/loading_window.dart';
import 'scene/scene_manager.dart';
import 'scene/abstract_outdoor_scene.dart';
import 'component/common/physics/kinematic_movement.dart';
import 'component/common/underground/underground.dart';
import 'game_manager/audio_manager.dart';
import 'scene/game_scene.dart';
import 'component/camera_component.dart';
import 'game/world_scale.dart';
import 'system/storage/game_runtime_state.dart';
import 'system/farm_role_profile.dart';
import 'system/dig_shape_editor_controller.dart';
import 'system/placeable_placement_controller.dart';
import 'system/stage_clear_cinematic_controller.dart';
import 'UI/overlays/stage_clear_rive_overlay.dart';
import 'package:rive/rive.dart';
import 'dart:async';

// GameLoadState enum は削除 (FutureBuilderで状態管理するため)
// enum GameLoadState {
//   loadingSaveData, // セーブデータロード中
//   initializingGame, // ゲーム初期化中（セーブデータロード後）
//   loaded, // ゲームロード完了
// }

void main() async {
  Logger.root.level = kDebugMode ? Level.FINE : Level.INFO;
  Logger.root.onRecord.listen((record) {
    // dev.log はデバッガーでのみ表示されることがあるため、print も併用する
    final logMessage = '${record.time}: [${record.level.name}] ${record.loggerName}: ${record.message}';
    print(logMessage);
    if (record.error != null) print('Error: ${record.error}');
    if (record.stackTrace != null) print('StackTrace: ${record.stackTrace}');

    dev.log(
      record.message,
      time: record.time,
      level: record.level.value,
      name: record.loggerName,
      zone: record.zone,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  });

  WidgetsFlutterBinding.ensureInitialized();
  await RiveNative.init();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(MaterialApp(home: Scaffold(body: GameScreen())));
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final MyGame game;
  late final TimeService timeService;
  late final SaveDataManager saveDataManager;
  late final ItemBag itemBag;
  late final GameRuntimeState gameRuntimeState;
  SaveData? initialSaveData; // 初期セーブデータを保持
  late Future<void> _initializationFuture; // 初期化処理のFuture
  // MyGameのonLoadが完了したことを通知するためのCompleter
  final Completer<void> _gameReadyForSceneLoadCompleter =
      Completer<void>(); // リネーム
  bool _postGameLoadInitializationCalled =
      false; //_postGameLoadInitializationが呼ばれたかどうかを追跡
  bool _isWindowManagerInitialized = false; // WindowManagerが初期化されたかどうかのフラグ
  WindowManager? _windowManager; // null許容に変更
  WindowManager get windowManager => _windowManager!; // getterを追加
  final Completer<void> _windowManagerInitializedCompleter = Completer<void>();
  final StageClearCinematicController stageClearCinematic =
      StageClearCinematicController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timeService = TimeService();
    saveDataManager = SaveDataManager();
    gameRuntimeState = GameRuntimeState();

    _initializationFuture = _initializeGame();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isWindowManagerInitialized) {
      final Size screenSize = MediaQuery.of(context).size; // 画面サイズを取得
      debugPrint('GameScreen: didChangeDependencies called. screenSize: $screenSize');

      // 画面サイズが(0, 0)でないことを確認してから初期化
      if (screenSize.width > 0 && screenSize.height > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _windowManager = WindowManager(
            screenWidth: screenSize.width,
            screenHeight: screenSize.height,
          );
          debugPrint('GameScreen: WindowManager initialized with size: $screenSize');
          
          // ウィンドウの表示状態に応じてゲームを一時停止・再開
          _windowManager!.addListener(() {
            if (game.isTrainTravelTransitioning) return;
            if (_windowManager!.currentWindowType != GameWindowType.none &&
                _windowManager!.currentWindowType != GameWindowType.tweet) {
              game.pauseEngine();
            } else {
              game.resumeEngine();
            }
          });
          _isWindowManagerInitialized = true;
          _windowManagerInitializedCompleter.complete(); // ここで完了を通知
        });
      }
    }
  }

  // すべての初期化処理をまとめたメソッド
  Future<void> _initializeGame() async {
    // WindowManagerの初期化が完了するのを待機
    await _windowManagerInitializedCompleter.future; // これを追加

    // 1. セーブデータをロード
    final saveData = await saveDataManager.loadSaveData();
    initialSaveData = saveData;
    gameRuntimeState.loadFromSaveData(initialSaveData!); // GameRuntimeStateにロード

    // 2. ItemBagを初期化
    itemBag = ItemBag(
      gameRuntimeState: gameRuntimeState, // GameRuntimeStateから取得
    );

    // 3. MyGameインスタンスを作成し、onLoadの完了を待機
    // MyGameのonLoad完了時に呼ばれるコールバックを渡す
    if (!mounted) return;
    final screenSize = MediaQuery.of(context).size;

    game = MyGame(
      timeService: timeService,
      saveDataManager: saveDataManager,
      gameRuntimeState: gameRuntimeState,
      itemBag: itemBag,
      onGameLoaded: () {
        debugPrint('MyGame: onGameLoaded callback called.'); // コールバックの開始ログ
        _gameReadyForSceneLoadCompleter
            .complete(); // _myGameOnLoadCompleterをリネーム
        debugPrint(
          'MyGame: _gameReadyForSceneLoadCompleter completed.',
        ); // コールバックの完了ログ
      },
      screenSize: screenSize, // 取得したscreenSizeを渡す
      windowManager: windowManager, // ここで初期化されたwindowManagerを渡す
      stageClearCinematic: stageClearCinematic,
    );
    debugPrint(
      'MyGame: Instance created in _initializeGame.',
    ); // MyGameインスタンス作成ログ
    game.audioManager.initialize();
    debugPrint(
      'MyGame: AudioManager initialized in _initializeGame.',
    ); // AudioManager初期化ログ

    debugPrint('GameScreen: _initializeGame completed.');
  }

  // シーンロード処理を分離 (内容はそのまま)
  Future<void> _performSceneLoad({
    bool showCompass = false,
    ValueNotifier<String>? maskStatusNotifier,
  }) async {
    debugPrint('GameScreen: _performSceneLoad started. showCompass: $showCompass');
    // 保存されたシーンIDとプレイヤー位置を取得
    String savedSceneId =
        gameRuntimeState.currentSceneId; // GameRuntimeStateから取得

    // デバッグ用の初期ステージ上書き
    if (gameRuntimeState.debugInitialStage != null) {
      debugPrint('DEBUG: Overriding start scene from $savedSceneId to ${gameRuntimeState.debugInitialStage}');
      savedSceneId = gameRuntimeState.debugInitialStage!;
    }
    
    debugPrint('GameScreen: _performSceneLoad. savedSceneId: $savedSceneId');
    final Vector2 savedPlayerPosition = Vector2(
      gameRuntimeState.currentPlayerPositionX, // GameRuntimeStateから取得
      gameRuntimeState.currentPlayerPositionY, // GameRuntimeStateから取得
    );
    debugPrint('GameScreen: _performSceneLoad. savedPlayerPosition: $savedPlayerPosition');
    
    final String? savedBuildingType =
        gameRuntimeState.currentBuildingType; // GameRuntimeStateから取得
    final Vector2? savedBuildingOutdoorPosition =
        (gameRuntimeState.currentBuildingPositionX != null &&
                gameRuntimeState.currentBuildingPositionY != null)
            ? Vector2(
              gameRuntimeState.currentBuildingPositionX!,
              gameRuntimeState.currentBuildingPositionY!,
            )
            : null;

    // ここで初期シーンをロードする
    // 保存されたY座標がデフォルト値 (0.0) の場合はOutdoorSceneのデフォルト計算を適用
    final Vector2 playerInitialLoadPosition;
    // プレイヤーが最初高いところから始まるのを防ぐ
    if (savedPlayerPosition.y == 0.0) {
      debugPrint('GameScreen: savedPlayerPosition.y is 0.0, calculating default ground position.');
      playerInitialLoadPosition = Vector2(
        savedPlayerPosition.x,
        game.initialGameCanvasSize.y -
            (game.player.size.y / 2), // Anchor.center なので半分だけ浮かせれば足元が地面に付く
      );
    } else {
      playerInitialLoadPosition = savedPlayerPosition;
    }
    debugPrint('GameScreen: _performSceneLoad. playerInitialLoadPosition: $playerInitialLoadPosition');

    // 背景パララックスをリセットするためにテレポートを使用
    game.player.teleportTo(playerInitialLoadPosition);

    // シーンマネージャーに渡すデータマップを作成
    final Map<String, dynamic> sceneData = {};
    if (savedBuildingType != null) {
      sceneData['buildingTypeFromSave'] = savedBuildingType;
    }
    if (savedBuildingOutdoorPosition != null) {
      sceneData['buildingOutdoorPositionFromSave'] =
          savedBuildingOutdoorPosition;
    }

    await game.sceneManager.loadScene(
      savedSceneId,
      data: sceneData, // パンくずリスト情報をdataとして渡す
      initialPlayerPosition: playerInitialLoadPosition,
      onMaskBakeProgress: maskStatusNotifier == null
          ? null
          : (progress, message) {
              maskStatusNotifier.value = message;
            },
    );
    
    debugPrint('GameScreen: _performSceneLoad finished.');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    game.pauseEngine();
    game.removeAll(game.children);
    game.audioManager.dispose(); // AudioManagerのdisposeを追加
    _windowManager?.dispose(); // null安全に呼び出し
    itemBag.dispose();

    gameRuntimeState.currentPlayerPositionX = game.player.position.x;
    gameRuntimeState.currentPlayerPositionY = game.player.position.y;
    gameRuntimeState.saveGame();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('AppLifecycleState changed: $state');
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      // アプリがバックグラウンドに移行したとき
      // ゲームを一時停止
      if (_windowManager?.currentWindowType == GameWindowType.none) {
        // null安全にアクセス
        _windowManager?.showWindow(
          GameWindowType.pause,
          PauseWindow(
            windowManager: windowManager,
            itemBag: itemBag,
            game: game,
          ),
        );
      }
      // SoLoudの音声を一時停止
      game.audioManager.soloud.setGlobalVolume(0.0); // SoLoudの全音量を0に設定して一時停止
      debugPrint(
        'Game paused and SoLoud volume set to 0.0 due to app state: $state',
      );
      // ゲーム終了前に状態を保存
      gameRuntimeState.currentPlayerPositionX = game.player.position.x;
      gameRuntimeState.currentPlayerPositionY = game.player.position.y;
      gameRuntimeState.saveGame();
    } else if (state == AppLifecycleState.resumed) {
      // アプリがフォアグラウンドに戻ったとき
      // ゲームを再開
      if (_windowManager?.currentWindowType == GameWindowType.pause) {
        // null安全にアクセス
        _windowManager?.hideWindow();
      }
      // SoLoudの音声を再開
      game.audioManager.soloud.setGlobalVolume(1.0); // SoLoudの全音量を元に戻して再開
      debugPrint('Game resumed due to app state: $state');
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      'GameScreen: build called. Current initialization future status.',
    );
    final Size screenSize = MediaQuery.of(context).size; // 画面サイズを取得

    debugPrint(
      'GameScreen: Actual physical screen size (MediaQuery): $screenSize',
    ); // 実際の画面サイズをログ出力

    return FutureBuilder<void>(
      future: _initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            debugPrint(
              'Initialization error: ${snapshot.error}, Stack Trace: ${snapshot.stackTrace}',
            );
            // 初期化が失敗した場合はエラー画面を表示
            return Scaffold(
              body: Center(
                child: Text(
                  'Error loading game: ${snapshot.error}',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            );
          } else {
            // 初期化が完了したらゲーム画面を表示
            debugPrint('GameScreen: Initialization complete. Rendering game.');
            // _postGameLoadInitialization を一度だけ呼び出す
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_postGameLoadInitializationCalled) {
                _postGameLoadInitializationCalled = true;
                _postGameLoadInitialization();
              }
            });
            // gameがnullでないことを確認してからGameWidgetをレンダリング
            return Stack(
              children: [
                GameWidget(game: game), // UniqueKeyを削除
                GameUI(
                  screenSize: screenSize,
                  game: game,
                  timeService: timeService,
                  windowManager:
                      windowManager, // game.windowManagerではなくwindowManager
                  onPressedJumpButton: _onPressedJumpButton,
                ),
                AnimatedBuilder(
                  animation:
                      windowManager, // game.windowManagerではなくwindowManager
                  builder: (context, child) {
                    debugPrint(
                      'AnimatedBuilder rebuild. currentWindowContent is null: ${windowManager.currentWindowContent == null}',
                    );
                    debugPrint(
                      'AnimatedBuilder rebuild. currentWindowType: ${windowManager.currentWindowType}',
                    );
                    if (windowManager.currentWindowContent != null &&
                        windowManager.currentWindowType !=
                            GameWindowType.none) {
                      return Positioned.fill(
                        child: Center(
                          child: windowManager.currentWindowContent,
                        ),
                      );
                    } else {
                      return Container();
                    }
                  },
                ),
                ListenableBuilder(
                  listenable: stageClearCinematic,
                  builder: (context, _) {
                    return StageClearRiveOverlay(
                      controller: stageClearCinematic,
                    );
                  },
                ),
              ],
            );
          }
        } else {
          // ロード中はプログレスインジケーターを表示
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
      },
    );
  }

  void _onPressedJumpButton(bool isPressed) {
    if (isPressed) {
      game.player.jump();
    } else {
      game.player.stopJump();
    }
  }

  // MyGameがロードされた後に実行される追加の初期化処理
  Future<void> _postGameLoadInitialization() async {
    try {
      debugPrint('GameScreen: _postGameLoadInitialization started.');
      
      final maskStatus = ValueNotifier<String>('シーンを読み込み中…');
      _windowManager?.showWindow(
        GameWindowType.loading,
        LoadingWindow(
          windowManager: windowManager,
          message: 'LOADING...',
          statusMessage: maskStatus,
        ),
      );

      // MyGame.onLoadが完了するのを待機
      debugPrint('GameScreen: Waiting for _gameReadyForSceneLoadCompleter.future...');
      await _gameReadyForSceneLoadCompleter.future;
      debugPrint('GameScreen: _gameReadyForSceneLoadCompleter.future completed.');

      // MyGame.onGameResizeが最初に呼ばれたこと（initialGameCanvasSizeが設定されたこと）を待機
      debugPrint('GameScreen: Waiting for game.initialResizeDone...');
      await game.initialResizeDone;
      debugPrint('GameScreen: game.initialResizeDone completed. initialSize: ${game.initialGameCanvasSize}');

      // シーンをロード
      debugPrint('GameScreen: Calling _performSceneLoad...');
      await _performSceneLoad(maskStatusNotifier: maskStatus);
      debugPrint('GameScreen: _performSceneLoad completed.');

      // コンポーネントのマウントを確実にするために1フレーム待機
      await Future.delayed(Duration.zero);
      debugPrint('GameScreen: Post-mount delay completed.');

      final rs = game.gameRuntimeState;
      if (rs.currentWillpower <= 0 || rs.maxWillCoreValue <= 0) {
        debugPrint(
          'GameScreen: Will exhausted or zero cores on load — running gameOver.',
        );
        await game.gameOver();
      }

      // GameRuntimeStateに運搬中のアイテム情報があれば、プレイヤーに設定する
      if (game.gameRuntimeState.carriedItemName != null) {
        final itemName = game.gameRuntimeState.carriedItemName!;
        debugPrint('GameScreen: Restoring carried item: $itemName');
        final carriedItem = ItemFactory.createItemByName(
          itemName,
          Vector2.zero(),
        );

        if (carriedItem != null) {
          await game.player.startCarrying(carriedItem);
          debugPrint('GameScreen: Carried item restoration completed.');
        }
      }

      // GameRuntimeStateに装備アイテム情報があれば、プレイヤーに設定する
      if (game.gameRuntimeState.equippedItemName != null) {
        final itemName = game.gameRuntimeState.equippedItemName!;
        debugPrint('GameScreen: Restoring equipped item: $itemName');
        game.player.equipItem(itemName);
      }

      // ローディング画面を隠す
      _windowManager?.hideWindow();

      // ゲームロード後にタイトル画面を表示
      debugPrint('GameScreen: Showing TitleWindow.');
      _windowManager?.showWindow(
        GameWindowType.title,
        TitleWindow(
          windowManager: windowManager,
          onStart: () {
            // ゲーム開始時の処理
          },
        ),
      );
      debugPrint('GameScreen: TitleWindow show request completed.');
      debugPrint('GameScreen: _postGameLoadInitialization finished.');
    } catch (e, stack) {
      debugPrint('GameScreen: ERROR in _postGameLoadInitialization: $e');
      debugPrint('Stack Trace: $stack');
    }
  }
}

class MyGame extends FlameGame
    with
        HasKeyboardHandlerComponents,
        HasCollisionDetection,
        HasGameReference,
        TapCallbacks {
  static const double worldWidth = WorldScale.worldWidth;
  late final Player player; // late final に変更
  DigEffectComponent? digEffect;
  // TerrainManager? terrainManager; // 削除
  // EnemyManager? enemyManager; // 削除
  late RectangleComponent _fadeOverlay;
  late RectangleComponent _tessellationOverlay;

  // 新しいオーバーレイのgetterを追加
  double minZoomToFit = 1.0;
  double maxZoomToFit = 8.0;
  final TimeService timeService;
  final SaveDataManager saveDataManager;
  final GameRuntimeState gameRuntimeState; // GameRuntimeStateを追加
  late final WindowManager windowManager; // MyGame内で宣言をlate finalに変更
  final ItemBag itemBag;
  late final SceneManager sceneManager;
  late final AudioManager audioManager; // AudioManagerを追加
  late final CameraController cameraController; // CameraControllerを追加
  final PlaceablePlacementController placeablePlacement =
      PlaceablePlacementController();
  final DigShapeEditorController digShapeEditor = DigShapeEditorController();
  final StageClearCinematicController stageClearCinematic;
  final Random random = Random(); // Randomインスタンスを追加
  final Size screenSize;

  // 現在表示されているシーンを管理するためのプロパティ
  GameScene? _currentScene; // privateなフィールド
  GameScene? get currentScene => _currentScene; // getterとして公開

  bool isGameOver = false;
  bool isGameClear = false;

  /// 電車移動演出中は [WindowManager] による pause/resume を無効化する。
  bool isTrainTravelTransitioning = false;

  // カーゴ自動射出・自動進行のトリガー管理
  bool _autoLaunchTriggered = false;   // 23:50 自動射出済みフラグ
  bool _autoAdvanceTriggered = false;  // 0:00 自動進行済みフラグ

  final Function() onGameLoaded;

  Vector2 cameraTargetPosition = Vector2.zero();

  // カメラの追従オフセット
  Vector2 cameraFollowOffset = Vector2(0, -100); // Y座標を負の値にして上方向を向くように調整

  /// 通常プレイでは true。演出でプレイヤーをフレーム外に出してよいとき false。
  bool clampPlayerInCamera = true;

  // 初回ロード時のゲームキャンバスサイズを保存するプロパティ (gameresizeで更新される)
  Vector2? _initialGameCanvasSize;
  Vector2 get initialGameCanvasSize => _initialGameCanvasSize ?? size;

  // 初回リサイズが完了したことを通知するためのCompleter
  final Completer<void> _initialResizeCompleter = Completer();
  Future<void> get initialResizeDone => _initialResizeCompleter.future;

  MyGame({
    required this.timeService,
    required this.saveDataManager,
    required this.gameRuntimeState, // ここを修正
    required this.itemBag,
    required this.onGameLoaded,
    required this.screenSize,
    required this.windowManager,
    required this.stageClearCinematic,
  }) : super(camera: CameraComponent()) {
    debugPrint('MyGame: Constructor called.');
    stageClearCinematic.fadeFromBlack = _fadeFromBlack;
    stageClearCinematic.fadeToBlack = _fadeToBlack;
    // ここでSceneManagerを初期化
    sceneManager = SceneManager(game: this);
    // ここでAudioManagerを初期化
    audioManager = AudioManager(game: this, soloud: SoLoud.instance);
    // ここでCameraControllerを初期化
    cameraController = CameraController();
    // playerをここで初期化する
    player = Player(
      itemBag: itemBag,
      gameRuntimeState: gameRuntimeState, // GameRuntimeStateを渡す
      audioManager: audioManager,
    );
  }

  @override
  Future<void> onLoad() async {
    collisionDetection = FamilyFilteredCollisionDetection();
    // バッグ内テンプレート Item はツリー未接続のため HasGameReference が解決できない。
    // onUse / getDescription 等で game を参照する前に紐付ける。
    itemBag.bindToGame(this);
    placeablePlacement.bind(this);
    debugPrint('MyGame: onLoad started.'); // onLoad開始ログ
    // デバッグモード
    /* debugMode = true; */

    // playerはコンストラクタで初期化済み
    debugPrint('MyGame: Before adding player to world.');
    await world.add(player); // ! を削除
    debugPrint(
      'MyGame: Player added to world. player object: $player',
    );
    debugPrint('MyGame: After adding player to world.');
    debugPrint(
      'MyGame: player before DigEffectComponent init: not null',
    );

    // 掘るエフェクトを追加
    try {
      digEffect = DigEffectComponent(player: player); // ! を削除
    } catch (e) {
      debugPrint('Error initializing DigEffectComponent: $e'); // エラーログを追加
    }
    if (digEffect != null) {
      digEffect!.priority = 51;
      await world.add(digEffect!);
    } else {
      debugPrint(
        'DigEffectComponent was not initialized, skipping adding to world.',
      );
    }

    // カメラの初期化（CameraControllerに委譲）
    // CameraControllerをワールドに追加
    await world.add(cameraController); // cameraControllerを先にworldに追加
    cameraController.priority = 10; // プレイヤー更新のあとでアンカーを合わせる
    cameraController.initializeCamera(player);

    // シーンマネージャーをゲームワールドに追加
    await world.add(sceneManager); // これをplayerなどより後にする

    // 資源蓄積イベントの監視
    gameRuntimeState.cargoAccumulatedStream.listen((event) {
      _handleCargoAccumulated(event.$1, event.$2, event.$3);
    });

    // フェード用オーバーレイの初期化
    _fadeOverlay = RectangleComponent(
      size: canvasSize,
      paint: Paint()..color = Colors.black.withAlpha(0),
      priority: 1050,
    );
    await camera.viewport.add(_fadeOverlay);

    // テセレーション用オーバーレイの初期化
    _tessellationOverlay = RectangleComponent(
      size: canvasSize,
      paint: Paint()..color = Colors.black.withAlpha(0),
      priority: 1000,
    );
    await camera.viewport.add(_tessellationOverlay);

    // ゲームがロードされたことを通知
    debugPrint(
      'MyGame: Before onGameLoaded callback, game.player is: true',
    );
    onGameLoaded.call();
  }

  @override
  void onRemove() {
    // リソースのクリーンアップ
    digEffect = null;
    super.onRemove();
  }

  void _handleCargoAccumulated(int life, int history, int inorganic) {
    // 即時フィードバック（条件反射）の演出
    if (life > 0) {
      // 生命資源：心拍音、赤ランプ（仮で画面フラッシュ）
      // TODO: 画面端の赤ランプ脈動演出
    }
    if (history > 0) {
      // 歴史資源：音声ノイズ、青波紋
      // TODO: 青波紋エフェクト
    }
    if (inorganic > 0) {
      // 無機資源：重低音、金属振動
      // TODO: 重低音SE、画面揺れ
    }
  }

  @override
  void update(double dt) {
    final physicsDt = KinematicMovement.clampPhysicsDt(dt);
    super.update(physicsDt);

    audioManager.update(dt);
    timeService.update(dt);
    gameRuntimeState.tickFarmInterventionWindow(dt);

    // ステージ内の時間ベースカーゴ射出・自動進行ロジック
    if (sceneManager.currentScene is AbstractOutdoorScene) {
      final state = gameRuntimeState;
      final hour = timeService.hour;
      final minute = timeService.minute;
      final scene = sceneManager.currentScene as AbstractOutdoorScene;

      // 23:50 に未射出なら強制射出
      if (hour == 23 && minute >= 50 && !state.isCargoLaunched && !_autoLaunchTriggered) {
        _autoLaunchTriggered = true;
        state.launchCargo();
        scene.spawnTrain();
        debugPrint('MyGame: Auto cargo launch triggered at 23:50');
      }

      // 0:00（真夜中）に射出済みで未乗車なら少女のセリフ後に自動進行
      if (hour == 0 && minute == 0 && state.isCargoLaunched && !isGameClear && !_autoAdvanceTriggered) {
        _autoAdvanceTriggered = true;
        windowManager.showDialog(
          ['「……もう時間だ。行こう。」'],
          onClosed: () async {
            await stageClear();
          },
        );
        debugPrint('MyGame: Auto stage advance triggered at 0:00');
      }
    }

    // 掘りエフェクトの表示/非表示を制御
    if (player.isDigging) {
      if (digEffect != null && !digEffect!.isMounted && player.inUnderGround) {
        world.add(digEffect!);
      }
    } else {
      // 掘る動作が終わったらエフェクトを削除
      if (digEffect != null && digEffect!.isMounted) {
        world.remove(digEffect!);
      }
    }

    // プレイヤーが落ちたときは元に戻す
    if (sceneManager.currentScene
            is AbstractOutdoorScene && // シーンがAbstractOutdoorSceneであることを確認
        (sceneManager.currentScene as AbstractOutdoorScene).ground !=
            null && // groundがnullでないことを確認
        player.position.y >
            initialGameCanvasSize.y +
                (sceneManager.currentScene as AbstractOutdoorScene)
                    .ground!
                    .size
                    .y + // groundHeightを直接ground.size.yに置き換え
                UnderGround.underGroundHeight) {
      player.position.y = initialGameCanvasSize.y / 1.2;
    }
  }

  // 初期化時にも呼ばれる
  @override
  void onGameResize(Vector2 gameSize) {
    super.onGameResize(gameSize);
    debugPrint('MyGame: onGameResize called with size: $gameSize');
    
    // オーバーレイのサイズを更新
    if (gameSize.x > 0 && gameSize.y > 0) {
      if (isLoaded) {
        _fadeOverlay.size = gameSize;
        _tessellationOverlay.size = gameSize;
      }
    }

    if (_initialGameCanvasSize == null && gameSize.x > 0 && gameSize.y > 0) {
      _initialGameCanvasSize = gameSize;
      debugPrint('MyGame: initialGameCanvasSize set to: $gameSize');
      if (!_initialResizeCompleter.isCompleted) {
        _initialResizeCompleter.complete(); // 初回リサイズ完了を通知
      }
    }
    // 背景が画面全体を覆うために必要な最小ズームを計算
    if (game.size.y > 0) {
      minZoomToFit = canvasSize.y / (game.size.y * 1.5); // onGameResizeでは常に最新のcanvasSizeを使用
    }
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    super.onKeyEvent(event, keysPressed);

    // デバッグ用の時間調整機能
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        timeService.advanceMinutes(60);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        timeService.rewindMinutes(15);
        return KeyEventResult.handled;
      }
    }

    // プレイヤーの移動処理

    // 左右の矢印キーは時間調整に割り当てたため、ここではAとDキーのみを使用
    player.isMovingRight = keysPressed.contains(LogicalKeyboardKey.keyD);
    player.isMovingLeft = keysPressed.contains(LogicalKeyboardKey.keyA);

    // 下方向への移動
    player.isMovingDown =
        keysPressed.contains(LogicalKeyboardKey.arrowDown) ||
        keysPressed.contains(LogicalKeyboardKey.keyS);

    // しゃがみ処理
    player.iscrouching =
        (keysPressed.contains(LogicalKeyboardKey.arrowDown) ||
            keysPressed.contains(LogicalKeyboardKey.keyS)) &&
        !player.isDigging;

    // 上方向への移動
    player.isMovingUp =
        keysPressed.contains(LogicalKeyboardKey.arrowUp) ||
        keysPressed.contains(LogicalKeyboardKey.keyW);

    // 掘る（トグル機能）
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyP) {
      player.toggleDigging(true);
    } else if (event is KeyUpEvent &&
        event.logicalKey == LogicalKeyboardKey.keyP) {
      player.toggleDigging(false);
    }

    // ジャンプ処理
    if (keysPressed.contains(LogicalKeyboardKey.space) && player.isOnGround) {
      if (!GameUI.showJumpButton) {
        return KeyEventResult.ignored;
      }
      player.isOnGround = false;
      player.velocity.y = Player.jumpForce;
    }

    // ズーム機能
    if (event is KeyRepeatEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        cameraController.zoomIn();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        cameraController.zoomOut();
      }
    }

    // カメラの手動パン（ワールド座標）
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.home) {
        cameraController.nudgeManualPanWorld(Vector2(0, -100));
      } else if (event.logicalKey == LogicalKeyboardKey.end) {
        cameraController.nudgeManualPanWorld(Vector2(0, 100));
      }
    }

    return KeyEventResult.handled;
  }

  Future<void> gameOver() async {
    if (isGameOver) return;
    player.unbeatable = true;
    isGameOver = true;
    debugPrint('gameOver sequence started');

    // 1. 1秒かけて画面を暗くする (フェードイン)
    debugPrint('Starting 1s fade in');
    _fadeOverlay.add(
      OpacityEffect.to(
        1.0, // 暗転時の不透明度 (0.0 - 1.0)
        EffectController(duration: 1),
        onComplete: () {
          player.updateIntegrity(player.maxIntegrity);
          player.updateStress(0);
          player.addMaxStress(-10);
          timeService.advanceTime(90);
          // エフェクトが完了したら自身を削除
          _fadeOverlay.children.whereType<OpacityEffect>().forEach((effect) {
            effect.removeFromParent();
          });
        },
      ),
    );
    await Future.delayed(const Duration(seconds: 1)); // エフェクトの完了を待つ
    debugPrint('1s fade in complete');

    // 2. 2秒待機
    debugPrint('Starting 2s hold');
    await Future.delayed(const Duration(seconds: 1));
    debugPrint('2s hold complete');

    // 3. player.position をリセット
    player.teleportTo(Vector2(
      -50,
      initialGameCanvasSize.y - player.size.y / 2,
    ));
    debugPrint('Player position reset');

    // 4. 1秒かけて画面を元の明るさに戻す (フェードアウト)
    debugPrint('Starting 1s fade out');
    _fadeOverlay.add(
      OpacityEffect.to(
        0.0, // 透明に戻す
        EffectController(duration: 1.0),
      ),
    );
    await Future.delayed(const Duration(seconds: 1)); // エフェクトの完了を待つ
    debugPrint('1s fade out complete');
    debugPrint('gameOver sequence complete');

    gameRuntimeState.refillCurrentWillpowerAfterGameOver();

    gameRuntimeState.currentPlayerPositionX = player.position.x;
    gameRuntimeState.currentPlayerPositionY = player.position.y;
    gameRuntimeState.saveGame();
    isGameOver = false;
    player.unbeatable = false;
  }

  void _removeFadeEffects() {
    _fadeOverlay.children.whereType<OpacityEffect>().forEach((effect) {
      effect.removeFromParent();
    });
  }

  /// 画面を暗くする（黒オーバーレイ opacity → 1.0）
  Future<void> _fadeToBlack({double duration = 1.0}) async {
    _removeFadeEffects();
    final completer = Completer<void>();
    _fadeOverlay.add(
      OpacityEffect.to(
        1.0,
        EffectController(duration: duration),
        onComplete: () {
          if (!completer.isCompleted) completer.complete();
          _removeFadeEffects();
        },
      ),
    );
    await completer.future;
  }

  /// 画面を明るくする（黒オーバーレイ opacity → 0.0）
  Future<void> _fadeFromBlack({double duration = 1.0}) async {
    _removeFadeEffects();
    final completer = Completer<void>();
    _fadeOverlay.add(
      OpacityEffect.to(
        0.0,
        EffectController(duration: duration),
        onComplete: () {
          if (!completer.isCompleted) completer.complete();
          _removeFadeEffects();
        },
      ),
    );
    await completer.future;
  }

  /// 駅／電車ドアのインタラクトから次の屋外ステージへ進む（Rive 演出付き）。
  Future<void> advanceOutdoorStageViaTrain() async {
    final gs = gameRuntimeState;
    if (!gs.isCargoLaunched) {
      windowManager.showDialog([
        '電車はまだ来ない。',
        'カーゴを射出すれば、この電車が先へ運ぶ。',
      ]);
      return;
    }
    if (gs.blocksTrainForTrueSequenceGate) {
      if (gs.canStartTrueDeepSequence) {
        windowManager.showDialog(
          [
            '父のメモが、送還ログと噛み合った。',
            '通常路線は閉じる。深層へ降りるか？',
          ],
          options: ['深層へ', '戻る'],
          onSelect: (i) async {
            if (i != 0) return;
            gs.trueSequencePhase = 1;
            await gs.saveGame();
            GameUI.setInteractAction(null, null);
            final resetPos = Vector2(
              -100,
              initialGameCanvasSize.y - player.size.y / 2,
            );
            await playTrainTravelTransition(
              nextStageId: 'outdoor_true_corridor',
              resetPos: resetPos,
            );
          },
        );
        return;
      }
      windowManager.showDialog([
        '父のメモがそろった。',
        '通常進行では先へ進めない。',
      ]);
      return;
    }

    final currentSceneId = gs.currentOutdoorSceneId ?? 'outdoor_1';
    int currentStageNum;
    if (currentSceneId == 'outdoor_0') {
      currentStageNum = 0;
    } else if (currentSceneId == 'outdoor_philosophy') {
      currentStageNum = 5;
    } else if (currentSceneId == 'outdoor_despair' ||
        currentSceneId == 'outdoor_true' ||
        currentSceneId.startsWith('outdoor_true_')) {
      currentStageNum = 6;
    } else {
      currentStageNum = int.tryParse(currentSceneId.split('_').last) ?? 1;
    }

    const maxStageNum = 6;
    int nextStageNum = currentStageNum + 1;
    if (currentStageNum >= maxStageNum) {
      nextStageNum = 1;
    }

    String nextStageId = 'outdoor_$nextStageNum';
    if (nextStageNum == 5) {
      nextStageId = 'outdoor_philosophy';
    } else if (nextStageNum == 6) {
      nextStageId = gs.outdoorIdAfterPhilosophy();
    }
    if (nextStageNum == 1) {
      nextStageId = 'outdoor_1';
    }

    debugPrint('Train: Traveling to $nextStageId');

    gs.buildingPlacements.remove(nextStageId);
    if (gs.scenarioCount == 1) {
      gs.resetStageState();
    }

    GameUI.setInteractAction(null, null);
    final resetPos = Vector2(
      -100,
      initialGameCanvasSize.y - player.size.y / 2,
    );
    await playTrainTravelTransition(
      nextStageId: nextStageId,
      resetPos: resetPos,
    );
  }

  /// 暗転 → Rive（trainscene）→ 暗転 → シーンロード → 明転。
  /// 電車インタラクトなど、次ステージ ID が決まっている遷移で使う。
  Future<void> playTrainTravelTransition({
    required String nextStageId,
    required Vector2 resetPos,
    VoidCallback? onAfterFadeIn,
  }) async {
    player.unbeatable = true;
    isGameClear = true;
    isTrainTravelTransitioning = true;
    // pauseEngine は呼ばない。Flame の OpacityEffect（フェード）が update を要するため。
    try {
      debugPrint('TrainTravelTransition: starting cinematic → $nextStageId');

      await _fadeToBlack();
      await stageClearCinematic.playTrainScene();
      _fadeOverlay.opacity = 1.0;

      player.teleportTo(resetPos);
      cameraController.resetBackgroundParallax();
      cameraController.setOutdoorSceneCamera();

      await sceneManager.loadScene(
        nextStageId,
        initialPlayerPosition: resetPos,
      );

      await _fadeFromBlack();
      onAfterFadeIn?.call();
    } finally {
      isGameClear = false;
      player.unbeatable = false;
      isTrainTravelTransitioning = false;
      // ウィンドウ表示中なら pause のまま、なければ再開
      if (windowManager.currentWindowType != GameWindowType.none) {
        pauseEngine();
      } else {
        resumeEngine();
      }
    }
  }

  Future<void> stageClear() async {
    final state = gameRuntimeState;
    final currentSceneId = state.currentOutdoorSceneId ?? 'outdoor_1';
    final bool isFinalStage =
        currentSceneId == 'outdoor_despair' || currentSceneId == 'outdoor_true';

    // 現在の属性を確定し、クリア済みリストに追加
    // TODO: 属性確定ロジックの再設計

    String nextStageId = 'outdoor_0';
    if (!isFinalStage) {
      int nextNum = (currentSceneId == 'outdoor_philosophy')
          ? 6
          : (int.tryParse(currentSceneId.split('_').last) ?? 1) + 1;

      if (nextNum == 5) {
        nextStageId = 'outdoor_philosophy';
      } else if (nextNum == 6) {
        nextStageId = state.outdoorIdAfterPhilosophy();
      } else {
        nextStageId = 'outdoor_$nextNum';
      }
    } else {
      state.applyScenarioClearMacroRewardsForCompletedRun();
      state.sentLifeScenarioBaseline = state.sentLifeResourceCount;
      state.scenarioCount++;
      state.currentOutdoorSceneId = 'outdoor_0';
      nextStageId = 'outdoor_0';
      debugPrint(
        'Scenario completed. Starting Scenario ${state.scenarioCount} from Stage 0.',
      );
    }

    final resetPos = Vector2(
      -50,
      initialGameCanvasSize.y - player.size.y / 2,
    );

    debugPrint(
      'Transitioning to: $nextStageId (Scenario: ${state.scenarioCount})',
    );

    try {
      await playTrainTravelTransition(
        nextStageId: nextStageId,
        resetPos: resetPos,
        onAfterFadeIn: () {
          player.updateIntegrity(player.maxIntegrity);
          player.updateStress(0);
          timeService.advanceTime(420);
        },
      );
    } finally {
      _autoLaunchTriggered = false;
      _autoAdvanceTriggered = false;
    }
  }

  /*
  /// シナリオクリア時の報酬適用
  void _applyScenarioClearRewards(String attribute) {
    final state = gameRuntimeState;
    
    // 基本報酬
    state.currency += 500;
    state.miningPoints += 100;
    
    // 属性に応じたステータス永続強化
    switch (attribute) {
      case 'violence':
        state.hpBonus += 100.0; // 耐久力最大値アップ
        state.maxIntegrity += 100.0;
        break;
      case 'efficiency':
        state.movementSpeedBonus += 0.1; // 速度アップ
        break;
      case 'empathy':
        state.stressBonus += 20.0; // ストレス耐性アップ
        state.maxStress += 20.0;
        break;
      case 'philosophy':
        state.throwPowerBonus += 0.2; // 投擲・干渉力アップ
        break;
    }

    // 特定の周回数で能力解禁
    if (state.scenarioCount >= 2) {
      state.canRun = true; // ダッシュ解禁
    }

    debugPrint('Applied Rewards for $attribute clear. Scenario: ${state.scenarioCount}');
  }
  */

  @override
  void onDispose() {
    super.onDispose();
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
  }
}
