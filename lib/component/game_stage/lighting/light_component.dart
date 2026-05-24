import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'light_emitter.dart';
import 'light_emitter_spec.dart';

/// シーンに置く固定ライト（[ConfiguredLightEmitter]）。
///
/// ```dart
/// add(LightComponent.fromSpec(
///   position: center - Vector2.all(radius),
///   size: Vector2.all(radius * 2),
///   spec: LightEmitterSpec.warmWhite(brightnessLevel: 400),
/// ));
/// ```
class LightComponent extends RectangleComponent with ConfiguredLightEmitter {
  @override
  final LightEmitterSpec lightEmitterSpec;

  LightComponent.fromSpec({
    required Vector2 position,
    required Vector2 size,
    required this.lightEmitterSpec,
  }) : super(
         position: position,
         size: size,
         paint: Paint()..color = Colors.transparent,
       );
}
