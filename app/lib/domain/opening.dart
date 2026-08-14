enum OpeningType { door, window }

enum DoorSwing { leftIn, leftOut, rightIn, rightOut }

class Opening {
  Opening({
    required this.id,
    required this.type,
    required this.wallId,
    required this.offset,
    required this.width,
    this.swing = DoorSwing.leftIn,
    this.layerId = 'openings',
    this.colorValue,
    this.strokeWidth,
  });

  final String id;
  OpeningType type;
  String wallId;
  double offset;
  double width;
  DoorSwing swing;
  String layerId;
  int? colorValue;
  double? strokeWidth;

  double get centerOffset => offset + width / 2;

  Opening copyWith({
    OpeningType? type,
    String? wallId,
    double? offset,
    double? width,
    DoorSwing? swing,
    String? layerId,
    int? colorValue,
    double? strokeWidth,
    bool clearColor = false,
    bool clearStroke = false,
  }) {
    return Opening(
      id: id,
      type: type ?? this.type,
      wallId: wallId ?? this.wallId,
      offset: offset ?? this.offset,
      width: width ?? this.width,
      swing: swing ?? this.swing,
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
        'width': width,
        'swing': swing.name,
        'layerId': layerId,
        if (colorValue != null) 'colorValue': colorValue,
        if (strokeWidth != null) 'strokeWidth': strokeWidth,
      };

  factory Opening.fromJson(Map<String, dynamic> json) => Opening(
        id: json['id'] as String,
        type: OpeningType.values.byName(json['type'] as String),
        wallId: json['wallId'] as String,
        offset: (json['offset'] as num).toDouble(),
        width: (json['width'] as num).toDouble(),
        swing: DoorSwing.values.byName(
          json['swing'] as String? ?? DoorSwing.leftIn.name,
        ),
        layerId: json['layerId'] as String? ?? 'openings',
        colorValue: json['colorValue'] as int?,
        strokeWidth: (json['strokeWidth'] as num?)?.toDouble(),
      );
}
