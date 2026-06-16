import 'dart:async' as async;

import 'package:flutter/material.dart';
import 'package:flame/components.dart';

/// バッグ入手時に HUD へ流す1件分のイベント。
class ItemPickupFeedEvent {
  ItemPickupFeedEvent({
    required this.itemName,
    required this.displayName,
    required this.spritePath,
    required this.stackCount,
    required this.isFirstAcquisition,
    this.borderColor,
    this.flyStartGlobal,
    this.flyStartWorld,
  });

  final String itemName;
  final String displayName;
  final String spritePath;
  final int stackCount;
  final bool isFirstAcquisition;
  final Color? borderColor;
  final Offset? flyStartGlobal;
  /// ワールド拾得時の飛行演出起点（GameUI がスクリーン座標へ変換）。
  final Vector2? flyStartWorld;
}

/// 表示中の1行（同一アイテムのスタック更新用に可変）。
class ItemPickupFeedEntry {
  ItemPickupFeedEntry({
    required this.id,
    required this.itemName,
    required this.displayName,
    required this.spritePath,
    this.stackCount = 1,
    this.isFirstAcquisition = false,
    this.borderColor,
    this.flyStartGlobal,
    this.flyStartWorld,
  }) : shownAt = DateTime.now();

  final String id;
  final String itemName;
  String displayName;
  String spritePath;
  int stackCount;
  bool isFirstAcquisition;
  Color? borderColor;
  Offset? flyStartGlobal;
  Vector2? flyStartWorld;
  DateTime shownAt;
}

/// 入手ログのキューと表示リスト。最大5件・4秒表示。
class ItemPickupFeedController extends ChangeNotifier {
  static const int maxVisible = 5;
  static const Duration displayDuration = Duration(seconds: 4);
  static const Duration queueDelay = Duration(milliseconds: 300);

  final List<ItemPickupFeedEntry> _visible = [];
  final List<ItemPickupFeedEvent> _queue = [];
  async.Timer? _expireTimer;
  async.Timer? _queueTimer;
  int _idSeq = 0;
  bool _processingQueue = false;

  List<ItemPickupFeedEntry> get entries => List.unmodifiable(_visible);

  void enqueue(ItemPickupFeedEvent event) {
    final existingIdx =
        _visible.indexWhere((e) => e.itemName == event.itemName);
    if (existingIdx >= 0) {
      final entry = _visible[existingIdx];
      entry.stackCount = event.stackCount;
      entry.displayName = event.displayName;
      entry.spritePath = event.spritePath;
      entry.borderColor = event.borderColor ?? entry.borderColor;
      entry.flyStartGlobal = event.flyStartGlobal ?? entry.flyStartGlobal;
      entry.flyStartWorld = event.flyStartWorld ?? entry.flyStartWorld;
      entry.shownAt = DateTime.now();
      notifyListeners();
      _scheduleExpire();
      return;
    }

    _queue.add(event);
    _pumpQueue();
  }

  void _pumpQueue() {
    if (_processingQueue) return;
    if (_queue.isEmpty) return;
    if (_visible.length >= maxVisible) {
      _scheduleExpire();
      return;
    }

    _processingQueue = true;
    _queueTimer?.cancel();
    _queueTimer = async.Timer(queueDelay, () {
      _processingQueue = false;
      if (_queue.isEmpty || _visible.length >= maxVisible) return;
      final event = _queue.removeAt(0);
      _visible.insert(
        0,
        ItemPickupFeedEntry(
          id: 'pickup_${_idSeq++}',
          itemName: event.itemName,
          displayName: event.displayName,
          spritePath: event.spritePath,
          stackCount: event.stackCount,
          isFirstAcquisition: event.isFirstAcquisition,
          borderColor: event.borderColor,
          flyStartGlobal: event.flyStartGlobal,
          flyStartWorld: event.flyStartWorld,
        ),
      );
      notifyListeners();
      _scheduleExpire();
      _pumpQueue();
    });
  }

  void _scheduleExpire() {
    _expireTimer?.cancel();
    _expireTimer = async.Timer.periodic(const Duration(milliseconds: 200), (_) {
      final now = DateTime.now();
      final before = _visible.length;
      _visible.removeWhere(
        (e) => now.difference(e.shownAt) >= displayDuration,
      );
      if (_visible.length != before) {
        notifyListeners();
        _pumpQueue();
      }
      if (_visible.isEmpty && _queue.isEmpty) {
        _expireTimer?.cancel();
        _expireTimer = null;
      }
    });
  }

  @override
  void dispose() {
    _expireTimer?.cancel();
    _queueTimer?.cancel();
    super.dispose();
  }
}
