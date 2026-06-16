import 'automation_tool_kind.dart';

/// 屋外に設置された自動化装置1台分。
class AutomationToolPlacement {
  final String instanceId;
  final AutomationToolKind kind;
  final String sceneId;
  final double x;
  final double y;

  const AutomationToolPlacement({
    required this.instanceId,
    required this.kind,
    required this.sceneId,
    required this.x,
    required this.y,
  });

  Map<String, dynamic> toJson() => {
        'instanceId': instanceId,
        'kind': kind.toJson(),
        'sceneId': sceneId,
        'x': x,
        'y': y,
      };

  factory AutomationToolPlacement.fromJson(Map<String, dynamic> json) {
    final kind = AutomationToolKind.fromJson(json['kind'] as String?) ??
        AutomationToolKind.upkeep;
    return AutomationToolPlacement(
      instanceId: json['instanceId'] as String? ?? '',
      kind: kind,
      sceneId: json['sceneId'] as String? ?? '',
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
    );
  }
}
