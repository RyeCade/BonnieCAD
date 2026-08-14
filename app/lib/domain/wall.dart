import '../core/vec2.dart';

class Wall {
  Wall({
    required this.id,
    required this.a,
    required this.b,
    this.thickness = 4.5,
    this.layerId = 'walls',
    this.colorValue,
    this.strokeWidth,
  });

  final String id;
  Vec2 a;
  Vec2 b;
  double thickness;
  String layerId;
  int? colorValue;
  double? strokeWidth;

  double get length => a.distanceTo(b);

  Vec2 get midpoint => a.lerp(b, 0.5);

  Vec2 get direction {
    final d = b - a;
    return d.normalized();
  }

  Vec2 pointAt(double distanceAlong) {
    final len = length;
    if (len < 1e-12) return a;
    final t = (distanceAlong / len).clamp(0.0, 1.0);
    return a.lerp(b, t);
  }

  double clampOffset(double offset) => offset.clamp(0.0, length);

  Wall copyWith({
    Vec2? a,
    Vec2? b,
    double? thickness,
    String? layerId,
    int? colorValue,
    double? strokeWidth,
    bool clearColor = false,
    bool clearStroke = false,
  }) {
    return Wall(
      id: id,
      a: a ?? this.a,
      b: b ?? this.b,
      thickness: thickness ?? this.thickness,
      layerId: layerId ?? this.layerId,
      colorValue: clearColor ? null : (colorValue ?? this.colorValue),
      strokeWidth: clearStroke ? null : (strokeWidth ?? this.strokeWidth),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'a': a.toJson(),
        'b': b.toJson(),
        'thickness': thickness,
        'layerId': layerId,
        if (colorValue != null) 'colorValue': colorValue,
        if (strokeWidth != null) 'strokeWidth': strokeWidth,
      };

  factory Wall.fromJson(Map<String, dynamic> json) => Wall(
        id: json['id'] as String,
        a: Vec2.fromJson(Map<String, dynamic>.from(json['a'] as Map)),
        b: Vec2.fromJson(Map<String, dynamic>.from(json['b'] as Map)),
        thickness: (json['thickness'] as num?)?.toDouble() ?? 4.5,
        layerId: json['layerId'] as String? ?? 'walls',
        colorValue: json['colorValue'] as int?,
        strokeWidth: (json['strokeWidth'] as num?)?.toDouble(),
      );
}
