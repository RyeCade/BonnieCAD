import 'dart:math' as math;

class Vec2 {
  const Vec2(this.x, this.y);

  final double x;
  final double y;

  static const zero = Vec2(0, 0);

  Vec2 operator +(Vec2 o) => Vec2(x + o.x, y + o.y);
  Vec2 operator -(Vec2 o) => Vec2(x - o.x, y - o.y);
  Vec2 operator *(double s) => Vec2(x * s, y * s);
  Vec2 operator -() => Vec2(-x, -y);

  double get length => math.sqrt(x * x + y * y);
  double get lengthSquared => x * x + y * y;

  Vec2 normalized() {
    final len = length;
    if (len < 1e-12) return Vec2.zero;
    return this * (1 / len);
  }

  double distanceTo(Vec2 o) => (this - o).length;

  double dot(Vec2 o) => x * o.x + y * o.y;

  Vec2 lerp(Vec2 o, double t) => Vec2(x + (o.x - x) * t, y + (o.y - y) * t);

  Map<String, double> toJson() => {'x': x, 'y': y};

  factory Vec2.fromJson(Map<String, dynamic> json) =>
      Vec2((json['x'] as num).toDouble(), (json['y'] as num).toDouble());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vec2 && (x - other.x).abs() < 1e-9 && (y - other.y).abs() < 1e-9;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Vec2(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)})';
}
