# Android ライティングクラッシュ調査メモ



## 症状（Galaxy SC-03K 等）



- 夜 + ランタン + `local_lights.frag` + 参加者ごと `saveLayer` で `ErrorOutOfDeviceMemory` / SIGSEGV
- batched 全画面 saveLayer では座標ずれによるタイル状点滅



## 現行方針（mobileCanvas）



| 項目 | 内容 |
|------|------|
| ティア | Android → `LightingQuality.mobileCanvas`（[`lighting_quality.dart`](../lib/component/game_stage/lighting/lighting_quality.dart)） |
| アーキテクチャ | **Emitter / Receiver**（[`light_emitter.dart`](../lib/component/game_stage/lighting/light_emitter.dart) / [`light_receiver.dart`](../lib/component/game_stage/lighting/light_receiver.dart)） |
| 太陽 | [`LightingWorld`](../lib/component/game_stage/lighting/lighting_world.dart) + per-Receiver `modulate`（マスク内のみ） |
| ランタン | `LanternItem` / `LightComponent` が Emitter、各スプライトが Receiver |
| マスク | ロード中 [`LightingMaskCatalog.bakeScene`](../lib/component/game_stage/lighting/lighting_mask_catalog.dart) + 動的スポーン時 [`bakeAndRegister`](../lib/component/game_stage/lighting/lighting_mask_catalog.dart)（[`LightReceiver.onMount`](../lib/component/game_stage/lighting/light_receiver.dart)）。白 RGB + α のみ |
| 描画 | [`LightReceiverRenderer`](../lib/component/game_stage/lighting/light_receiver_renderer.dart)（下記パイプライン。**saveLayer はマスク画素／長辺256 cap**） |
| viewport オーバーレイ | **使わない**（OOM 回避） |



## 描画パイプライン（Receiver・Canvas）



```text
translate(localBounds) + saveLayer(pixelW×pixelH)  // 論理3000pxでもバッファは最大256辺
  scale → 論理座標で描画
  drawContent → mask dstIn → sun modulate（マスク内）
  各 Emitter: lerp（本来色）+ warm（plus）、いずれも mask×radial weight
restore ×2
```

- **pixelW/H**: シルエットはベイク画像サイズ、Ground/空は `maxMaskLongEdge`(256) で cap
- 内側の saveLayer も同じスケール空間内 → 実メモリは cap 以下



- **暗部**: weight = 0 の画素は `C_dark` のまま
- **ランタン下**: マスク ∩ 光の radial 内だけ本来色 + 暖色（矩形塗りなし）
- **奥行き**: `lightingReceiverDepthFactor`（bbox 距離 m × punch）が weight に乗算
- **マスク未ベイク**（`full`）: 照明スキップ + デバッグ 1 回警告



## 検証チェックリスト



1. 夜 + ランタン移動 → クラッシュ / OOM なし
2. 遠景（`LightingParticipation.none`）はランタンで明るくならない（太陽暗化のみ）
3. プレイヤー PNG 透過穴から背景が勝手に明るくならない
4. 夜・ランタン未所持: Player / NPC がマスク形状どおり暗い
5. ランタン接近: 光の届く画素だけ本来色 + 軽い暖色（オレンジ矩形なし）
6. 光中心はランタン `worldCenter` 固定
7. ローディングでマスク生成完了（LoadingWindow に進捗表示）
8. 地下・地上
9. ログに `LightingMaskCatalog: bake failed` / `no silhouette mask` が出ないこと



## プレイヤー下半身が真っ黒に見える（マスクずれ）



### 症状



- 夜・Canvas 照明でプレイヤー**足元だけ**常に真っ黒（上半身はマスクどおり暗い）
- 歩行 2 コマで左右にブレることがある



### 原因（コード上の整理）



