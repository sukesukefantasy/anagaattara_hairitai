import 'package:flame/components.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_soloud/src/enums.dart'; // DistanceModel, AttenuationModel のために追加
import 'dart:math'; // Randomのために追加
import '../main.dart'; // MyGameをインポート

class ActiveSound {
  final SoundHandle handle;
  final Vector2 position;

  ActiveSound({required this.handle, required this.position});
}

class AudioManager {
  final MyGame game;
  final SoLoud soloud;
  final Map<String, AudioSource> _soundCache = {}; // 音源のキャッシュ
  final List<ActiveSound> _activeFootstepSounds = []; // 現在再生中の足音を追跡
  final List<ActiveSound> _activeCarSounds = []; // 現在再生中の車の音を追跡
  final Random _random = Random();

  // BGM関連の変数
  final List<String> _bgmFiles = [
    'bgms/ChillLofiR.mp3',
    'bgms/Friends.mp3',
    'bgms/lofihiphop.mp3',
    'bgms/A_cup_of_tea.mp3',
  ];
  String? _currentBgm;
  bool _isBgmPlaying = false;
  // BGM独立制御用の変数
  bool _wasInUnderGround = false;
  double _timeInUnderGround = 0.0;
  static const double _bgmPlayThresholdSeconds = 2.0;

  // 効果音関連の変数
  final Map<String, Future<AudioSource>> _loadingSounds = {};

  static const double maxDistance = 750.0; // 音が聞こえる最大距離
  static const int maxFootstepSounds = 5; // 同時に再生できる足音の最大数

  AudioManager({required this.game, required this.soloud});

  /// SoLoudとFlameAudioの初期化
  Future<void> initialize() async {
    if (!soloud.isInitialized) {
      //debugPrint('SoLoud初期化中...');
      await soloud.init(); // 3Dオーディオの設定は別途行う
      soloud.set3dSoundSpeed(maxDistance); // 3Dオーディオの最大距離を設定
      //debugPrint('SoLoud初期化完了。');
    }
    await FlameAudio.bgm.initialize();
    debugPrint('MyGame: FlameAudio initialized.');
  }

  /// 毎フレーム更新されるメソッド
  void update(double dt) {
    // アクティブな足音のリストをクリーンアップ
    _activeFootstepSounds.removeWhere(
      (s) => !soloud.getIsValidVoiceHandle(s.handle),
    );
    // アクティブな車の音のリストをクリーンアップ
    _activeCarSounds.removeWhere(
      (s) => !soloud.getIsValidVoiceHandle(s.handle),
    );

    // BGMの制御
    final bool currentlyInUnderGround = game.player!.inUnderGround;

    if (currentlyInUnderGround) {
      if (!_wasInUnderGround) {
        // 地下に入った瞬間
        _timeInUnderGround = 0.0;
      } else {
        // 地下継続中
        if (!_isBgmPlaying) {
          // BGMが再生されていない間だけ時間を加算
          _timeInUnderGround += dt;
        }
      }

      // 地下に入ってから閾値秒経過し、かつBGMがまだ再生されていなければ再生
      if (_timeInUnderGround >= _bgmPlayThresholdSeconds && !_isBgmPlaying) {
        playRandomBgm();
      }
    } else {
      // 地上にいる
      if (_isBgmPlaying) {
        stopBgm(); // 非同期停止メソッドを呼び出す
      }
      _timeInUnderGround = 0.0; // 地上に出たらリセット
    }
    _wasInUnderGround = currentlyInUnderGround;
  }

