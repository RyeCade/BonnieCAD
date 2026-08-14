import 'package:bon_cad/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('BonnieCAD shell loads', (tester) async {
    await tester.pumpWidget(const BonnieCadApp());
    expect(find.textContaining('BonnieCAD'), findsWidgets);
    expect(find.textContaining('Wall'), findsWidgets);
  });
}
