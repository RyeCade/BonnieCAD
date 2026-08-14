class Layer {
  Layer({
    required this.id,
    required this.name,
    this.visible = true,
    this.locked = false,
    this.colorValue = 0xFF212121,
  });

  final String id;
  String name;
  bool visible;
  bool locked;
  int colorValue;

  Layer copyWith({
    String? name,
    bool? visible,
    bool? locked,
    int? colorValue,
  }) {
    return Layer(
      id: id,
      name: name ?? this.name,
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'visible': visible,
        'locked': locked,
        'colorValue': colorValue,
      };

  factory Layer.fromJson(Map<String, dynamic> json) => Layer(
        id: json['id'] as String,
        name: json['name'] as String,
        visible: json['visible'] as bool? ?? true,
        locked: json['locked'] as bool? ?? false,
        colorValue: json['colorValue'] as int? ?? 0xFF212121,
      );
}
