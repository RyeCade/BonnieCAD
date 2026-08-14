import '../core/vec2.dart';

class LinearDimension {
  LinearDimension({
    required this.id,
    required this.p1,
    required this.p2,
    this.offset = 12.0,
    this.layerId = 'dimensions',
    this.colorValue,
    this.strokeWidth,
  });

  final String id;
  Vec2 p1;
  Vec2 p2;
  double offset;
  String layerId;
  int? colorValue;
  double? strokeWidth;

  double get measuredLength => p1.distanceTo(p2);

  LinearDimension copyWith({
    Vec2? p1,
    Vec2? p2,
    double? offset,
    String? layerId,
    int? colorValue,
    double? strokeWidth,
    bool clearColor = false,
    bool clearStroke = false,
  }) {
    return LinearDimension(
      id: id,
      p1: p1 ?? this.p1,
      p2: p2 ?? this.p2,
      offset: offset ?? this.offset,
      layerId: layerId ?? this.layerId,
      colorValue: clearColor ? null : (colorValue ?? this.colorValue),
      strokeWidth: clearStroke ? null : (strokeWidth ?? this.strokeWidth),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'p1': p1.toJson(),
        'p2': p2.toJson(),
        'offset': offset,
        'layerId': layerId,
        if (colorValue != null) 'colorValue': colorValue,
        if (strokeWidth != null) 'strokeWidth': strokeWidth,
      };

  factory LinearDimension.fromJson(Map<String, dynamic> json) =>
      LinearDimension(
        id: json['id'] as String,
        p1: Vec2.fromJson(Map<String, dynamic>.from(json['p1'] as Map)),
        p2: Vec2.fromJson(Map<String, dynamic>.from(json['p2'] as Map)),
        offset: (json['offset'] as num?)?.toDouble() ?? 12.0,
        layerId: json['layerId'] as String? ?? 'dimensions',
        colorValue: json['colorValue'] as int?,
        strokeWidth: (json['strokeWidth'] as num?)?.toDouble(),
      );
}
