import 'package:anagaattara_hairitai/game/world_scale.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loopStageTileCount covers stage width', () {
    expect(WorldScale.loopStageTileCount(1599), 3);
    expect(WorldScale.loopStageTileCount(1983), 3);
    expect(
      WorldScale.loopStageTilePeriod(1599),
      closeTo(4797, 1e-9),
    );
    expect(
      WorldScale.loopStageTilePeriod(1983),
      closeTo(5949, 1e-9),
    );
  });

  test('loopStageTileTrueLeft right-aligns full tile to camera bound right', () {
    expect(
      WorldScale.loopStageTileTrueLeft(2, 1599),
      WorldScale.cameraBoundRightX - 1599,
    );
    expect(
      WorldScale.loopStageTileTrueLeft(2, 1599) + 1599,
      WorldScale.cameraBoundRightX,
    );
    expect(
      WorldScale.loopBackgroundTileOriginWorldX(1599),
      WorldScale.cameraBoundRightX - 4797,
    );
  });

  test('loopStageStripBounds spans stage tile count', () {
    final strip = WorldScale.loopStageStripBounds(1599);
    expect(strip.left, WorldScale.loopStageTileTrueLeft(0, 1599));
    expect(
      strip.width,
      closeTo(3 * 1599, 1e-9),
    );
  });

  test('loopStagePaintSlotRange without margin is stage tiles only', () {
    final range = WorldScale.loopStagePaintSlotRange(2);
    expect(range.start, 0);
    expect(range.endInclusive, 1);
  });

  test('loopStagePaintSlotRange with margin extends both sides', () {
    final range = WorldScale.loopStagePaintSlotRange(2, marginSlots: 1);
    expect(range.start, -1);
    expect(range.endInclusive, 2);
  });

  test('loopStageStripBounds includes margin slots', () {
    final strip = WorldScale.loopStageStripBounds(1599, marginSlots: 1);
    expect(strip.left, WorldScale.loopStageTileTrueLeft(-1, 1599));
    expect(strip.width, closeTo(5 * 1599, 1e-9));
  });

  test('renderPriorityForDepth follows depth-linear formula', () {
    expect(
      WorldScale.renderPriorityForDepth(WorldScale.skyDepthMeters),
      WorldScale.renderPriorityAtSky,
    );
    expect(
      WorldScale.renderPriorityForDepth(WorldScale.playfieldDepthMeters),
      WorldScale.renderPriorityAtPlayfield,
    );
    expect(
      WorldScale.renderPriorityForDepth(500),
      lessThan(WorldScale.renderPriorityForDepth(200)),
    );
    expect(
      WorldScale.renderPriorityForDepth(200),
      lessThan(WorldScale.renderPriorityForDepth(100)),
    );
    expect(
      WorldScale.renderPriorityForDepth(100),
      lessThan(WorldScale.outdoorGroundRenderPriority),
    );
    expect(
      WorldScale.outdoorBuildingRenderPriority,
      greaterThan(WorldScale.outdoorGroundRenderPriority),
    );
    expect(
      WorldScale.renderPriorityForDepth(WorldScale.nearForegroundDepthMeters),
      greaterThan(WorldScale.outdoorBuildingRenderPriority),
    );
  });
}
