import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../services/arabic_digits.dart';

enum MealType { breakfast, lunch, dinner, snack }

extension MealTypeX on MealType {
  String get label => switch (this) {
        MealType.breakfast => 'فطار',
        MealType.lunch => 'غدا',
        MealType.dinner => 'عشا',
        MealType.snack => 'سناك',
      };

  static MealType byHour(int h) => h < 11
      ? MealType.breakfast
      : h < 17
          ? MealType.lunch
          : h < 21
              ? MealType.dinner
              : MealType.snack;

  static MealType parse(String? s) => MealType.values.firstWhere((e) => e.name == s, orElse: () => MealType.snack);
}

enum Confidence { high, medium, low }

extension ConfidenceX on Confidence {
  String get label => switch (this) {
        Confidence.high => 'عالية',
        Confidence.medium => 'متوسطة',
        Confidence.low => 'منخفضة',
      };

  static Confidence parse(String? s) => Confidence.values.firstWhere((e) => e.name == s, orElse: () => Confidence.medium);
}

int _idCounter = 0;
String newId() => '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

class FoodAssets {
  FoodAssets._();
  static const koshary = 'assets/images/food_koshary.png';
  static const fulTamiya = 'assets/images/food_ful_tamiya.png';
  static const baladiBread = 'assets/images/food_baladi_bread.png';
  static const shaiLaban = 'assets/images/food_shai_laban.png';
  static const chickenVeg = 'assets/images/food_chicken_veg.png';
  static const datesAlmond = 'assets/images/food_dates_almond.png';
  static const chips = 'assets/images/food_chips.png';
  static const applePb = 'assets/images/food_apple_pb.png';

  /// يختار صورة مناسبة من الاسم، وبشروط دقيقة عشان ما تظهرش صورة غلط
  /// (مثلاً "شاي أحمر" مايخدش صورة الشاي بلبن). لو مفيش مطابقة بيرجّع null.
  /// الصور الجاهزة (assets) مقفولة: صورة الوجبة بيضيفها المستخدم بنفسه. غيّرها لـ true لو عايزها تشتغل تاني.
  static const bool useStock = true;

  static String? match(String name) {
    if (!useStock) return null;
    bool has(String k) => name.contains(k);
    if (has('كشري')) return koshary;
    if (has('فول') || has('طعمي') || has('فلافل')) return fulTamiya;
    if (has('عيش') && !(has('فينو') || has('شامي') || has('توست') || has('حواوشي'))) return baladiBread;
    if (has('شاي') && has('لبن')) return shaiLaban;
    if (has('فراخ') || has('دجاج')) return chickenVeg;
    if (has('تمر')) return datesAlmond;
    if (has('شيبس')) return chips;
    if (has('تفاح') && has('زبدة')) return applePb;
    return null;
  }
}

