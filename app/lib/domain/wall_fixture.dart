enum WallFixtureType { outlet, switchFixture, light }

class WallFixture {
  WallFixture({
    required this.id,
    required this.type,
    required this.wallId,
    required this.offset,
    this.scale = 1.0,
    this.layerId = 'electrical',
    this.colorValue,
    this.strokeWidth,
  });

  final String id;
  WallFixtureType type;
  String wallId;
  /// Distance from wall endpoint A to fixture center, inches.
  double offset;
  /// Symbol size multiplier (1 = default sticker size).
  double scale;
  String layerId;
  int? colorValue;
  double? strokeWidth;

  WallFixture copyWith({
    WallFixtureType? type,
    String? wallId,
    double? offset,
    double? scale,
    String? layerId,
    int? colorValue,
    double? strokeWidth,
    bool clearColor = false,
    bool clearStroke = false,
  }) {
    return WallFixture(
      id: id,
      type: type ?? this.type,
      wallId: wallId ?? this.wallId,
      offset: offset ?? this.offset,
      scale: scale ?? this.scale,
      layerId: layerId ?? this.layerId,
      colorValue: clearColor ? null : (colorValue ?? this.colorValue),
      strokeWidth: clearStroke ? null : (strokeWidth ?? this.strokeWidth),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'wallId': wallId,
        'offset': offset,
        if (scale != 1.0) 'scale': scale,
        'layerId': layerId,
        if (colorValue != null) 'colorValue': colorValue,
        if (strokeWidth != null) 'strokeWidth': strokeWidth,
      };

  factory WallFixture.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String? ?? 'outlet';
    final type = WallFixtureType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => WallFixtureType.outlet,
    );
    return WallFixture(
      id: json['id'] as String,
      type: type,
      wallId: json['wallId'] as String,
      offset: (json['offset'] as num).toDouble(),
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      layerId: json['layerId'] as String? ?? 'electrical',
      colorValue: json['colorValue'] as int?,
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble(),
    );
  }

  static WallFixtureType typeFromCatalogId(String catalogId) =>
      switch (catalogId) {
        'switch' => WallFixtureType.switchFixture,
        'wall_light' => WallFixtureType.light,
        _ => WallFixtureType.outlet,
      };
}
