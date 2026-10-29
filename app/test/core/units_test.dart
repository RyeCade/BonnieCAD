import 'package:bon_cad/core/units.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Units.parseLength', () {
    test('bare number is decimal feet', () {
      expect(Units.parseLength('10'), 120);
      expect(Units.parseLength('10.5'), 126);
      expect(Units.parseLength('.25'), 3);
      expect(Units.parseLength('0.25'), 3);
      expect(Units.parseLength('12.5'), 150);
    });

    test('explicit inches', () {
      expect(Units.parseLength('6"'), 6);
      expect(Units.parseLength('12.5"'), 12.5);
    });

    test('feet inches', () {
      expect(Units.parseLength("12'"), 144);
      expect(Units.parseLength("12'6\""), 150);
      expect(Units.parseLength("10' 6\""), 126);
    });

    test('metric', () {
      expect(Units.parseLength('25.4mm')!, closeTo(1.0, 1e-9));
      expect(Units.parseLength('2.54cm')!, closeTo(1.0, 1e-9));
      expect(Units.parseLength('1m')!, closeTo(1000 / 25.4, 1e-6));
    });
  });

  group('Units.formatImperial', () {
    test('formats feet and inches', () {
      expect(Units.formatImperial(150), contains("12'"));
      expect(Units.formatImperial(6), contains('6'));
    });
  });
}