  /// 音源をロードしキャッシュする
  Future<AudioSource> loadAndCacheSound(String path) async {
    if (_soundCache.containsKey(path)) {
      return _soundCache[path]!;
    }

    // 同じパスのロードが既に進行中の場合は、そのFutureを返す
    if (_loadingSounds.containsKey(path)) {
      return _loadingSounds[path]!;
    }

    // パスが 'assets/audio/' で始まらない場合は補完する
    final String fullPath =
        path.startsWith('assets/audio/') ? path : 'assets/audio/' + path;

    final futureSound = soloud.loadAsset(fullPath);
    _loadingSounds[path] = futureSound;

    final sound = await futureSound;
    _soundCache[path] = sound;
    _loadingSounds.remove(path); // ロード完了後、Futureを削除
    return sound;
  }

  /// ボリュームを計算する（距離減衰）
  /// 3Dオーディオを使用するため、このメソッドは不要になるか、異なる目的で使われる
  /// double calculateVolume(Vector2 sourcePosition, Vector2 listenerPosition) {
  ///   final distance = (sourcePosition - listenerPosition).length;
  ///   if (distance > maxDistance) {
  ///     return 0.0; // 距離が最大距離を超えたら音量0
  ///   }
  ///   // 距離が近いほど音量が大きくなるように調整
  ///   return 1.0 - (distance / maxDistance);
  /// }

  /// リスナーの位置と向きを更新する
  void updateListener(Vector2 position, Vector2 at, Vector2 up) {
    soloud.set3dListenerParameters(
      position.x,
      position.y,
      0.0, // posX, posY, posZ
      at.x,
      at.y,
      0.0, // atX, atY, atZ
      up.x,
      up.y,
      1.0, // upX, upY, upZ
      0.0,
      0.0,
      0.0, // velocityX, velocityY, velocityZ
    );
  }

  // BGMを再生する
  Future<void> playRandomBgm() async {
    if (_bgmFiles.isEmpty) return;
    FlameAudio.bgm.stop();

    final random = Random();
    String newBgm;
    do {
      newBgm = _bgmFiles[random.nextInt(_bgmFiles.length)];
    } while (newBgm == _currentBgm &&
        _bgmFiles.length > 1); // 同じ曲が連続しないようにする（曲が2つ以上ある場合）

    _currentBgm = newBgm;

    FlameAudio.bgm.play(_currentBgm!, volume: 0.2);
    _isBgmPlaying = true;
    debugPrint("Playing BGM: $_currentBgm");
  }

  // BGMを停止する
  Future<void> stopBgm() async {
    if (_isBgmPlaying) {
      await FlameAudio.bgm.stop();
      _isBgmPlaying = false;
      debugPrint("BGM stopped.");
    }
  }

  /// 足音を再生する
  Future<SoundHandle?> playFootstepSound(Vector2 position) async {
    final soundPath = 'footsteps/step_cloth${_random.nextInt(4) + 1}.mp3';
    final AudioSource sound = await loadAndCacheSound(soundPath);

    // 既存の足音をクリーンアップ
    _activeFootstepSounds.removeWhere(
      (s) => !soloud.getIsValidVoiceHandle(s.handle),
    );

    // 最大数を超えている場合の置き換えロジック
    if (_activeFootstepSounds.length >= maxFootstepSounds) {
      // 最も遠い足音を見つけて停止し、置き換える
      double maxCurrentDistance = 0.0;
      ActiveSound? soundToReplace;
      for (var s in _activeFootstepSounds) {
        final currentDistance = (s.position - game.player!.position).length;
        if (currentDistance > maxCurrentDistance) {
          maxCurrentDistance = currentDistance;
          soundToReplace = s;
        }
      }
      if (soundToReplace != null) {
        soloud.stop(soundToReplace.handle);
        _activeFootstepSounds.remove(soundToReplace);
        //debugPrint('Stopped footstep sound ${soundToReplace.handle} at ${soundToReplace.position} for replacement');
      }
    }

    // 新しい足音を3Dで再生
    final SoundHandle handle = await soloud.play3d(
      sound,
      position.x,
      position.y,
      0.0, // posZ
      volume: 1.0,
      looping: false,
    );

    // 再生中の音源に対して3D減衰設定を適用
    soloud.set3dSourceAttenuation(
      handle,
      2,
      1.0,
    ); // 2: LINEAR_DISTANCE, 1.0: RolloffFactor
    soloud.set3dSourceMinMaxDistance(
      handle,
      0.0,
      maxDistance,
    ); // 最小距離0.0, 最大距離maxDistance

    _activeFootstepSounds.add(ActiveSound(handle: handle, position: position));
    //debugPrint('Playing footstep sound ${handle} at ${position}');
    return handle;
  }

