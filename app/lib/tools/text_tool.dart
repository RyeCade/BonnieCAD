import '../domain/commands.dart';
import '../domain/text_label.dart';
import 'editor_controller.dart';
import 'tool.dart';

class TextTool extends EditorTool {
  @override
  ToolId get id => ToolId.text;

  @override
  String get name => 'Text';

  @override
  String get statusHint => 'Click to place a text label. T';

  @override
  void onActivate(EditorController c) {
    c.setStatus(statusHint);
  }

  @override
  void pointerDown(EditorController c, ToolPointerEvent e) {
    if (!e.isPrimary) return;
    final label = TextLabel(
      id: c.document.idGen.next('t'),
      origin: e.point,
      text: 'Label',
    );
    c.pushCommand(AddTextLabelCommand(label));
    c.selectedIds
      ..clear()
      ..add(label.id);
    c.setTool(ToolId.select);
    c.setStatus('Label placed — edit text in the side panel');
  }
}