double _num(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
const Object _unset = Object();
/// عنصر أكل. القيم الأساسية لـ "١×" من الحصة، والكمية (qty) معامل ضرب.
class FoodItem {
  FoodItem({
    String? id,
    required this.name,
    required this.portion,
    required int kcal,
    double protein = 0,
    double carbs = 0,
    double fat = 0,
    double fiber = 0,
    double sugar = 0,
    double sodium = 0,
    this.qty = 1,
    this.grams,
    this.asset,
    this.tag,
    this.tagColor,
    this.confidence = Confidence.high,
    this.needsReview = false,
  })  : id = id ?? newId(),
        baseKcal = kcal,
        baseProtein = protein,
        baseCarbs = carbs,
        baseFat = fat,
        baseFiber = fiber,
        baseSugar = sugar,
        baseSodium = sodium;

  final String id;
  final String name;
  final String portion;
  final int baseKcal;
  final double baseProtein, baseCarbs, baseFat, baseFiber, baseSugar, baseSodium; // جرام (الصوديوم ملجم)
  final double qty;
  final int? grams;
  final String? asset; // asset أو رابط أو مسار ملف
  final String? tag;
  final Color? tagColor;
  final Confidence confidence;
  final bool needsReview;

  int get kcal => (baseKcal * qty).round();
  int get protein => (baseProtein * qty).round();
  int get carbs => (baseCarbs * qty).round();
  int get fat => (baseFat * qty).round();
  double get fiber => baseFiber * qty;
  double get sugar => baseSugar * qty;
  double get sodium => baseSodium * qty;

  String get portionLabel => qty == 1 ? portion : '$portion × ${arNum(qty)}';

  /// [kcal] هنا هي السعرات الأساسية لـ ١×.
  FoodItem copyWith({
    String? name,
    String? portion,
    int? kcal,
    double? qty,
    Object? asset = _unset,
    bool? needsReview,
  }) =>
      FoodItem(
        id: id,
        name: name ?? this.name,
        portion: portion ?? this.portion,
        kcal: kcal ?? baseKcal,
        protein: baseProtein,
        carbs: baseCarbs,
        fat: baseFat,
        fiber: baseFiber,
        sugar: baseSugar,
        sodium: baseSodium,
        qty: qty ?? this.qty,
        grams: grams,
        asset: identical(asset, _unset) ? this.asset : asset as String?,
        tag: tag,
        tagColor: tagColor,
        confidence: confidence,
        needsReview: needsReview ?? this.needsReview,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'portion': portion,
        'kcal': baseKcal,
        'p': baseProtein,
        'c': baseCarbs,
        'f': baseFat,
        'fiber': baseFiber,
        'sugar': baseSugar,
        'sodium': baseSodium,
        'qty': qty,
        'grams': grams,
        'asset': asset,
        'tag': tag,
        'tagColor': tagColor?.toARGB32(),
        'confidence': confidence.name,
        'review': needsReview,
      };

  factory FoodItem.fromJson(Map<String, dynamic> j) => FoodItem(
        id: j['id'] as String?,
        name: j['name'] as String? ?? '',
        portion: j['portion'] as String? ?? '',
        kcal: (j['kcal'] as num?)?.round() ?? 0,
        protein: _num(j['p']),
        carbs: _num(j['c']),
        fat: _num(j['f']),
        fiber: _num(j['fiber']),
        sugar: _num(j['sugar']),
        sodium: _num(j['sodium']),
        qty: j['qty'] == null ? 1 : _num(j['qty']),
        grams: (j['grams'] as num?)?.round(),
        asset: j['asset'] as String?,
        tag: j['tag'] as String?,
        tagColor: j['tagColor'] == null ? null : Color((j['tagColor'] as num).toInt()),
        confidence: ConfidenceX.parse(j['confidence'] as String?),
        needsReview: j['review'] as bool? ?? false,
      );
}

class Macros {
  const Macros({required this.protein, required this.carbs, required this.fat});
  final int protein, carbs, fat; // جرام
}

Macros _sumMacros(List<FoodItem> items) => Macros(
      protein: items.fold(0, (s, e) => s + e.protein),
      carbs: items.fold(0, (s, e) => s + e.carbs),
      fat: items.fold(0, (s, e) => s + e.fat),
    );

/// نتيجة تحليل وجبة كاملة.
class MealAnalysis {
  MealAnalysis({
    required this.type,
    required List<FoodItem> items,
    this.confidence = Confidence.high,
    this.warning,
    this.isDemo = false,
  }) : items = List<FoodItem>.of(items);

  final MealType type;
  final List<FoodItem> items;
  final Confidence confidence;
  final String? warning;
  final bool isDemo; // نتيجة تجريبية (مفيش مفتاح Gemini)

  int get totalKcal => items.fold(0, (s, e) => s + e.kcal);
  int get rangeMin => (totalKcal * .94).round();
  int get rangeMax => (totalKcal * 1.06).round();
  Macros get macros => _sumMacros(items);

  static MealAnalysis get sample => demo(MealType.lunch);

  static MealAnalysis demo(MealType type) => MealAnalysis(
        type: type,
        isDemo: true,
        warning: 'زيت التحمير مش واضح في الصورة، راجع الكمية',
        items: [
          FoodItem(name: 'كشري', portion: 'طبق وسط · ٣٥٠ جم', kcal: 570, protein: 14, carbs: 88, fat: 12, fiber: 9, sugar: 6, sodium: 900, asset: FoodAssets.koshary, tag: 'عالية', tagColor:Colors.green),
          FoodItem(name: 'عيش بلدي', portion: 'نص رغيف · ٤٥ جم', kcal: 115, protein: 4, carbs: 22, fat: 1, fiber: 2, sugar: 0.5, sodium: 210, asset: FoodAssets.baladiBread),
          FoodItem(name: 'شاي بلبن', portion: 'كوباية · ٢ معلقة سكر', kcal: 145, protein: 6, carbs: 18, fat: 1, sugar: 15, sodium: 40, asset: FoodAssets.shaiLaban, tag: 'سكر', tagColor: AppColors.orange),
          FoodItem(name: 'زيت التحمير', portion: '١ معلقة أكل ≈ ١٠ جم', kcal: 90, fat: 10, tag: 'راجعه', tagColor: AppColors.orange, needsReview: true, confidence: Confidence.low),
        ],
      );
}

/// وجبة محفوظة في اليومية.
class LoggedMeal {
  LoggedMeal({
    String? id,
    required this.type,
    required this.title,
    required List<FoodItem> items,
    required this.time,
    this.favorite = false,
    this.photoPath,
  })  : id = id ?? newId(),
        items = List<FoodItem>.of(items);

  final String id;
  MealType type;
  String title;
  final List<FoodItem> items;
  final DateTime time;
  bool favorite;
  String? photoPath;

  int get kcal => items.fold(0, (s, e) => s + e.kcal);
  Macros get macros => _sumMacros(items);
  String? get mainAsset => photoPath ?? items.map((e) => e.asset).whereType<String>().firstOrNull;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'time': time.toIso8601String(),
        'favorite': favorite,
        'photo': photoPath,
        'items': items.map((e) => e.toJson()).toList(),
      };

  factory LoggedMeal.fromJson(Map<String, dynamic> j) => LoggedMeal(
        id: j['id'] as String?,
        type: MealTypeX.parse(j['type'] as String?),
        title: j['title'] as String? ?? '',
        time: DateTime.tryParse(j['time'] as String? ?? '') ?? DateTime.now(),
        favorite: j['favorite'] as bool? ?? false,
        photoPath: j['photo'] as String?,
        items: [for (final e in (j['items'] as List? ?? const [])) FoodItem.fromJson(Map<String, dynamic>.from(e as Map))],
      );
}