  /// 車の音を再生する
  Future<SoundHandle?> playCarSound(Vector2 position) async {
    final soundPath = 'cars/car2.mp3';
    final AudioSource sound = await loadAndCacheSound(soundPath);

    // 既存の車の音源リストをクリーンアップ
    _activeCarSounds.removeWhere(
      (s) => !soloud.getIsValidVoiceHandle(s.handle),
    );

    // 新しい音源を3Dで再生
    final SoundHandle handle = await soloud.play3d(
      sound,
      position.x,
      position.y,
      0.0, // posZ velZ
      volume: 1.5, // 車の音は大きめに
      looping: true,
    );

    // 再生中の音源に対して3D減衰設定を適用
    soloud.set3dSourceAttenuation(
      handle,
      2,
      1.0,
    ); // 2: LINEAR_DISTANCE, 1.0: RolloffFactor
    soloud.set3dSourceMinMaxDistance(
      handle,
      0.0,
      maxDistance,
    ); // 最小距離0.0, 最大距離maxDistance

    _activeCarSounds.add(ActiveSound(handle: handle, position: position));
    //debugPrint('Playing car sound ${handle} at ${position}');
    return handle;
  }

  /// 効果音を再生する
  Future<SoundHandle?> playEffectSound(
    String path, {
    double volume = 1.0,
  }) async {
    final AudioSource sound = await loadAndCacheSound(path);
    final SoundHandle handle = await soloud.play(
      sound,
      volume: volume,
    ); // 3Dではないのでplayを使用
    //debugPrint('Playing effect sound ${handle}');
    return handle;
  }

  /// 特定の音源を停止する
  void stopSound(SoundHandle? handle) {
    // Future<void> と async を削除
    if (handle != null && soloud.getIsValidVoiceHandle(handle)) {
      soloud.stop(handle); // await を削除
      // _activeFootstepSounds からも削除
      _activeFootstepSounds.removeWhere((s) => s.handle == handle);
      // _activeCarSounds からも削除
      _activeCarSounds.removeWhere((s) => s.handle == handle);
      //debugPrint('Stopped sound ${handle}');
    }
  }

  void onRemove() {
    // リソースのクリーンアップ
    FlameAudio.bgm.dispose(); // BGM機能の破棄
    _isBgmPlaying = false;
    _currentBgm = null;
  }

  /// 全ての音源を停止する
  void dispose() {
    // Future<void> と async を削除
    for (final entry in _soundCache.entries) {
      soloud.disposeSource(entry.value);
    }
    // アクティブな足音を停止
    for (var s in _activeFootstepSounds) {
      if (soloud.getIsValidVoiceHandle(s.handle)) {
        // 有効なハンドルのみ停止
        soloud.stop(s.handle); // await を削除
        //debugPrint('Stopped active footstep sound ${s.handle}');
      }
    }
    _activeFootstepSounds.clear();
    // アクティブな車の音を停止
    for (var s in _activeCarSounds) {
      if (soloud.getIsValidVoiceHandle(s.handle)) {
        // 有効なハンドルのみ停止
        soloud.stop(s.handle); // await を削除
        //debugPrint('Stopped active car sound ${s.handle}');
      }
    }
    _activeCarSounds.clear();
    soloud.deinit(); // await を削除
    //debugPrint('AudioManager disposed.');
  }

  void onDispose() {
    dispose();
  }
}
