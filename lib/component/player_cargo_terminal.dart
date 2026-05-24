import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import '../main.dart';
import '../scene/abstract_outdoor_scene.dart';
import 'effect/residue_effect.dart';

/// プレイヤーに追従するカーゴ端末（表示サイズは cargo シートの [SpriteSheet.srcSize]）。
/// プレイヤーの子コンポーネントとして追加するため、ワールド座標変換は自動。
/// インタラクトで手動射出ダイアログを表示し、射出後はStationの電車を呼ぶ。
///
/// cargo.png: フレームは [SpriteSheet.srcSize]、35枚横一列 (1120×32 のとき srcSize=32×32)
/// - フレーム 1–26 : 待機アニメーション（端末が浮遊・待機、ループ）
/// - フレーム 27–35: 射出アニメーション（ロケット発光 → 飛翔、ワンショット）
class PlayerCargoTerminal extends SpriteAnimationComponent with HasGameReference<MyGame> {
  late SpriteSheet spriteSheet;
  
  /// 待機中アニメーション（ループ）
  late SpriteAnimation _idleAnimation;

  /// 射出中アニメーション（ワンショット → 待機に戻る）
  late SpriteAnimation _launchAnimation;

  bool _isLaunching = false;

  PlayerCargoTerminal()
      : super(
          size: Vector2.zero(),
          priority: 51,
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final cargoImage = await game.images.load('cargo.png');
    spriteSheet = SpriteSheet.fromColumnsAndRows(
      image: cargoImage,
      columns: 35,
      rows: 1,
    );
    size.setFrom(spriteSheet.srcSize);

    final frameSize = spriteSheet.srcSize;
    // フレーム 1–26: 待機（26フレーム、ループ）
    _idleAnimation = SpriteAnimation.fromFrameData(
      cargoImage,
      SpriteAnimationData.sequenced(
        amount: 26,
        stepTime: 0.1,
        textureSize: frameSize,
        texturePosition: Vector2.zero(),
        loop: true,
      ),
    );

    // フレーム 27–35: 射出（9フレーム、ワンショット）
    _launchAnimation = SpriteAnimation.fromFrameData(
      cargoImage,
      SpriteAnimationData.sequenced(
        amount: 9,
        stepTime: 0.07,
        textureSize: frameSize,
        texturePosition: Vector2(26 * frameSize.x, 0),
        loop: false,
      ),
    );

    animation = _idleAnimation;
  }

  @override
  void update(double dt) {
    super.update(dt);

    // 射出アニメーション終了後、待機アニメーションに戻す
    if (_isLaunching && animationTicker?.isLastFrame == true) {
      _isLaunching = false;
      animation = _idleAnimation;
    }

    // プレイヤーの向きに応じて後頭部後方に追従
    // ローカル座標の原点はプレイヤーの左上隅。プレイヤー中心は size.x/2, size.y/2
    final player = game.player;
    final rawFacing = player.facingDirection.x;
    // facingDirection.x が 0（初期アイドル）のときは右向きとして扱う
    final facingX = rawFacing == 0 ? 1.0 : rawFacing;
    final centerX = player.size.x / 2; // = 25
    final headY = player.size.y * 0;  // 頭の高さ（上から20%）
    // 進行方向の逆に 15px ずらしたプレイヤー中心付近
    position = Vector2(centerX - facingX * 20, headY);
  }