class ProductAlternative {
  const ProductAlternative({required this.name, required this.kcal, required this.grade, required this.asset, this.allergens = const {}});
  final String name;
  final int kcal;
  final String grade;
  final String asset;
  final Set<String> allergens; // وسوم Open Food Facts مثل en:peanuts

  static const catalog = [
    ProductAlternative(name: 'تمر محشي لوز', kcal: 180, grade: 'A', asset: FoodAssets.datesAlmond, allergens: {'en:nuts'}),
    ProductAlternative(name: 'تفاح وزبدة فول', kcal: 160, grade: 'B', asset: FoodAssets.applePb, allergens: {'en:peanuts'}),
  ];
}

class Product {
  const Product({
    required this.barcode,
    required this.name,
    required this.category,
    this.kcalPer100,
    this.protein100 = 0,
    this.carbs100 = 0,
    this.fat100 = 0,
    this.sugar100 = 0,
    this.fiber100 = 0,
    this.sodium100 = 0,
    this.defaultGrams = 100,
    this.image,
    this.nutriScore,
    required this.summaryTag,
    this.allergenWarning,
    this.alternatives = const [],
    this.isDemo = false,
  });

  final String barcode, name, category;
  final int? kcalPer100;
  final double protein100, carbs100, fat100, sugar100, fiber100, sodium100; // لكل ١٠٠ جم (الصوديوم ملجم)
  final int defaultGrams;
  final String? image; // asset أو رابط
  final String? nutriScore; // A..E أو null لو مش متاح
  final String summaryTag;
  final String? allergenWarning;
  final List<ProductAlternative> alternatives;
  final bool isDemo;

  FoodItem toFoodItem(int grams) {
    final f = grams / 100;
    return FoodItem(
      name: name,
      portion: '${ar(grams)} جم',
      kcal: ((kcalPer100 ?? 0) * f).round(),
      protein: protein100 * f,
      carbs: carbs100 * f,
      fat: fat100 * f,
      fiber: fiber100 * f,
      sugar: sugar100 * f,
      sodium: sodium100 * f,
      grams: grams,
      asset: image,
    );
  }

  static const demo = Product(
    barcode: '6221031000010',
    name: 'شيبسي ملح',
    category: 'سناك',
    kcalPer100: 530,
    protein100: 6,
    carbs100: 52,
    fat100: 33,
    sugar100: 1,
    sodium100: 600,
    image: FoodAssets.chips,
    nutriScore: 'E',
    summaryTag: 'سكر ودهون عالية',
    allergenWarning: 'يحتوي مكسرات — يتعارض مع حساسيتك',
    alternatives: ProductAlternative.catalog,
    isDemo: true,
  );
}
