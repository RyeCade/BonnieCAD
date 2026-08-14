import 'document.dart';

abstract class Command {
  String get label;
  void execute(Document doc);
  void undo(Document doc);
}
