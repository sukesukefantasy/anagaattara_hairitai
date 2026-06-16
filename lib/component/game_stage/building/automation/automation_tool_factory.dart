import 'package:flame/components.dart';

import '../../../../system/automation_tool_kind.dart';
import 'harvest_automation_tool.dart';
import 'upkeep_automation_tool.dart';
import 'ward_automation_tool.dart';
import 'automation_tool_base.dart';

AutomationToolBase createAutomationTool({
  required AutomationToolKind kind,
  required String instanceId,
  required Vector2 position,
}) {
  return switch (kind) {
    AutomationToolKind.harvest => HarvestAutomationTool(
        instanceId: instanceId,
        position: position,
      ),
    AutomationToolKind.upkeep => UpkeepAutomationTool(
        instanceId: instanceId,
        position: position,
      ),
    AutomationToolKind.ward => WardAutomationTool(
        instanceId: instanceId,
        position: position,
      ),
  };
}