| 疑い | 結論 |
|------|------|
| Ground ベイクに下半身が巻き込まれている | **いいえ**。Player / Ground は別 Receiver・別 atlas |
| マスクが本体より上にずれ `dstIn` で足元 α=0 のまま punch | **有力**。その下に既描画の暗い Ground（priority 3）が見える |
| ベイク時 anchor 二重適用 | **修正済**：オフスクリーン bake では anchor 補正しない（Flame `render` は `transform.offset` 済みの左上原点）。`translate(-size×anchor)` はマスクを `(-25,-25)` にずらし切れ・無照明の原因になっていた |
| 先頭 `dstIn` で本体 punch | **廃止**：暗化はマスク上への上塗りのみ（[`light_receiver_renderer.dart`](../lib/component/game_stage/lighting/light_receiver_renderer.dart)） |
| ロード時アイドルだけベイクし歩行コマ index がずれる | **修正済**（Player の `lightingMaskAnimations` で全アニメをフラット atlas 化 + `resolveFrameIndex`） |
| 子 `PlayerCargoTerminal` で `localBounds` が 32×32 | **修正済**：ルート SAC は常に `(0,0,size)`。ベイクもルートのみ（子 cargo はマスクに含めない） |



### 歩行 2 コマで照明位置が 2 種類・右下切れ・暗化なし



- **原因**: `_localVisualBounds` が子スプライトだけ union → cargo 約 32×32。`saveLayer` がその矩形でクリップされ、50×50 本体の右・下が切れる。シート上でコマごとにキャラ位置が違うため、固定 32×32 窓では片方のコマだけマスクと偶然一致し「2 位置」に見えた。
- **修正**: [`lighting_mask_builder.dart`](../lib/component/game_stage/lighting/lighting_mask_builder.dart) の `_isRootSpriteReceiver` / `_paintRootSprite`
- **検証**: シーン再ロード後、歩行 2 コマとも同じ基準で暗化・ランタン・切れなし（夜推奨）



## プレイヤーに時間帯の暗化・ランタン復光が乗らない



- **原因**: [`_applySunDarkeningMasked`](../lib/component/game_stage/lighting/light_receiver_renderer.dart) が空の `saveLayer` 上で `Paint.blendMode = modulate` 描画 → 透明×係数色でレイヤーが空のまま `restore`（srcOver）され暗化ゼロ。ランタン lerp も暗化前提のため見えない。
- **修正**: `saveLayer(..., Paint()..blendMode = BlendMode.modulate)` + 内側は **srcOver** で係数色 → `dstIn` マスク → `restore` で本体に乗算暗化。
- **検証**: 夜・ランタンなしで Player が暗い／所持して接近でマスク内だけ本来色+暖色（昼は `ambientBrightness≈0` でランタン relight スキップは仕様）



## Ground strip の可視域カット（負荷対策）



| 項目 | 内容 |
|------|------|
| 問題 | 幅 ~4600 の Ground 全体に `saveLayer` + 全タイル `drawContent` + ランタン再描画 → 画面外まで処理 |
| 可視 | [`CameraViewportCoords.intersectVisibleLocalRect`](../lib/component/game_stage/lighting/camera_viewport_coords.dart) でカメラ可視 ∩ 地面 |
| 画面外 | 交差が空なら **描画も照明もスキップ** |
| ランタン | `activeRect ∩ 光プール` の帯だけ lerp/warm（[`_rectOverlapsLightPool`](../lib/component/game_stage/lighting/light_receiver_renderer.dart) で矩形交差） |
| 描画 | [`ground.dart`](../lib/component/common/ground/ground.dart) は可視タイル index のみ `render` |
| UnderGround | 同じ `usesStripClip` 経路で自動適用 |

**期待**: 水平タイル描画 **約 70〜90% 削減**、夜+ランタン時は **数倍軽量**（端末・ズーム依存）。



描画順: Ground → Player。Receiver パイプラインは `drawContent` → 太陽 modulate（マスク内）→ ランタン lerp/warm。



### 修正後の実機検証（フェーズ1）



1. シーン再ロード（`LightingMaskCatalog.bakeScene` が走ること）
2. 夜・ランタンなし: 足元に「穴あき黒」がない（シルエット全体が同じ暗さ）
3. ランタン接近: 上半身・下半身ともマスク内だけ本来色
4. 左右歩行: マスク index がコマと一致（ずれが原画タイル内オフセットのみならアート別件）



