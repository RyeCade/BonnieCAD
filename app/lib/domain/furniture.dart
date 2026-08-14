import 'dart:math' as math;

import '../core/vec2.dart';
import 'furniture_catalog.dart';

class FurnitureItem {
  FurnitureItem({
    required this.id,
    required this.catalogId,
    required this.origin,
    required this.width,
    required this.depth,
    this.rotationRad = 0,
    this.layerId = 'furniture',
    this.colorValue,
    this.strokeWidth,
  });

  final String id;
  String catalogId;
  Vec2 origin;
  double width;
  double depth;
  double rotationRad;
  String layerId;
  int? colorValue;
  double? strokeWidth;

  FurnitureCatalogEntry? get catalogEntry => FurnitureCatalog.byId(catalogId);

  FurnitureItem copyWith({
    String? catalogId,
    Vec2? origin,
    double? width,
    double? depth,
    double? rotationRad,
    String? layerId,
    int? colorValue,
    double? strokeWidth,
    bool clearColor = false,
    bool clearStroke = false,
  }) {
    return FurnitureItem(
      id: id,
      catalogId: catalogId ?? this.catalogId,
      origin: origin ?? this.origin,
      width: width ?? this.width,
      depth: depth ?? this.depth,
      rotationRad: rotationRad ?? this.rotationRad,
      layerId: layerId ?? this.layerId,
      colorValue: clearColor ? null : (colorValue ?? this.colorValue),
      strokeWidth: clearStroke ? null : (strokeWidth ?? this.strokeWidth),
    );
  }

  List<Vec2> localCorners() {
    final hw = width / 2;
    final hd = depth / 2;
    return [
      Vec2(-hw, -hd),
      Vec2(hw, -hd),
      Vec2(hw, hd),
      Vec2(-hw, hd),
    ];
  }

  List<Vec2> worldCorners() {
    final cos = math.cos(rotationRad);
    final sin = math.sin(rotationRad);
    return localCorners().map((p) {
      final rx = p.x * cos - p.y * sin;
      final ry = p.x * sin + p.y * cos;
      return Vec2(origin.x + rx, origin.y + ry);
    }).toList();
  }

  bool containsPoint(Vec2 world, {double pad = 0}) {
    final cos = math.cos(rotationRad);
    final sin = math.sin(rotationRad);
    final dx = world.x - origin.x;
    final dy = world.y - origin.y;
    final lx = dx * cos + dy * sin;
    final ly = -dx * sin + dy * cos;
    final hw = width / 2 + pad;
    final hd = depth / 2 + pad;
    return lx.abs() <= hw && ly.abs() <= hd;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'catalogId': catalogId,
        'origin': origin.toJson(),
        'width': width,
        'depth': depth,
        'rotationRad': rotationRad,
        'layerId': layerId,
        if (colorValue != null) 'colorValue': colorValue,
        if (strokeWidth != null) 'strokeWidth': strokeWidth,
      };

  factory FurnitureItem.fromJson(Map<String, dynamic> json) => FurnitureItem(
        id: json['id'] as String,
        catalogId: json['catalogId'] as String,
        origin: Vec2.fromJson(Map<String, dynamic>.from(json['origin'] as Map)),
        width: (json['width'] as num).toDouble(),
        depth: (json['depth'] as num).toDouble(),
        rotationRad: (json['rotationRad'] as num?)?.toDouble() ?? 0,
        layerId: json['layerId'] as String? ?? 'furniture',
        colorValue: json['colorValue'] as int?,
        strokeWidth: (json['strokeWidth'] as num?)?.toDouble(),
      );
}