  /// UIボタンから呼び出す公開メソッド
  void showCargoDialog() {
    final state = game.gameRuntimeState;

    if (state.isCargoLaunched) {
      game.windowManager.showDialog([
        '【カーゴ端末】',
        '射出済みです。Stationで電車を待ってください。',
      ]);
      return;
    }

    final life = state.cargoLifeCount;
    final history = state.cargoHistoryCount;
    final inorganic = state.cargoInorganicCount;
    final total = state.totalCargoCount;

    if (total == 0) {
      game.windowManager.showDialog([
        '【カーゴ端末】',
        '残滓はまだ蓄積されていません。',
        'この星で行動するほど、何かが漏れ出てきます。',
      ]);
      return;
    }

    final pctLife = (life / total * 100).round();
    final pctHist = (history / total * 100).round();
    final pctIno = (inorganic / total * 100).round();

    game.windowManager.showDialog(
      [
        '【カーゴ端末 ─ 蓄積状況】',
        '生命残滓 : $life（全体の $pctLife%）',
        '歴史残滓 : $history（全体の $pctHist%）',
        '無機残滓 : $inorganic（全体の $pctIno%）',
        '今すぐ母星へ射出しますか？',
      ],
      options: ['射出する', 'まだ待つ'],
      onSelect: (index) {
        if (index == 0) {
          _launchCargo();
        }
      },
    );
  }

  void _launchCargo() {
    final state = game.gameRuntimeState;
    final batchLife = state.cargoLifeCount;
    final batchHist = state.cargoHistoryCount;
    final batchIno = state.cargoInorganicCount;
    final batchTotal = state.totalCargoCount;
    final batchPctLife = batchTotal > 0 ? (batchLife / batchTotal * 100).round() : 0;
    final batchPctHist = batchTotal > 0 ? (batchHist / batchTotal * 100).round() : 0;
    final batchPctIno = batchTotal > 0 ? (batchIno / batchTotal * 100).round() : 0;

    state.launchCargo(); // isCargoLaunched = true もここで設定される

    // 射出アニメーション再生
    _isLaunching = true;
    animation = _launchAnimation;
    animationTicker?.reset();

    // 残滓エフェクト（全種類を爆発的に漏出させる）
    ResidueEffect.spawnLife(game, game.player.absolutePosition.clone(), count: 12);
    ResidueEffect.spawnHistory(game, game.player.absolutePosition.clone(), count: 6);
    ResidueEffect.spawnInorganic(game, game.player.absolutePosition.clone(), count: 12);

    // 射出後に電車を呼ぶ
    final scene = game.sceneManager.currentScene;
    if (scene is AbstractOutdoorScene) {
      scene.spawnTrain();
    }

    // フィードバックダイアログ（資源傾向によって変化）
    final sentLife = state.sentLifeResourceCount;
    final sentHistory = state.sentHistoryResourceCount;
    final sentInorganic = state.sentInorganicResourceCount;

    List<String> messages;
    if (sentLife > sentHistory && sentLife > sentInorganic) {
      messages = [
        '【射出完了】',
        '今回の内訳: 生命 $batchPctLife% / 歴史 $batchPctHist% / 無機 $batchPctIno%（計$batchTotal）',
        '残滓は母星へ向かった。',
        '……向こうの報告が来た。みんなシャキッとしてる、と。',
        'でも同じ時間に、同じ方向を向いて、一言も喋らずに立ってるそうだ。',
        '——Stationで電車を待て。',
      ];
    } else if (sentHistory > sentLife && sentHistory > sentInorganic) {
      messages = [
        '【射出完了】',
        '今回の内訳: 生命 $batchPctLife% / 歴史 $batchPctHist% / 無機 $batchPctIno%（計$batchTotal）',
        '残滓は母星へ向かった。',
        '……人々が互いの名前を呼び合い始めている、と。',
        '回復は遅い。でも、あれが俺たちの知っている母星の姿だ。',
        '——Stationで電車を待て。',
      ];
    } else {
      messages = [
        '【射出完了】',
        '今回の内訳: 生命 $batchPctLife% / 歴史 $batchPctHist% / 無機 $batchPctIno%（計$batchTotal）',
        '残滓は母星へ向かった。',
        '……現状維持には十分だ。でも人々の眼が、また少し死んでいく。',
        '——Stationで電車を待て。',
      ];
    }

    if (state.disclosureTier >= 1) {
      messages.add(
        '〔開示：${state.disclosureTier >= 2 ? "終盤" : "中途"}〕通信にノイズが混じり始めた。',
      );
    }

    game.windowManager.showDialog(messages);
  }
}