## 地面ランタン + 負荷（フェーズ2）



- [`Ground`](../lib/component/common/ground/ground.dart) は `LightReceiver` + `LightingParticipation.full` のまま（太陽暗化 + ランタン）
- saveLayer はマスク画素／長辺 256 cap のため、以前の「論理 3000×500 1 枚」OOM は起きにくい
- ただし **saveLayer 枚数・`drawContent` 再描画**は地面帯分だけ増える



### 実機検証（フェーズ2）



1. フェーズ1 OK のあと、夜 + ランタン所持 + 地上移動
2. 地面が光の届く範囲だけ自然に明るくなる（帯全体がオレンジ矩形にならない）
3. 5 分以上移動してもクラッシュ / `ErrorOutOfDeviceMemory` なし（SC-03K 等で logcat 確認）
4. logcat に `bake failed` / `no silhouette mask` が出ないこと



## 起動直後フラッシュ → 全面真っ黒（2025-05）



**症状**: 開始直後一瞬だけ背景が見え、その後空・遠景・地面が真っ黒のまま（昼でも）。



**主因**:

1. `maskFrame != null` かつ `sunDark ≈ 0` でも saveLayer 経路に入っていた（`bakeScene` 完了がトリガー）
2. strip の `paintRect.isEmpty` で `return`（描画ゼロ）+ `ground.render` 先頭の二重カリング
3. `bakeScene` の二重実行（`scene_manager` + `GameScreen`）と `onMount` 個別ベイク



**対応** (`light_receiver_renderer.dart`):

- `needsLightingPass` が false のときは saveLayer を使わず `drawContent` 直描画
- 照明が必要で strip 交差が空のときはコンポーネント全幅へフォールバック
- `bakeScene` は `scene_manager.loadScene` のみ。静的 Receiver は `deferMountBakeFor`

**地面・地下だけ非表示**（追記）:

- 4 隅 `intersectVisibleLocalRect` が細い strip で常に `Rect.zero` → 昼は renderer が return、`clipLocal` 空で saveLayer も中身なし
- `intersectVisibleLocalRectForStrip`（ワールド X 交差 + ローカル Y 全高）を Ground / `_stripVisibleLocalRect` で使用

**ランタン付近でズームインするとフリーズ**（追記）:

- relight の `outerLocal` に `* zoom` があり saveLayer が過大化 → zoom 除去
- pool 対角キャップは **mask 経路のみ**（strip/地面・地下・loop 遠景は pool 矩形＋楕円 clip のみ。キャップでズームイン時に光が消えるのを防ぐ）

**地面位置ずれ / ズームで赤枠**（追記）:

- 可視帯を Ground と Renderer が別計算 + Y 交差で strip が空 → 全幅フォールバックが悪化
- 対応: `visibleHorizontalBandLocal`（X のみ・`globalToLocal`）を唯一の帯、フォールバック・二重 clip 削除

**地面真っ黒 / 遠景に暗さなし**（追記）:

- 全面 strip saveLayer が中身空で真っ黒、遠景は saveLayer 内 modulate が効かず原色のまま
- **太陽暗化**: 親 canvas で `drawContent` → `_applySunDarkening` / `_applySunDarkeningMasked`（saveLayer 全面なし）
- **ランタン**: 太陽暗化のあと `_applyRelightPassesOnParent`（プール矩形 saveLayer のみ）

**昼も全面真っ黒・プレイヤー塗りつぶし**（追記）:

- `_visualOverlay`（priority 100・Paint 未指定=黒）が Android per-component 時も不透明のまま → `useCanvasLocalLights` では追加しない
- シルエット太陽暗化を「親 canvas の空 saveLayer」にしていた → **レイヤー内** `drawContent` → `_applySunDarkeningMasked` に復帰
- strip: 親 canvas `clip` + `drawContent` + `_applySunDarkening`（全面 saveLayer なし）
- relight: `_compositeOriginalLerpMasked` の `layerRect` を光プール矩形のみに（全面禁止）
- strip `paintRect` 空でも昼は全幅フォールバックで return しない
