import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui' show Offset, Path, Picture, PictureRecorder, Rect;
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flame/particles.dart';

import '../../../../main.dart';
import '../collision/collision_family.dart';
import '../../item/item.dart';
import '../../game_stage/building/bed.dart';
import '../../../system/storage/game_runtime_state.dart';
import '../hitboxes/interact_hitbox.dart';
import '../../effect/residue_pickup.dart';
import '../../effect/residue_effect.dart';
import '../terrain/composite_terrain_field.dart';
import '../terrain/grid_terrain_field.dart';
import '../terrain/stamp_terrain_field.dart';
import '../physics/physics_body_queries.dart';
import '../terrain/terrain_field.dart';

class UnderGround extends PositionComponent
    with CollisionCallbacks, HasGameReference<MyGame>, HasCollisionFamily {
  @override
  CollisionFamily get collisionFamily => CollisionFamily.terrain;

  late final Sprite _underGroundSprite;
  late final Sprite _stoneSprite;
  static const double underGroundHeight = 1024.0;
  static const double digAreaSize = 64.0;
  final Set<Vector2> dugAreas = {};
  static const double penetrationThreshold = 2.0;
  final Set<double> _diggableEntranceXPositions = {}; // 採掘可能入口のX座標を保存
  
  late final Sprite _terminalSprite;
  late final Sprite _createPointSprite;
  late final Sprite _repairPointSprite;

  final Random _random = Random();
  final overlayPaint =
      Paint()
        ..color = const Color.fromARGB(180, 29, 29, 29)
        ..blendMode = BlendMode.overlay;
  late final Sprite _diggableEntranceSprite;
  final List<SpriteComponent> _diggableEntranceComponents = [];

  late AudioSource _digAudioSource;
  final String _digSoundFile = 'assets/audio/rock_break.mp3';

  final double _groundHeight;

  late CompositeTerrainField terrainField;
  late GridTerrainField _gridField;
  late StampTerrainField _stampField;

  late final Paint _tunnelFillPaint;

  Picture? _tunnelPicture;
  bool _tunnelPictureDirty = true;
  bool _carvePersistPending = false;
  double _persistCooldown = 0;
  static const double _persistIntervalSec = 2.5;

  List<CarveStamp> get carveStamps => _stampField.stamps;

  /// プレイヤー物理ヒットボックスに合わせたトンネル半径（掘削・通行・描画で共有）。
  double passageRadiusForPlayer() =>
      PhysicsBodyQueries.passageRadiusForBody(game.player);

  Set<double> get diggableEntranceXPositions => _diggableEntranceXPositions;

  UnderGround({required double groundHeight, double height = 1024.0})
    : _groundHeight = groundHeight,
      super(size: Vector2(MyGame.worldWidth, height));

  Future<void> addDiggableEntrances(List<double> xPositions) async {
    for (final x in xPositions) {
      _diggableEntranceXPositions.add(x);
    }

    // 採掘可能入口のスプライトをロード
    try {
      _diggableEntranceSprite = await Sprite.load('Crack.png');
      debugPrint('UnderGround: _diggableEntranceSprite loaded.');
    } catch (e) {
      debugPrint('Error loading Crack.png in addDiggableEntrances: $e');
      return; // スプライトロード失敗時は処理を中断
    }

    // 各採掘可能入口にスプライトコンポーネントを追加
    for (final xPos in diggableEntranceXPositions) {
      final Vector2 gridAlignedEntrance = getGridCellTopLeftWorld(
        Vector2(xPos, position.y),
      );

      // game.sceneManager.currentScene と groundComponent の null チェックを強化
      if (game.sceneManager.currentScene == null ||
          game.sceneManager.currentScene!.groundComponent == null) {
        debugPrint(
          'Warning: currentScene or groundComponent is null when adding entranceSpriteComponent. Skipping.',
        );
        continue; // 次のループへ
      }

      final entranceSpriteComponent = SpriteComponent(
          sprite: _diggableEntranceSprite,
          size: Vector2(
            UnderGround.digAreaSize,
            game
                .sceneManager
                .currentScene!
                .groundComponent!
                .size
                .y, // groundHeightの代わりにgroundComponentのサイズを使用
          ),
          position: Vector2(
            gridAlignedEntrance.x,
            game.initialGameCanvasSize.y,
          ),
        )
        ..priority =
            game.sceneManager.currentScene!.groundComponent!.priority + 1;
      _diggableEntranceComponents.add(entranceSpriteComponent);
      await game.sceneManager.currentScene!.add(entranceSpriteComponent);

      debugPrint(
        'entranceSpriteComponent added at: ${entranceSpriteComponent.position}',
      );
    }
  }

  // 指定されたワールド座標がどのグリッドセルに属するかを計算し、そのセルのワールド座標での左上隅を返すヘルパーメソッド
  Vector2 getGridCellTopLeftWorld(Vector2 worldPosition) {
    // worldPositionはプレイヤーの足元の座標などを想定
    // UnderGroundの左上隅を(0,0)とするローカル座標に変換
    final localX = worldPosition.x - position.x;
    final localY = worldPosition.y - position.y;

    // グリッド座標を計算
    final gridX = (localX / digAreaSize).floor();
    final gridY = (localY / digAreaSize).floor();

    // グリッドセルのローカル座標での左上隅を計算
    final cellLocalX = gridX * digAreaSize;
    final cellLocalY = gridY * digAreaSize;

    // グリッドセルのワールド座標での左上隅に変換
    return Vector2(cellLocalX + position.x, cellLocalY + position.y);
  }

  // 掘削済みのエリアのワールド座標での左上隅を返すメソッド
  Vector2? getDugAreaTopLeftWorld(Vector2 position) {
    final potentialDugAreaWorldPos = getGridCellTopLeftWorld(position);
    // dugAreasには、digAreaが追加された時点のワールド座標が保存されている
    if (dugAreas.contains(potentialDugAreaWorldPos)) {
      return potentialDugAreaWorldPos;
    }
    return null;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // GameRuntimeStateから既存の掘削エリアをロード
    final savedAreas = game.gameRuntimeState.dugAreas[game.sceneManager.currentSceneId];
    if (savedAreas != null) {
      for (final areaStr in savedAreas) {
        final coords = areaStr.split(',');
        if (coords.length == 2) {
          dugAreas.add(Vector2(double.parse(coords[0]), double.parse(coords[1])));
        }
      }
    }

    try {
      _underGroundSprite = await Sprite.load('concrete_ground.png');
      debugPrint('UnderGround: _underGroundSprite loaded.');
      _stoneSprite = await Sprite.load('stone.png');
      debugPrint('UnderGround: _stoneSprite loaded.');

      _terminalSprite = await Sprite.load('CITY_MEGA.png',
          srcPosition: Vector2(899, 85), srcSize: Vector2(26, 27));
      _createPointSprite = await Sprite.load('CITY_MEGA.png',
          srcPosition: Vector2(897, 66), srcSize: Vector2(30, 14));
      _repairPointSprite = await Sprite.load('CITY_MEGA.png',
          srcPosition: Vector2(768, 118), srcSize: Vector2(32, 26));

      // SoLoud の初期化状態を確認
      _digAudioSource = await game.audioManager.loadAndCacheSound(
        _digSoundFile,
      );
      debugPrint(
        "Dig sound '$_digSoundFile' loaded successfully using AudioManager.",
      );
    } catch (e) {
      debugPrint(
        'Error loading assets in UnderGround.onLoad: $e. Make sure sound and image files exist.',
      );
    }
    
    // 地下のY座標を地面のすぐ下に配置する
    position = Vector2(
      -MyGame.worldWidth,
      game.initialGameCanvasSize.y + _groundHeight,
    );
    _tunnelFillPaint = Paint()
      ..color = const Color(0xFF4A3F32)
      ..blendMode = BlendMode.srcOver
      ..isAntiAlias = true;

    _rebuildTerrainField();

    // 掘削・接触検知用（地形ブロックは [terrainField] が担当）
    add(
      RectangleHitbox(
        size: size,
        collisionType: CollisionType.passive,
        isSolid: false,
      ),
    );

    // 聖域のアンカー：「意味を忘れないためのメモ」を配置（未所持の場合）
    // プレイヤーが最初に入る可能性が高い X=-500 付近に配置
    _spawnAnchorItem();

    // 惑星調査日誌（アーカイブ端末）の配置
    _spawnDiaryTerminal();

    // 意志力補充（聖域）ポイントの配置
    _spawnReclaimPoints();

    // ベッドの配置
    _spawnBed();

    _playSoundEffectWithSoloud();
    _spawnDiggingParticles(Vector2.zero()); // 初期化用（表示されない）
  }

  void _spawnAnchorItem() {
    final state = game.gameRuntimeState;
    // すでに所持しているか、ワールドに存在する場合はスキップ
    if ((state.itemCounts['意味を忘れないためのメモ'] ?? 0) > 0) return;
    
    // 最初の掘削地点付近 (X=-500) に配置 (親コンポーネント UnderGround からの相対座標)
    // UnderGroundのXは -MyGame.worldWidth (-3000) なので、ワールド座標 -500 は相対座標で 2500
    final anchorItem = ItemFactory.createItemByName(
      '意味を忘れないためのメモ',
      Vector2(2500 + UnderGround.digAreaSize * 2, UnderGround.digAreaSize * 2),
    );
    if (anchorItem != null) {
      add(anchorItem); // game.world ではなく add(this) で子にする
      debugPrint('UnderGround: Anchor item spawned at ${anchorItem.position}');
    }

    // おじさんの手書きノート（アーカイブ）を配置
    final noteItem = ItemFactory.createItemByName(
      'おじさんの手書きノート',
      Vector2(2500 + UnderGround.digAreaSize * 4, UnderGround.digAreaSize * 2),
    );
    if (noteItem != null) {
      add(noteItem);
    }
  }

  void _spawnDiaryTerminal() {
    // X=-500 付近に配置 (親コンポーネント UnderGround からの相対座標)
    final terminalPos = Vector2(2500 + UnderGround.digAreaSize, UnderGround.digAreaSize * 3);
    
    // 端末の見た目（仮）
    // TODO: 画像挿入 (アーカイブ端末)
    final terminal = SpriteComponent(
      sprite: _terminalSprite,
      position: terminalPos,
      size: Vector2(48, 48),
    );
    add(terminal);

    terminal.add(InteractHitbox(
      position: Vector2.zero(),
      size: terminal.size,
      onInteract: () {
        _showDiaryMenu();
      },
      icon: Icons.menu_book,
    ));
  }

  void _spawnReclaimPoints() {
    // 創造ポイント (親コンポーネント UnderGround からの相対座標)
    final createPos = Vector2(2500 + UnderGround.digAreaSize * 3, UnderGround.digAreaSize * 3);
    // TODO: 画像挿入 (創造の祭壇)
    final createPoint = SpriteComponent(
      sprite: _createPointSprite, // 仮
      position: createPos,
      size: Vector2(48, 48),
    );
    add(createPoint);
    createPoint.add(InteractHitbox(
      position: Vector2.zero(),
      size: createPoint.size,
      onInteract: () => _showReclaimMenu('create'),
      icon: Icons.build,
    ));

    // 修復ポイント (親コンポーネント UnderGround からの相対座標)
    final repairPos = Vector2(2500 + UnderGround.digAreaSize * 8, UnderGround.digAreaSize * 3);
    // TODO: 画像挿入 (修復の机)
    final repairPoint = SpriteComponent(
      sprite: _repairPointSprite, // 仮
      position: repairPos,
      size: Vector2(48, 48),
    );
    add(repairPoint);
    repairPoint.add(InteractHitbox(
      position: Vector2.zero(),
      size: repairPoint.size,
      onInteract: () => _showReclaimMenu('repair'),
      icon: Icons.auto_fix_high,
    ));
  }

  void _spawnBed() {
    // X=-500 付近に配置 (親コンポーネント UnderGround からの相対座標)
    final bedPos = Vector2(2500 - UnderGround.digAreaSize * 2, UnderGround.digAreaSize * 2);
    final bed = Bed(
      position: bedPos,
      size: Vector2(64, 32),
    );
    add(bed);
  }

  void _showReclaimMenu(String type) {
    final state = game.gameRuntimeState;
    if (state.currentWillpower >= state.maxWillCoreValue) {
      game.windowManager.showDialog(["「意志の核は十分に満たされています。今はこれ以上の儀式は必要ありません。」"]);
      return;
    }

    if (type == 'create') {
      final hasMaterials = game.player.itemBag.getItemCount('石') >= 3 || game.player.itemBag.getItemCount('棒') >= 3;
      game.windowManager.showDialog(
        ["[創造の祭壇]", "「拾い集めたガラクタから、何か新しい形を生み出しますか？」", "（材料：石または棒 ×3）"],
        options: ["創造する", "やめる"],
        onSelect: (index) {
          if (index == 0) {
            if (hasMaterials) {
              if (game.player.itemBag.getItemCount('石') >= 3) {
                for (int i = 0; i < 3; i++) game.player.itemBag.removeItem('石');
              } else {
                for (int i = 0; i < 3; i++) game.player.itemBag.removeItem('棒');
              }
              state.reclaimWillpower(GameRuntimeState.willCoreUnit);
              game.windowManager.showDialog(["「……無心に手を動かし、形なきものに形を与えた。意志の核が静かに輝きを取り戻した。」"]);
            } else {
              game.windowManager.showDialog(["「材料が足りません。」"]);
            }
          }
        },
      );
    } else if (type == 'repair') {
      final hasRelic = game.player.itemBag.getItemCount('意味を忘れないためのメモ') > 0 || game.player.itemBag.getItemCount('おじさんの手書きノート') > 0;
      game.windowManager.showDialog(
        ["[修復の机]", "「父の遺品や、大切な思い出の品を丁寧に手入れしますか？」"],
        options: ["修復する", "やめる"],
        onSelect: (index) {
          if (index == 0) {
            if (hasRelic) {
              state.reclaimWillpower(GameRuntimeState.willCoreUnit * 1.5); // 旧30相当（max10スケール）
              game.windowManager.showDialog(["「……傷ついた品を磨き、かつての持ち主の想いに触れた。意志の核が温かな光を放ち始めた。」"]);
            } else {
              game.windowManager.showDialog(["「修復すべき思い出の品を持っていません。」"]);
            }
          }
        },
      );
    }
  }

  void _showDiaryMenu() {
    final List<String> options = ["日誌を読む", "日誌を復元する", "今日の出来事を記す", "閉じる"];
    
    game.windowManager.showDialog(
      ["[惑星調査日誌アーカイブ]", "「……未復元のデータが検出されました。復元には『破損したメモリ』が必要です。」"],
      options: options,
      onSelect: (index) {
        if (index == 0) {
          _showUnlockedEntries();
        } else if (index == 1) {
          _tryUnlockEntry();
        } else if (index == 2) {
          _memorizeAction();
        }
      },
    );
  }

  void _memorizeAction() {
    final state = game.gameRuntimeState;
    if (state.currentWillpower >= state.maxWillCoreValue) {
      game.windowManager.showDialog(["「……今はこれ以上、記すべき言葉が見当たりません。」"]);
      return;
    }

    game.windowManager.showDialog(
      ["[日誌への加筆]", "「今日起きた理不尽な出来事や、星への反抗心を日誌に書き留めますか？」"],
      options: ["記す", "やめる"],
      onSelect: (index) {
        if (index == 0) {
          state.reclaimWillpower(GameRuntimeState.willCoreUnit * 0.75); // 旧15相当
          game.windowManager.showDialog(["「……ペンを走らせ、自分の言葉で世界を定義し直した。意志の核が鋭い光を宿した。」"]);
        }
      },
    );
  }

  void _showUnlockedEntries() {
    final state = game.gameRuntimeState;
    if (state.unlockedDiaryEntries.isEmpty) {
      game.windowManager.showDialog(["「……閲覧可能な日誌はありません。」"]);
      return;
    }

    final List<String> options = [...state.unlockedDiaryEntries, "戻る"];
    game.windowManager.showDialog(
      ["「閲覧する項目を選択してください。」"],
      options: options,
      onSelect: (index) {
        if (index < state.unlockedDiaryEntries.length) {
          final entryId = state.unlockedDiaryEntries[index];
          final text = GameRuntimeState.uncleDiaryEntries[entryId] ?? "（データ破損）";
          game.windowManager.showDialog(["[$entryId]", text]);
        }
      },
    );
  }

  void _tryUnlockEntry() {
    final state = game.gameRuntimeState;
    final hasMemory = game.player.itemBag.getItemCount('破損したメモリ') > 0;

    if (!hasMemory) {
      game.windowManager.showDialog(["「……『破損したメモリ』が不足しています。」"]);
      return;
    }

    // まだ解放されていないエントリを探す
    final allEntries = GameRuntimeState.uncleDiaryEntries.keys.toList();
    final lockedEntries = allEntries.where((e) => !state.unlockedDiaryEntries.contains(e)).toList();

    if (lockedEntries.isEmpty) {
      game.windowManager.showDialog(["「……すべてのデータは既に復元されています。」"]);
      return;
    }

    final nextEntry = lockedEntries.first;
    game.player.itemBag.removeItem('破損したメモリ');
    state.unlockedDiaryEntries.add(nextEntry);

    ResiduePickup.emitCargo(
        game, ResiduePickup.worldEmitOrigin(game.player), history: 1);

    state.saveGame();

    game.windowManager.showDialog([
      "「……データの復元に成功しました。」",
      "「新規ログ：$nextEntry がアーカイブに追加されました。」"
    ]);
  }

  void addDugArea(Vector2 position) {
    // addDugAreaは引数としてプレイヤーのworld positionを受け取る
    // _getGridCellTopLeftWorldを使用して、そのworld positionが属するセルのworld positionを特定する
    final dugAreaWorldPos = getGridCellTopLeftWorld(position);

      if (!dugAreas.contains(dugAreaWorldPos)) {
      dugAreas.add(dugAreaWorldPos);

      // GameRuntimeStateに保存
      final sceneId = game.sceneManager.currentSceneId;
      game.gameRuntimeState.dugAreas[sceneId] ??= [];
      game.gameRuntimeState.dugAreas[sceneId]!.add('${dugAreaWorldPos.x},${dugAreaWorldPos.y}');

      carveAt(
        dugAreaWorldPos + Vector2.all(digAreaSize / 2),
        passageRadiusForPlayer(),
      );
      _playSoundEffectWithSoloud();
      _spawnDiggingParticles(dugAreaWorldPos); // dugAreaWorldPos を渡す

      // 無機資源の残滓（黒破片）を漏出させる
      ResidueEffect.spawnInorganic(game, dugAreaWorldPos, count: 5);

      // "希少な鉱石"アイテムを2~4個ランダムに生成
      final int stoneCount = _random.nextInt(3) + 2; // (0~2) + 2 = 2~4
      for (int i = 0; i < stoneCount; i++) {
        // 掘ったエリア内のランダムな位置に配置
        final randomOffset = Vector2(
          _random.nextDouble() * UnderGround.digAreaSize,
          _random.nextDouble() * UnderGround.digAreaSize,
        );
        final stoneItem = ItemFactory.createItemByName(
          '石',
          dugAreaWorldPos + randomOffset,
        );
        if (stoneItem != null) {
          game.world.add(stoneItem);
        }
      }
    }
  }

  Future<void> _playSoundEffectWithSoloud() async {
    if (!SoLoud.instance.isInitialized) {
      debugPrint(
        "Passed SoLoud.instance not ready or sound not loaded, skipping sound effect.",
      );
      return;
    }

    // ランダム速度
    final double playbackRate = 0.4 + _random.nextDouble() * 0.6;

    // 音声再生、ランダム速度の適用
    try {
      final SoundHandle handle = await SoLoud.instance.play(
        _digAudioSource,
        volume: 0.4,
      );
      SoLoud.instance.setRelativePlaySpeed(handle, playbackRate);
    } catch (e) {
      debugPrint("Error playing sound with passed SoLoud.instance: $e");
    }
  }

  void _spawnDiggingParticles(Vector2 worldPosition) {
    // ParticleSystemComponent をワールド座標に追加するため、
    // パーティクルの初期位置はその ParticleSystemComponent からの相対位置になります。
    // ParticleSystemComponent の position を掘削地点に設定します。
    final particleSystemPosition = Vector2(
      worldPosition.x + digAreaSize / 2,
      worldPosition.y + digAreaSize / 2,
    ); // 掘削エリアの中心に設定

    game.world.add(
      ParticleSystemComponent(
        position: particleSystemPosition, // ParticleSystemComponent の位置を設定
        priority: 110, // 他のコンポーネントより手前に描画
        particle: Particle.generate(
          count: _random.nextInt(8) + 6,
          lifespan: 0.6,
          generator: (i) {
            // 各パーティクルの初速をランダムに設定
            final initialSpeed =
                (Vector2.random(_random) - Vector2(0.5, 2)) * 100.0;
            // 重力のような加速度
            final acceleration = Vector2(0, 700);
            // パーティクルのベースとなる色をランダムに選択
            final baseColor = () {
              final random = _random.nextInt(4);
              switch (random) {
                case 0:
                  return Colors.brown[800]!;
                case 1:
                  return Colors.brown[900]!;
                case 2:
                  return Colors.grey[900]!;
                case 3:
                  return Colors.black;
                default:
                  return Colors.black54;
              }
            }();
            final spriteOverlayColor = baseColor.withAlpha(100);

            // 各パーティクル固有のサイズをここで決定
            final spriteSizeForParticle = Vector2.all(
              _random.nextDouble() * 15.0 + 15.0,
            );

            return AcceleratedParticle(
              speed: initialSpeed,
              acceleration: acceleration,
              position: Vector2(
                (_random.nextDouble() - 0.5) * digAreaSize,
                (_random.nextDouble() - 0.5) * digAreaSize,
              ),
              child: ComputedParticle(
                lifespan: 0.6,
                renderer: (canvas, particle) {
                  final paint =
                      Paint()
                        ..colorFilter = ColorFilter.mode(
                          spriteOverlayColor,
                          BlendMode.srcATop,
                        );

                  // generatorスコープで決定されたサイズを使用
                  _stoneSprite.render(
                    canvas,
                    size: spriteSizeForParticle, // ここでgeneratorスコープの変数を使う
                    overridePaint: paint,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  bool isDug(Vector2 position) => terrainField.isPassable(position);

  Rect get undergroundBounds => Rect.fromLTWH(position.x, position.y, size.x, size.y);

  List<CarveStamp> _stampsFromSave() {
    final sceneId = game.sceneManager.currentSceneId;
    final saved = game.gameRuntimeState.carveStamps[sceneId];
    if (saved == null) return [];
    return List<CarveStamp>.from(saved);
  }

  void _rebuildTerrainField() {
    final bounds = undergroundBounds;
    _gridField = GridTerrainField(
      undergroundBounds: bounds,
      dugCells: dugAreas,
      cellTopLeftOf: getGridCellTopLeftWorld,
    );
    final stamps = _stampsFromSave();
    if (stamps.isEmpty) {
      for (final cell in dugAreas) {
        stamps.add(
          CarveStamp(
            x: cell.x + digAreaSize / 2,
            y: cell.y + digAreaSize / 2,
            radius: digAreaSize * 0.55,
          ),
        );
      }
    }
    _stampField = StampTerrainField(
      undergroundBounds: bounds,
      stamps: stamps,
    );
    terrainField = CompositeTerrainField(
      undergroundBounds: bounds,
      grid: _gridField,
      stamps: _stampField,
    );
  }

  void _persistCarveStamps() {
    final sceneId = game.sceneManager.currentSceneId;
    game.gameRuntimeState.carveStamps[sceneId] =
        List<CarveStamp>.from(_stampField.stamps);
    _carvePersistPending = false;
    _persistCooldown = 0;
  }

  void _schedulePersist() {
    _carvePersistPending = true;
  }

  /// プレイヤー周囲をリアルタイムで1か所だけ掘る（グリッド単位ではない）。
  bool carveAt(Vector2 worldCenter, double radius) {
    if (!_stampField.carveCircleDeduped(worldCenter, radius)) {
      return false;
    }
    _tunnelPictureDirty = true;
    _schedulePersist();
    return true;
  }

  /// 足元から前方へカプセル状に掘削（見た目の二重円を避ける）。
  void carveCapsule(Vector2 worldA, Vector2 worldB, double radius) {
    final before = _stampField.stamps.length;
    terrainField.carveCapsule(worldA, worldB, radius);
    if (_stampField.stamps.length != before) {
      _tunnelPictureDirty = true;
      _schedulePersist();
    }
  }

  @Deprecated('Use carveAt or carveCapsule')
  void carvePassageSegment(Vector2 worldA, Vector2 worldB, double radius) {
    carveCapsule(worldA, worldB, radius);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_carvePersistPending) {
      _persistCooldown += dt;
      if (_persistCooldown >= _persistIntervalSec) {
        _persistCarveStamps();
      }
    }
  }

  @override
  void onRemove() {
    if (_carvePersistPending) {
      _persistCarveStamps();
    }
    super.onRemove();
  }

  // プレイヤーが採掘可能入口の近くにいるかを判定するメソッド
  bool isPlayerNearDiggableEntrance(Vector2 playerWorldPosition) {
    // プレイヤーのX座標が、登録された採掘可能入口のX座標のいずれかに近いかを確認
    final double playerX = playerWorldPosition.x;
    final double underGroundTopY = position.y; // UnderGroundのワールドY座標

    if (game.player.inUnderGround) {
      return false; // プレイヤーが地下にいる場合は判定しない
    }

    // プレイヤーの足元のY座標を使用
    final double playerFeetY = playerWorldPosition.y + game.player.size.y / 2;
    final double groundSurfaceY = game.initialGameCanvasSize.y;

    // プレイヤーの足元が地面と地下の境界付近にいるかを確認
    // groundSurfaceYは地面のY座標、underGroundTopYは地下のY座標
    // playerFeetYが地面の表面から、地下の最初のグリッドセルの下端まで（許容範囲）にいるか
    final bool isAtEntranceHeight =
        playerFeetY >= groundSurfaceY &&
        playerFeetY <= (underGroundTopY + digAreaSize);

    if (!isAtEntranceHeight) {
      return false;
    }

    for (final entranceX in _diggableEntranceXPositions) {
      // 採掘可能入口として登録されたX座標が属するグリッドセルの左上ワールド座標を特定
      final entranceGridTopLeftWorld = getGridCellTopLeftWorld(
        Vector2(entranceX, underGroundTopY),
      );

      // プレイヤーのX座標が、採掘可能入口のグリッドセルのX座標範囲内にあるか
      // (グリッドセルの左端 <= プレイヤーのX < グリッドセルの右端)
      if (playerX >= entranceGridTopLeftWorld.x &&
          playerX < (entranceGridTopLeftWorld.x + digAreaSize)) {
        return true;
      }
    }
    return false;
  }

  @Deprecated('地形ブロックは TerrainField + KinematicMovement が担当')
  void updateHitboxes() {}

  void resetPositions(Vector2 gameSize) {
    position.y = gameSize.y + _groundHeight;
  }

  @override
  void render(Canvas canvas) {
    // super.render(canvas); // RectangleComponentのデフォルト描画（白ボックス）を避けるためコメントアウト
    if (game.player.inUnderGround) {
      // 背景描画
      final repeatCount = (size.x / _underGroundSprite.srcSize.x).ceil();
      for (int i = 0; i < repeatCount; i++) {
        _underGroundSprite.render(
          canvas,
          position: Vector2(i * _underGroundSprite.srcSize.x, 0),
          size: Vector2(_underGroundSprite.srcSize.x + 1, size.y),
        );
      }

      // 真実のログアーカイブの存在を示唆（デバッグ用・将来的にコンポーネント化）
      if (game.gameRuntimeState.missionTrueLogs.isNotEmpty) {
        // 地下のどこかにアーカイブが存在するという演出
      }

      if (_tunnelPictureDirty || _tunnelPicture == null) {
        _rebuildTunnelPictureCache();
      }
      final pic = _tunnelPicture;
      if (pic != null) {
        canvas.drawPicture(pic);
      }
    }
  }

  void _rebuildTunnelPictureCache() {
    final recorder = PictureRecorder();
    final cacheCanvas = Canvas(recorder);

    for (final stamp in carveStamps) {
      final lx = stamp.x - position.x;
      final ly = stamp.y - position.y;
      if (lx + stamp.radius < 0 ||
          ly + stamp.radius < 0 ||
          lx - stamp.radius > size.x ||
          ly - stamp.radius > size.y) {
        continue;
      }
      final seed = stamp.x.hashCode ^ stamp.y.hashCode;
      cacheCanvas.drawPath(
        _jaggedCirclePath(Offset(lx, ly), stamp.radius, seed),
        _tunnelFillPaint,
      );
    }

    // 旧セーブのグリッドのみ（スタンプ未移行分）
    if (_stampField.stamps.isEmpty) {
      final gridRadius = passageRadiusForPlayer();
      for (final cell in dugAreas) {
        final lx = cell.x + digAreaSize / 2 - position.x;
        final ly = cell.y + digAreaSize / 2 - position.y;
        final seed = cell.x.hashCode ^ cell.y.hashCode;
        cacheCanvas.drawPath(
          _jaggedCirclePath(Offset(lx, ly), gridRadius, seed),
          _tunnelFillPaint,
        );
      }
    }

    _tunnelPicture = recorder.endRecording();
    _tunnelPictureDirty = false;
  }

  /// 見た目のみギザギザ（当たりは円スタンプのまま）。
  Path _jaggedCirclePath(Offset center, double radius, int seed) {
    const vertexCount = 10;
    final rand = Random(seed);
    final path = Path();
    for (var i = 0; i < vertexCount; i++) {
      final angle = 2 * pi * i / vertexCount;
      final wobble = radius * 0.08 * (rand.nextDouble() * 2 - 1);
      final r = radius + wobble;
      final x = center.dx + cos(angle) * r;
      final y = center.dy + sin(angle) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }
}
