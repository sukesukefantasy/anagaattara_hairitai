import 'package:anagaattara_hairitai/game/pseudo3d_camera.dart';
import 'package:anagaattara_hairitai/game/world_scale.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const refZoom = 2.0;
  const focus = 500.0;
  const depthFar = 2000.0;
  const tileW = 1983.0;

  Pseudo3DCamera cam({
    double focusX = focus,
    double viewfinderZoom = refZoom,
  }) =>
      Pseudo3DCamera(
        focusWorldX: focusX,
        referenceZoom: refZoom,
        viewfinderZoom: viewfinderZoom,
      );

  test('depthScale at 2000m uses referenceZoom-only D', () {
    final p3d = cam();
    final dCam = WorldScale.cameraDistanceMeters(refZoom, refZoom);
    expect(p3d.depthScale(depthFar), closeTo(dCam / (dCam + depthFar), 1e-9));
  });

  test('depthZoomRenderFactor is 1 at referenceZoom', () {
    final p3d = cam(viewfinderZoom: refZoom);
    expect(p3d.depthZoomRenderFactor(depthFar), 1.0);
  });

  test('depthZoomRenderFactor lowers far layer when zoomed in', () {
    final p3d = cam(viewfinderZoom: refZoom * 2);
    expect(p3d.depthZoomRenderFactor(depthFar), lessThan(1.0));
    expect(p3d.depthZoomRenderFactor(0), 1.0);
  });

  test('projectedWorldX is invariant to viewfinder zoom changes', () {
    const wx = -1200.0;
    final p3d = cam();
    final projected = p3d.projectedWorldX(wx, depthFar);
    // depthScale no longer depends on viewfinder; same camera instance is enough.
    expect(p3d.projectedWorldX(wx, depthFar), projected);
    expect(
      cam(viewfinderZoom: refZoom * 2).projectedWorldX(wx, depthFar),
      projected,
    );
  });

  test('parallax: distant point moves slower than focus', () {
    final p3d0 = cam(focusX: 0);
    final p3d1 = cam(focusX: 100);
    final s = p3d0.depthScale(depthFar);
    const wx = -1000.0;
    final delta = p3d1.projectedWorldX(wx, depthFar) -
        p3d0.projectedWorldX(wx, depthFar);
    expect(delta, closeTo(100 * (1 - s), 1e-6));
    expect(delta.abs(), lessThan(100));
  });

  test('playfield depth: projected X equals true X', () {
    final p3d = cam();
    expect(
      p3d.projectedWorldX(-500, WorldScale.playfieldDepthMeters),
      -500,
    );
  });

  test('parallax is uniform: same delta for all world X when focus pans', () {
    final p3d0 = cam(focusX: 100);
    final p3d1 = cam(focusX: 200);
    const wxA = -1500.0;
    const wxB = -500.0;
    final deltaA =
        p3d1.projectedWorldX(wxA, depthFar) - p3d0.projectedWorldX(wxA, depthFar);
    final deltaB =
        p3d1.projectedWorldX(wxB, depthFar) - p3d0.projectedWorldX(wxB, depthFar);
    expect(deltaA, closeTo(deltaB, 1e-6));
  });

  test('full-width tiles overlap horizontally when s < 1', () {
    final origin = WorldScale.loopBackgroundTileOriginWorldX(tileW);
    final p3d = cam();
    final s = p3d.depthScale(depthFar);
    final overlap = p3d.projectedWorldX(origin, depthFar) +
        tileW -
        p3d.projectedWorldX(origin + tileW, depthFar);
    expect(overlap, closeTo(tileW * (1 - s), 1e-6));
    expect(overlap, greaterThan(0));
  });
}
