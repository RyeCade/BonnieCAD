enum FurnitureCategory {
  bath,
  kitchen,
  bedroom,
  living,
  laundry,
  electrical,
  misc,
}

enum FurnitureDrawStyle {
  rect,
  roundedRect,
  ellipse,
  toilet,
  bathtub,
  shower,
  sink,
  stove,
  fridge,
  bed,
  sofa,
  chair,
  table,
  washer,
  outlet,
  switchFixture,
  light,
  cabinet,
}

class FurnitureCatalogEntry {
  const FurnitureCatalogEntry({
    required this.id,
    required this.name,
    required this.category,
    required this.defaultWidth,
    required this.defaultDepth,
    required this.drawStyle,
    this.wallHosted = false,
  });

  final String id;
  final String name;
  final FurnitureCategory category;
  final double defaultWidth;
  final double defaultDepth;
  final FurnitureDrawStyle drawStyle;
  final bool wallHosted;
}

class FurnitureCatalog {
  static const entries = <FurnitureCatalogEntry>[
    // Bath
    FurnitureCatalogEntry(
      id: 'bathtub',
      name: 'Bathtub',
      category: FurnitureCategory.bath,
      defaultWidth: 60,
      defaultDepth: 30,
      drawStyle: FurnitureDrawStyle.bathtub,
    ),
    FurnitureCatalogEntry(
      id: 'shower',
      name: 'Shower',
      category: FurnitureCategory.bath,
      defaultWidth: 36,
      defaultDepth: 36,
      drawStyle: FurnitureDrawStyle.shower,
    ),
    FurnitureCatalogEntry(
      id: 'toilet',
      name: 'Toilet',
      category: FurnitureCategory.bath,
      defaultWidth: 18,
      defaultDepth: 28,
      drawStyle: FurnitureDrawStyle.toilet,
    ),
    FurnitureCatalogEntry(
      id: 'bath_sink',
      name: 'Bath sink',
      category: FurnitureCategory.bath,
      defaultWidth: 24,
      defaultDepth: 18,
      drawStyle: FurnitureDrawStyle.sink,
    ),
    FurnitureCatalogEntry(
      id: 'bidet',
      name: 'Bidet',
      category: FurnitureCategory.bath,
      defaultWidth: 15,
      defaultDepth: 24,
      drawStyle: FurnitureDrawStyle.toilet,
    ),
    // Kitchen
    FurnitureCatalogEntry(
      id: 'base_cabinet',
      name: 'Base cabinet',
      category: FurnitureCategory.kitchen,
      defaultWidth: 36,
      defaultDepth: 24,
      drawStyle: FurnitureDrawStyle.cabinet,
    ),
    FurnitureCatalogEntry(
      id: 'fridge',
      name: 'Fridge',
      category: FurnitureCategory.kitchen,
      defaultWidth: 36,
      defaultDepth: 30,
      drawStyle: FurnitureDrawStyle.fridge,
    ),
    FurnitureCatalogEntry(
      id: 'stove',
      name: 'Stove',
      category: FurnitureCategory.kitchen,
      defaultWidth: 30,
      defaultDepth: 26,
      drawStyle: FurnitureDrawStyle.stove,
    ),
    FurnitureCatalogEntry(
      id: 'dishwasher',
      name: 'Dishwasher',
      category: FurnitureCategory.kitchen,
      defaultWidth: 24,
      defaultDepth: 24,
      drawStyle: FurnitureDrawStyle.rect,
    ),
    FurnitureCatalogEntry(
      id: 'kitchen_sink',
      name: 'Kitchen sink',
      category: FurnitureCategory.kitchen,
      defaultWidth: 33,
      defaultDepth: 22,
      drawStyle: FurnitureDrawStyle.sink,
    ),
    FurnitureCatalogEntry(
      id: 'island',
      name: 'Island',
      category: FurnitureCategory.kitchen,
      defaultWidth: 72,
      defaultDepth: 36,
      drawStyle: FurnitureDrawStyle.roundedRect,
    ),
    // Bedroom
    FurnitureCatalogEntry(
      id: 'twin_bed',
      name: 'Twin bed',
      category: FurnitureCategory.bedroom,
      defaultWidth: 39,
      defaultDepth: 75,
      drawStyle: FurnitureDrawStyle.bed,
    ),
    FurnitureCatalogEntry(
      id: 'queen_bed',
      name: 'Queen bed',
      category: FurnitureCategory.bedroom,
      defaultWidth: 60,
      defaultDepth: 80,
      drawStyle: FurnitureDrawStyle.bed,
    ),
    FurnitureCatalogEntry(
      id: 'nightstand',
      name: 'Nightstand',
      category: FurnitureCategory.bedroom,
      defaultWidth: 18,
      defaultDepth: 16,
      drawStyle: FurnitureDrawStyle.rect,
    ),
    FurnitureCatalogEntry(
      id: 'dresser',
      name: 'Dresser',
      category: FurnitureCategory.bedroom,
      defaultWidth: 60,
      defaultDepth: 20,
      drawStyle: FurnitureDrawStyle.cabinet,
    ),
    // Living
    FurnitureCatalogEntry(
      id: 'sofa',
      name: 'Sofa',
      category: FurnitureCategory.living,
      defaultWidth: 84,
      defaultDepth: 36,
      drawStyle: FurnitureDrawStyle.sofa,
    ),
    FurnitureCatalogEntry(
      id: 'armchair',
      name: 'Armchair',
      category: FurnitureCategory.living,
      defaultWidth: 32,
      defaultDepth: 32,
      drawStyle: FurnitureDrawStyle.chair,
    ),
    FurnitureCatalogEntry(
      id: 'coffee_table',
      name: 'Coffee table',
      category: FurnitureCategory.living,
      defaultWidth: 48,
      defaultDepth: 24,
      drawStyle: FurnitureDrawStyle.table,
    ),
    FurnitureCatalogEntry(
      id: 'dining_table',
      name: 'Dining table',
      category: FurnitureCategory.living,
      defaultWidth: 72,
      defaultDepth: 36,
      drawStyle: FurnitureDrawStyle.table,
    ),
    FurnitureCatalogEntry(
      id: 'chair',
      name: 'Chair',
      category: FurnitureCategory.living,
      defaultWidth: 18,
      defaultDepth: 20,
      drawStyle: FurnitureDrawStyle.chair,
    ),
    FurnitureCatalogEntry(
      id: 'tv_stand',
      name: 'TV stand',
      category: FurnitureCategory.living,
      defaultWidth: 60,
      defaultDepth: 16,
      drawStyle: FurnitureDrawStyle.cabinet,
    ),
    // Laundry
    FurnitureCatalogEntry(
      id: 'washer',
      name: 'Washer',
      category: FurnitureCategory.laundry,
      defaultWidth: 27,
      defaultDepth: 30,
      drawStyle: FurnitureDrawStyle.washer,
    ),
    FurnitureCatalogEntry(
      id: 'dryer',
      name: 'Dryer',
      category: FurnitureCategory.laundry,
      defaultWidth: 27,
      defaultDepth: 30,
      drawStyle: FurnitureDrawStyle.washer,
    ),
    // Electrical (wall-hosted)
    FurnitureCatalogEntry(
      id: 'outlet',
      name: 'Outlet',
      category: FurnitureCategory.electrical,
      defaultWidth: 4,
      defaultDepth: 4,
      drawStyle: FurnitureDrawStyle.outlet,
      wallHosted: true,
    ),
    FurnitureCatalogEntry(
      id: 'switch',
      name: 'Switch',
      category: FurnitureCategory.electrical,
      defaultWidth: 4,
      defaultDepth: 4,
      drawStyle: FurnitureDrawStyle.switchFixture,
      wallHosted: true,
    ),
    FurnitureCatalogEntry(
      id: 'wall_light',
      name: 'Wall light',
      category: FurnitureCategory.electrical,
      defaultWidth: 6,
      defaultDepth: 6,
      drawStyle: FurnitureDrawStyle.light,
      wallHosted: true,
    ),
    // Misc free light + closet
    FurnitureCatalogEntry(
      id: 'ceiling_light',
      name: 'Ceiling light',
      category: FurnitureCategory.electrical,
      defaultWidth: 12,
      defaultDepth: 12,
      drawStyle: FurnitureDrawStyle.light,
    ),
    FurnitureCatalogEntry(
      id: 'closet',
      name: 'Closet',
      category: FurnitureCategory.misc,
      defaultWidth: 48,
      defaultDepth: 24,
      drawStyle: FurnitureDrawStyle.cabinet,
    ),
  ];

  static FurnitureCatalogEntry? byId(String id) {
    for (final e in entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  static List<FurnitureCatalogEntry> byCategory(FurnitureCategory c) =>
      entries.where((e) => e.category == c).toList();

  static List<FurnitureCatalogEntry> get freeStanding =>
      entries.where((e) => !e.wallHosted).toList();

  static List<FurnitureCatalogEntry> get wallHosted =>
      entries.where((e) => e.wallHosted).toList();

  static String categoryLabel(FurnitureCategory c) => switch (c) {
        FurnitureCategory.bath => 'Bath',
        FurnitureCategory.kitchen => 'Kitchen',
        FurnitureCategory.bedroom => 'Bedroom',
        FurnitureCategory.living => 'Living',
        FurnitureCategory.laundry => 'Laundry',
        FurnitureCategory.electrical => 'Electrical',
        FurnitureCategory.misc => 'Misc',
      };
}
