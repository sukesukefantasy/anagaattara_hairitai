import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math';
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

class UnderGround extends PositionComponent
    with CollisionCallbacks, HasGameReference<MyGame>, HasCollisionFamily {
  @override
  CollisionFamily get collisionFamily => CollisionFamily.terrain;

  late final Sprite _underGroundSprite;
  late final Sprite _dugAreaSprite;
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
      _dugAreaSprite = await Sprite.load('dugArea.png');
      debugPrint('UnderGround: _dugAreaSprite loaded.');
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
    updateHitboxes();

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
      
      // 哲学ルート進行：地下を掘る行為は好奇心・探求心とみなす
      // TODO: 属性進行ロジックの再設計
      
      //debugPrint('addDugArea: $position');
      updateHitboxes();
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

  bool isDug(Vector2 position) {
    // _getGridCellTopLeftWorldでグリッドセルのワールド座標を取得し、それがdugAreasに含まれるか確認
    return dugAreas.contains(getGridCellTopLeftWorld(position));
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

  void updateHitboxes() {
    // UnderGroundのヒットボックスのみを削除
    children.whereType<RectangleHitbox>().forEach((hitbox) {
      if (hitbox.parent == this) {
        hitbox.removeFromParent();
      }
    });

    // 掘削されていない部分のヒットボックスを再構築
    // dugAreasにないすべてのグリッドセルに対してヒットボックスを作成
    final allPossibleAreas = <Vector2>{};
    // ここでのループはUnderGroundのローカル座標系で考える
    for (double y = 0; y < size.y; y += digAreaSize) {
      for (double x = 0; x < size.x; x += digAreaSize) {
        // ローカル座標でグリッドセルの左上隅を計算
        final cellLocalX = x;
        final cellLocalY = y;
        // ワールド座標に変換
        final cellWorldX = cellLocalX + position.x;
        final cellWorldY = cellLocalY + position.y;
        allPossibleAreas.add(Vector2(cellWorldX, cellWorldY)); // ワールド座標で保存
      }
    }

    // 掘削されたエリアを考慮してヒットボックスを追加
    for (final areaWorldPos in allPossibleAreas) {
      if (!dugAreas.contains(areaWorldPos)) {
        // 掘削されていないエリアにのみヒットボックスを追加
        // ヒットボックスはUnderGroundの子供として追加されるため、positionはUnderGroundからの相対座標で指定
        final hitbox = RectangleHitbox(
          position: areaWorldPos - position, // ローカル座標に変換して追加
          size: Vector2.all(digAreaSize), // 掘削エリアのサイズに合わせる
          collisionType: CollisionType.passive,
          isSolid: true,
        );
        add(hitbox);
      }
    }
  }

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

      // 掘削済みエリアを描画
      for (final area in dugAreas) {
        // areaはワールド座標なので、UnderGroundのローカル座標に変換して描画
        final localX = area.x - position.x;
        final localY = area.y - position.y;

        if (localX >= 0 &&
            localX <= size.x &&
            localY >= 0 &&
            localY <= size.y) {
          _dugAreaSprite.render(
            canvas,
            position: Vector2(localX, localY), // ローカル座標で描画
            size: Vector2(digAreaSize, digAreaSize),
          );
        }
      }
    }
  }
}
