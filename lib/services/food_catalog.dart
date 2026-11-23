import 'models.dart';

/// كتالوج أكلات مصرية شائعة (قيم تقديرية للحصة المذكورة) للبحث اليدوي.
class FoodCatalogEntry {
  const FoodCatalogEntry(this.name, this.portion, this.kcal, this.protein, this.carbs, this.fat, {this.asset, this.fiber = 0, this.sugar = 0, this.sodium = 0});
  final String name, portion;
  final int kcal;
  final double protein, carbs, fat;
  final double fiber, sugar, sodium; // جرام (الصوديوم ملجم)

  /// صورة جاهزة للأكلة، لو الصور الجاهزة مفعّلة بس (FoodAssets.useStock).
  String? get image => FoodAssets.useStock ? (asset ?? FoodAssets.match(name)) : null;
  final String? asset;

  FoodItem toItem() => FoodItem(
        name: name,
        portion: portion,
        kcal: kcal,
        protein: protein,
        carbs: carbs,
        fat: fat,
        fiber: fiber,
        sugar: sugar,
        sodium: sodium,
        asset: image,
      );
}

class FoodCatalog {
  FoodCatalog._();

  static const entries = [
    FoodCatalogEntry('كشري', 'طبق وسط · ٣٥٠ جم', 570, 14, 88, 12, asset: FoodAssets.koshary, fiber: 9, sugar: 6, sodium: 900),
    FoodCatalogEntry('فول مدمس', 'طبق صغير · ١٥٠ جم', 190, 12, 24, 5, asset: FoodAssets.fulTamiya, fiber: 9, sugar: 1, sodium: 500),
    FoodCatalogEntry('طعمية', '٣ أقراص', 170, 6, 14, 10, asset: FoodAssets.fulTamiya, fiber: 4, sugar: 1, sodium: 350),
    FoodCatalogEntry('فول وطعمية', 'طبق وسط', 360, 18, 38, 15, asset: FoodAssets.fulTamiya, fiber: 12, sugar: 2, sodium: 850),
    FoodCatalogEntry('عيش بلدي', 'رغيف كامل · ٩٠ جم', 230, 8, 46, 1, asset: FoodAssets.baladiBread, fiber: 4, sugar: 1, sodium: 420),
    FoodCatalogEntry('عيش فينو', 'رغيف', 150, 5, 30, 1, fiber: 1.5, sugar: 3, sodium: 300),
    FoodCatalogEntry('شاي بلبن', 'كوباية · ٢ معلقة سكر', 145, 6, 18, 1, asset: FoodAssets.shaiLaban, fiber: 0, sugar: 15, sodium: 40),
    FoodCatalogEntry('شاي سادة', 'كوباية · معلقة سكر', 25, 0, 6, 0, fiber: 0, sugar: 5, sodium: 5),
    FoodCatalogEntry('قهوة سادة', 'فنجان', 5, 0, 1, 0, fiber: 0, sugar: 0, sodium: 5),
    FoodCatalogEntry('بيض مسلوق', 'بيضة', 78, 6, 1, 5, fiber: 0, sugar: 0.5, sodium: 62),
    FoodCatalogEntry('بيض مقلي', 'بيضة', 100, 6, 1, 8, fiber: 0, sugar: 0.5, sodium: 95),
    FoodCatalogEntry('جبنة بيضاء', '٥٠ جم', 125, 7, 2, 10, fiber: 0, sugar: 1, sodium: 500),
    FoodCatalogEntry('زبادي', 'علبة · ١٢٥ جم', 80, 5, 7, 3, fiber: 0, sugar: 7, sodium: 60),
    FoodCatalogEntry('فراخ مشوية', 'ربع فرخة · ١٥٠ جم', 270, 36, 0, 13, asset: FoodAssets.chickenVeg, fiber: 0, sugar: 0, sodium: 300),
    FoodCatalogEntry('فراخ وخضار', 'طبق وسط', 480, 40, 40, 16, asset: FoodAssets.chickenVeg, fiber: 6, sugar: 8, sodium: 600),
    FoodCatalogEntry('كفتة مشوية', '٣ أصابع', 330, 26, 3, 24, fiber: 1, sugar: 1, sodium: 500),
    FoodCatalogEntry('سمك مشوي', 'قطعة · ١٥٠ جم', 220, 32, 0, 9, fiber: 0, sugar: 0, sodium: 150),
    FoodCatalogEntry('أرز أبيض', 'طبق · ١٥٠ جم', 200, 4, 44, 1, fiber: 1, sugar: 0, sodium: 250),
    FoodCatalogEntry('مكرونة بالصلصة', 'طبق · ٢٠٠ جم', 330, 11, 60, 5, fiber: 4, sugar: 8, sodium: 600),
    FoodCatalogEntry('مكرونة بشاميل', 'قطعة', 450, 18, 42, 24, fiber: 3, sugar: 8, sodium: 700),
    FoodCatalogEntry('ملوخية', 'طبق', 120, 7, 10, 6, fiber: 5, sugar: 2, sodium: 450),
    FoodCatalogEntry('شوربة عدس', 'طبق', 180, 10, 28, 3, fiber: 6, sugar: 3, sodium: 600),
    FoodCatalogEntry('محشي ورق عنب', '٦ حبات', 260, 5, 40, 9, fiber: 4, sugar: 3, sodium: 550),
    FoodCatalogEntry('شاورما فراخ', 'ساندوتش', 450, 28, 40, 20, fiber: 3, sugar: 5, sodium: 1100),
    FoodCatalogEntry('بطاطس مقلية', 'حصة وسط · ١٠٠ جم', 310, 4, 40, 15, fiber: 3, sugar: 0.5, sodium: 300),
    FoodCatalogEntry('سلطة خضراء', 'طبق', 60, 2, 8, 3, fiber: 3, sugar: 4, sodium: 150),
    FoodCatalogEntry('موزة', 'واحدة متوسطة', 105, 1, 27, 0, fiber: 3, sugar: 14, sodium: 1),
    FoodCatalogEntry('تفاحة', 'واحدة متوسطة', 95, 0, 25, 0, fiber: 4, sugar: 19, sodium: 2),
    FoodCatalogEntry('تفاح وزبدة فول', 'تفاحة + معلقة', 160, 3, 22, 8, asset: FoodAssets.applePb, fiber: 5, sugar: 20, sodium: 60),
    FoodCatalogEntry('تمر محشي لوز', '٣ حبات', 180, 3, 38, 4, asset: FoodAssets.datesAlmond, fiber: 4, sugar: 30, sodium: 2),
    FoodCatalogEntry('شيبسي', 'كيس صغير · ٣٠ جم', 160, 2, 15, 10, asset: FoodAssets.chips, fiber: 1, sugar: 0.5, sodium: 180),
    FoodCatalogEntry('عصير برتقال', 'كوباية', 110, 2, 26, 0, fiber: 0.5, sugar: 21, sodium: 2),
    FoodCatalogEntry('مياه غازية', 'علبة', 140, 0, 35, 0, fiber: 0, sugar: 35, sodium: 15),
    FoodCatalogEntry('رز بلبن', 'علبة', 250, 6, 40, 7, fiber: 0, sugar: 28, sodium: 100),
    FoodCatalogEntry('أم علي', 'طبق', 400, 9, 45, 20, fiber: 1, sugar: 25, sodium: 180),
    FoodCatalogEntry('بسبوسة', 'قطعة', 250, 3, 38, 10, fiber: 1, sugar: 28, sodium: 120),
    FoodCatalogEntry('كنافة', 'قطعة', 350, 6, 42, 18, fiber: 1, sugar: 25, sodium: 150),
  ];

  static FoodCatalogEntry? byName(String name) {
    final n = normalize(name);
    for (final e in entries) {
      if (normalize(e.name) == n) return e;
    }
    return null;
  }

  /// يطبّع العربي: يشيل التشكيل ويوحّد الهمزات والتاء المربوطة.
  static String normalize(String s) => s
      .replaceAll(RegExp('[\u064B-\u0652\u0640]'), '')
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .toLowerCase()
      .trim();

  static List<FoodCatalogEntry> search(String q) {
    final n = normalize(q);
    if (n.isEmpty) return entries;
    return entries.where((e) => normalize(e.name).contains(n)).toList();
  }
}
