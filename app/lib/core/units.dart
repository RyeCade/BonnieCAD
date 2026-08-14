/// Canonical storage is inches. Display helpers convert at the UI boundary.
enum DisplayUnitSystem { imperial, metric }

class Units {
  Units._();

  static const inchesPerFoot = 12.0;
  static const mmPerInch = 25.4;
  static const cmPerInch = 2.54;
  static const mPerInch = 0.0254;

  static double inchesToMm(double inches) => inches * mmPerInch;
  static double mmToInches(double mm) => mm / mmPerInch;
  static double inchesToFeet(double inches) => inches / inchesPerFoot;

  /// Formats inches as feet-inches, e.g. `12' 6"` or `6"`.
  static String formatImperial(double inches, {int fractionDenom = 16}) {
    final sign = inches < 0 ? '-' : '';
    final abs = inches.abs();
    final feet = abs.floor() ~/ inchesPerFoot.toInt();
    var remInches = abs - feet * inchesPerFoot;

    final whole = remInches.floor();
    final frac = remInches - whole;
    final numer = (frac * fractionDenom).round();
    var adjWhole = whole;
    var adjNumer = numer;
    var adjFeet = feet;
    if (adjNumer >= fractionDenom) {
      adjNumer = 0;
      adjWhole += 1;
    }
    if (adjWhole >= 12) {
      adjWhole = 0;
      adjFeet += 1;
    }

    final inchPart = StringBuffer('$adjWhole');
    if (adjNumer > 0) {
      final g = _gcd(adjNumer, fractionDenom);
      inchPart.write(' ${adjNumer ~/ g}/${fractionDenom ~/ g}');
    }
    inchPart.write('"');

    if (adjFeet == 0) return '$sign$inchPart';
    return "$sign$adjFeet' $inchPart";
  }

  static String formatMetric(double inches, {int decimals = 1}) {
    final mm = inchesToMm(inches);
    if (mm.abs() >= 1000) {
      return '${(mm / 1000).toStringAsFixed(decimals)} m';
    }
    if (mm.abs() >= 10) {
      return '${(mm / 10).toStringAsFixed(decimals)} cm';
    }
    return '${mm.toStringAsFixed(decimals)} mm';
  }

  static String format(double inches, DisplayUnitSystem system) {
    return system == DisplayUnitSystem.imperial
        ? formatImperial(inches)
        : formatMetric(inches);
  }

  /// Parses user length input.
  /// Accepts: `12`, `12.5`, `12'`, `12'6"`, `12' 6"`, `6"`, `1.5m`, `150cm`, `1500mm`
  static double? parseLength(String input) {
    final s = input.trim().toLowerCase().replaceAll(',', '');
    if (s.isEmpty) return null;

    final metric = RegExp(r'^(-?\d+(?:\.\d+)?)\s*(mm|cm|m)$');
    final mm = metric.firstMatch(s);
    if (mm != null) {
      final v = double.parse(mm.group(1)!);
      return switch (mm.group(2)!) {
        'mm' => mmToInches(v),
        'cm' => mmToInches(v * 10),
        'm' => mmToInches(v * 1000),
        _ => null,
      };
    }

    final ftIn = RegExp(
      r"""^(-?\d+)\s*'\s*(?:(\d+(?:\.\d+)?)\s*(?:")?)?$""",
    );
    final fi = ftIn.firstMatch(s);
    if (fi != null) {
      final feet = double.parse(fi.group(1)!);
      final inches = fi.group(2) != null ? double.parse(fi.group(2)!) : 0.0;
      final sign = feet < 0 ? -1.0 : 1.0;
      return sign * (feet.abs() * inchesPerFoot + inches);
    }

    final inchOnly = RegExp(r'^(-?\d+(?:\.\d+)?)\s*"?$');
    final io = inchOnly.firstMatch(s);
    if (io != null) return double.parse(io.group(1)!);

    return null;
  }

  static int _gcd(int a, int b) {
    var x = a.abs();
    var y = b.abs();
    while (y != 0) {
      final t = y;
      y = x % y;
      x = t;
    }
    return x == 0 ? 1 : x;
  }
}
