import 'package:flame/components.dart';

import '../../common/ground/ground.dart';
import '../../common/underground/underground.dart';
import '../gamestage_component.dart';

/// 地面・地下・遠景ストリップの可視帯クリップ判定。
abstract final class LightingBandClip {
  LightingBandClip._();

  static bool usesStripClip(PositionComponent participant) =>
      usesVisibleBandClip(participant);

  /// 地面・地下・遠景: カメラ可視 X 帯だけ描画／環境暗化。
  static bool usesVisibleBandClip(PositionComponent participant) =>
      participant is Ground ||
      participant is UnderGround ||
      participant is GameStageComponent;

  /// [GameStageComponent.loop]: パララックスで local が size 外にも及ぶ → 帯を size.x にクランプしない。
  static bool usesLoopWorldWidthBand(PositionComponent participant) =>
      participant is GameStageComponent && participant.usesHorizontalLoop;
}
