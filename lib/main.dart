import 'package:flame/extensions.dart';
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
import 'scene/scene_manager.dart';
import 'scene/abstract_outdoor_scene.dart';
import 'component/common/underground/underground.dart';
import 'game_manager/audio_manager.dart';
import 'game_manager/route_manager.dart';
import 'scene/game_scene.dart';
import 'component/camera_conponent.dart';
import 'component/game_stage/lighting/light_shader.dart';
import 'system/storage/game_runtime_state.dart';
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

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  await Future.delayed(const Duration(seconds: 2));
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
            if (_windowManager!.currentWindowType != GameWindowType.none) {
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
      screenSize: MediaQuery.of(context).size, // ここでscreenSizeを渡す
      windowManager: windowManager, // ここで初期化されたwindowManagerを渡す
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
  Future<void> _performSceneLoad() async {
    debugPrint('GameScreen: _performSceneLoad started.');
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

    gameRuntimeState.currentPlayerPositionX = game.player!.position.x;
    gameRuntimeState.currentPlayerPositionY = game.player!.position.y;
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
      gameRuntimeState.currentPlayerPositionX = game.player!.position.x;
      gameRuntimeState.currentPlayerPositionY = game.player!.position.y;
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
            if (game == null) {
              return const Scaffold(
                body: Center(
                  child: Text(
                    'Error: Game not initialized.',
                    style: TextStyle(color: Colors.red),
                  ),
                ), // 閉じ括弧を追加
              ); // エラーハンドリング
            }
            return Stack(
              children: [
                GameWidget(key: UniqueKey(), game: game!), // Keyを追加
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
                // その他のゲーム要素のウィジェットはここに追加していく。
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

  void _onPressedJumpButton() {
    if (game.player == null) return; // playerがnullの場合は何もしない
    if (game.player!.isOnGround) {
      game.player!.isOnGround = false;
      game.player!.velocity.y = Player.jumpForce;
    }
  }

  // MyGameがロードされた後に実行される追加の初期化処理
  Future<void> _postGameLoadInitialization() async {
    try {
      debugPrint('GameScreen: _postGameLoadInitialization started.');
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
      await _performSceneLoad();
      debugPrint('GameScreen: _performSceneLoad completed.');

      // GameRuntimeStateに運搬中のアイテム情報があれば、プレイヤーに設定する
      if (game.gameRuntimeState.carriedItemName != null) {
        debugPrint('GameScreen: Loading carried item: ${game.gameRuntimeState.carriedItemName}');
        final carriedItem = ItemFactory.createItemByName(
          game.gameRuntimeState.carriedItemName!,
          Vector2.zero(),
        );

        if (carriedItem != null) {
          await game.player.startCarrying(carriedItem);
          debugPrint('GameScreen: Carried item set to player.');
        }
      }

      // GameRuntimeStateに装備アイテム情報があれば、プレイヤーに設定する
      if (game.gameRuntimeState.equippedItemName != null) {
        debugPrint('GameScreen: Equipping item: ${game.gameRuntimeState.equippedItemName}');
        game.player.equipItem(game.gameRuntimeState.equippedItemName!);
      }

      // ゲームロード後にタイトル画面を表示
      debugPrint('GameScreen: Showing TitleWindow.');
      _windowManager?.showWindow(
        GameWindowType.title,
        TitleWindow(
          windowManager: windowManager,
          onStart: () {
            // ゲーム開始時に羅針盤メッセージを表示（クリア済みルートならスキップされる）
            final state = game.gameRuntimeState;
            final currentSceneId = state.currentOutdoorSceneId ?? 'outdoor_1';
            game.routeManager.showCompassMessage(currentSceneId);
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
  static const worldWidth = 3000.0;
  late final Player player; // late final に変更
  DigEffectComponent? digEffect;
  // TerrainManager? terrainManager; // 削除
  // EnemyManager? enemyManager; // 削除
  late RectangleComponent _fadeOverlay;
  late RectangleComponent _tessellationOverlay;
  // late RectangleComponent _globalLightingOverlay; // グローバルな明るさ調整オーバーレイ (削除)
  LightingOverlayComponent?
  _lightingOverlayComponent; // LightingOverlayComponentをnullableに変更

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
  late final RouteManager routeManager; // RouteManagerを追加
  late final CameraController cameraController; // CameraControllerを追加
  final Random random = Random(); // Randomインスタンスを追加
  final Size screenSize;

  // 現在表示されているシーンを管理するためのプロパティ
  GameScene? _currentScene; // privateなフィールド
  GameScene? get currentScene => _currentScene; // getterとして公開

  bool isGameOver = false;
  bool isGameClear = false;

  int _lastTrainSpawnMinute = -1;

  final Function() onGameLoaded;

  Vector2 cameraTargetPosition = Vector2.zero();

  // カメラの追従オフセット
  Vector2 cameraFollowOffset = Vector2(0, -100); // Y座標を負の値にして上方向を向くように調整

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
  }) : super(camera: CameraComponent()) {
    debugPrint('MyGame: Constructor called.');
    // ここでSceneManagerを初期化
    sceneManager = SceneManager(game: this);
    // ここでAudioManagerを初期化
    audioManager = AudioManager(game: this, soloud: SoLoud.instance);
    // ここでRouteManagerを初期化
    routeManager = RouteManager(this);
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
    debugPrint('MyGame: onLoad started.'); // onLoad開始ログ
    // デバッグモード
    /* debugMode = true; */

    // playerはコンストラクタで初期化済み
    debugPrint('MyGame: Before adding player to world.');
    await world.add(player); // ! を削除
    debugPrint(
      'MyGame: Player added to world. player is null: ${player == null}, player object: $player',
    );
    debugPrint('MyGame: After adding player to world.');
    debugPrint(
      'MyGame: player before DigEffectComponent init: ${player == null ? "null" : "not null"}',
    );

    // AudioManagerの初期化 (_GameScreenStateで初期化済みなのでここでは不要)
    // await audioManager.initialize(); // この行を削除またはコメントアウト

    // セーブデータロード
    await saveDataManager.loadSaveData();

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
    if (player != null) {
      cameraController.initializeCamera(player!);
    }

    // シーンマネージャーをゲームワールドに追加
    await world.add(sceneManager); // これをplayerなどより後にする

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

    // LightingOverlayComponent を初期化して追加
    _lightingOverlayComponent = LightingOverlayComponent(
      timeService: timeService,
    );
    await camera.viewport.add(
      _lightingOverlayComponent!,
    ); // camera.viewportに追加に戻す

    // ゲームがロードされたことを通知
    debugPrint(
      'MyGame: Before onGameLoaded callback, game.player is: ${player != null}',
    );
    onGameLoaded.call();
  }

  @override
  void onRemove() {
    // リソースのクリーンアップ
    digEffect = null;
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);

    audioManager.update(dt);
    timeService.update(dt);

    // 30分ごとに電車をスポーンさせる
    final currentMinute = timeService.minute;
    if ((currentMinute % 30 == 0) && currentMinute != _lastTrainSpawnMinute) {
      if (sceneManager.currentScene is AbstractOutdoorScene) {
        (sceneManager.currentScene as dynamic).spawnTrain();
        _lastTrainSpawnMinute = currentMinute;
      }
    }

    // playerが初期化されていない場合は更新をスキップ
    if (player == null) return;

    // 掘りエフェクトの表示/非表示を制御
    if (player!.isDigging) {
      if (digEffect != null && !digEffect!.isMounted && player!.inUnderGround) {
        world.add(digEffect!);
      }
    } else {
      // 掘る動作が終わったらエフェクトを削除
      if (digEffect != null && digEffect!.isMounted) {
        world.remove(digEffect!);
      }
    }

    // プレイヤーが落ちたときは元に戻す
    // playerがnullでないことを確認
    if (player != null &&
        sceneManager.currentScene
            is AbstractOutdoorScene && // シーンがAbstractOutdoorSceneであることを確認
        (sceneManager.currentScene as AbstractOutdoorScene).ground !=
            null && // groundがnullでないことを確認
        player!.position.y >
            initialGameCanvasSize.y +
                (sceneManager.currentScene as AbstractOutdoorScene)
                    .ground!
                    .size
                    .y + // groundHeightを直接ground.size.yに置き換え
                UnderGround.underGroundHeight) {
      player!.position.y = initialGameCanvasSize.y / 1.2;
    }
  }

  // 初期化時にも呼ばれる
  @override
  void onGameResize(Vector2 gameSize) {
    super.onGameResize(gameSize);
    debugPrint('MyGame: onGameResize called with size: $gameSize');
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
    player!.isMovingRight = keysPressed.contains(LogicalKeyboardKey.keyD);
    player!.isMovingLeft = keysPressed.contains(LogicalKeyboardKey.keyA);

    // 下方向への移動
    player!.isMovingDown =
        keysPressed.contains(LogicalKeyboardKey.arrowDown) ||
        keysPressed.contains(LogicalKeyboardKey.keyS);

    // しゃがみ処理
    player!.iscrouching =
        (keysPressed.contains(LogicalKeyboardKey.arrowDown) ||
            keysPressed.contains(LogicalKeyboardKey.keyS)) &&
        !player.isDigging;

    // 上方向への移動
    player!.isMovingUp =
        keysPressed.contains(LogicalKeyboardKey.arrowUp) ||
        keysPressed.contains(LogicalKeyboardKey.keyW);

    // 掘る（トグル機能）
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyP) {
      player!.toggleDigging(true);
    } else if (event is KeyUpEvent &&
        event.logicalKey == LogicalKeyboardKey.keyP) {
      player!.toggleDigging(false);
    }

    // ジャンプ処理
    if (keysPressed.contains(LogicalKeyboardKey.space) && player!.isOnGround) {
      if (!GameUI.showJumpButton) {
        return KeyEventResult.ignored;
      }
      player!.isOnGround = false;
      player!.velocity.y = Player.jumpForce;
    }

    // ズーム機能
    if (event is KeyRepeatEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        cameraController.zoomIn();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        cameraController.zoomOut();
      }
    }

    // カメラの位置を上に移動
    if (event.logicalKey == LogicalKeyboardKey.home) {
      camera.viewfinder.position += Vector2(0, -100);
    }
    // カメラの位置を下に移動
    if (event.logicalKey == LogicalKeyboardKey.end) {
      camera.viewfinder.position += Vector2(0, 100);
    }

    return KeyEventResult.handled;
  }

  Future<void> gameOver() async {
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
          player!.updateHp(player!.maxHp);
          player!.updateStress(0);
          player!.addMaxStress(-10);
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

    // 3. player.position をリセットし、100 money 失う
    player.teleportTo(Vector2(
      -50,
      initialGameCanvasSize.y - player.size.y / 2,
    ));
    player.updateMoneyPoints(-100);
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

    gameRuntimeState.currentPlayerPositionX = player.position.x;
    gameRuntimeState.currentPlayerPositionY = player.position.y;
    gameRuntimeState.saveGame();
    isGameOver = false;
    player.unbeatable = false;
  }

  Future<void> routeClear() async {
    player.unbeatable = true;
    isGameClear = true;

    // 1. 1秒かけて画面を暗くする (フェードイン)
    debugPrint('Starting 1s fade in');
    _fadeOverlay.add(
      OpacityEffect.to(
        1.0, // 暗転時の不透明度 (0.0 - 1.0)
        EffectController(duration: 1),
        onComplete: () {
          player!.updateHp(player!.maxHp);
          player!.updateStress(0);
          player!.addMaxStress(10);
          timeService.advanceTime(420);
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

    // 3. player.position をリセットし、200 money 取得
    player.teleportTo(Vector2(-50, initialGameCanvasSize.y - player.size.y / 2));
    player.updateMoneyPoints(200);
    debugPrint('Player position reset');

    // ルートクリア後は常に最初のステージ（outdoor_1）から始まるように戻す
    // ただし、その週の最大ステージ数（unlockedStageCount）までは電車で移動可能
    
    debugPrint('Switching to initial stage after route clear: outdoor_1');
    final resetPosition = Vector2(
        -500,
        initialGameCanvasSize.y - player.size.y / 2,
      );
    player.teleportTo(resetPosition);
    await sceneManager.loadScene(
      'outdoor_1',
      initialPlayerPosition: resetPosition,
    );

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
    debugPrint('gameClear sequence complete');

    gameRuntimeState.currentPlayerPositionX = player.position.x;
    gameRuntimeState.currentPlayerPositionY = player.position.y;
    gameRuntimeState.saveGame();
    isGameClear = false;
    player.unbeatable = false;
  }

  @override
  void onDispose() {
    super.onDispose();
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
  }
}
