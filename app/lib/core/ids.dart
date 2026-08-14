class IdGen {
  IdGen([this._counter = 0]);

  int _counter;

  String next([String prefix = 'e']) {
    _counter += 1;
    return '$prefix$_counter';
  }

  void ensureAtLeast(int value) {
    if (value > _counter) _counter = value;
  }

  int get counter => _counter;
}

int maxNumericSuffix(Iterable<String> ids) {
  var max = 0;
  final re = RegExp(r'(\d+)$');
  for (final id in ids) {
    final m = re.firstMatch(id);
    if (m != null) {
      final n = int.tryParse(m.group(1)!) ?? 0;
      if (n > max) max = n;
    }
  }
  return max;
}
