import '../core/vec2.dart';

class TextLabel {
  TextLabel({
    required this.id,
    required this.origin,
    required this.text,
    this.rotationRad = 0,
    this.fontSizePx = 14,
    this.layerId = 'annotations',
    this.colorValue,
  });

  final String id;
  Vec2 origin;
  String text;
  double rotationRad;
  double fontSizePx;
  String layerId;
  int? colorValue;

  TextLabel copyWith({
    Vec2? origin,
    String? text,
    double? rotationRad,
    double? fontSizePx,
    String? layerId,
    int? colorValue,
    bool clearColor = false,
  }) {
    return TextLabel(
      id: id,
      origin: origin ?? this.origin,
      text: text ?? this.text,
      rotationRad: rotationRad ?? this.rotationRad,
      fontSizePx: fontSizePx ?? this.fontSizePx,
      layerId: layerId ?? this.layerId,
      colorValue: clearColor ? null : (colorValue ?? this.colorValue),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'origin': origin.toJson(),
        'text': text,
        'rotationRad': rotationRad,
        'fontSizePx': fontSizePx,
        'layerId': layerId,
        if (colorValue != null) 'colorValue': colorValue,
      };

  factory TextLabel.fromJson(Map<String, dynamic> json) => TextLabel(
        id: json['id'] as String,
        origin: Vec2.fromJson(Map<String, dynamic>.from(json['origin'] as Map)),
        text: json['text'] as String? ?? 'Label',
        rotationRad: (json['rotationRad'] as num?)?.toDouble() ?? 0,
        fontSizePx: (json['fontSizePx'] as num?)?.toDouble() ?? 14,
        layerId: json['layerId'] as String? ?? 'annotations',
        colorValue: json['colorValue'] as int?,
      );
}
