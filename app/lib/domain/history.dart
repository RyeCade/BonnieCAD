import 'command.dart';
import 'document.dart';

class History {
  History({this.limit = 100});

  final int limit;
  final List<Command> _undo = [];
  final List<Command> _redo = [];

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  List<Command> get undoStack => List.unmodifiable(_undo);
  List<Command> get redoStack => List.unmodifiable(_redo);

  void push(Command command, Document doc) {
    command.execute(doc);
    _undo.add(command);
    if (_undo.length > limit) {
      _undo.removeAt(0);
    }
    _redo.clear();
  }

  bool undo(Document doc) {
    if (_undo.isEmpty) return false;
    final c = _undo.removeLast();
    c.undo(doc);
    _redo.add(c);
    return true;
  }

  bool redo(Document doc) {
    if (_redo.isEmpty) return false;
    final c = _redo.removeLast();
    c.execute(doc);
    _undo.add(c);
    return true;
  }

  void clear() {
    _undo.clear();
    _redo.clear();
  }
}
