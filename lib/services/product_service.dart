import 'package:dio/dio.dart';
import '../services/models.dart';
import 'api_client.dart';

/// استعلام المنتجات بالباركود من Open Food Facts (مجاني، بدون مفتاح).
class ProductService {
  ProductService({Dio? dio})
      : _dio = dio ??
            ApiClient.create(
              baseUrl: 'https://world.openfoodfacts.org',
              headers: {'User-Agent': 'Sufra/1.0 (student project)'},
            );

  final Dio _dio;

  static const _fields = 'code,product_name,product_name_ar,generic_name,brands,nutriments,nutriscore_grade,'
      'image_front_url,image_url,allergens_tags,traces_tags,serving_quantity';

  /// null = المنتج مش موجود. بيرمي ApiException لو الشبكة وقعت.
  Future<Product?> fetch(String barcode, {Set<String> allergies = const {}}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v2/product/$barcode.json',
        queryParameters: {'fields': _fields},
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
      final data = res.data;
      if (data == null) return null;
      return parse(data, barcode, allergies: allergies);
    } on DioException catch (e) {
      throw ApiException(ApiClient.messageOf(e));
    }
  }

  static const _allergenAr = {
    'en:nuts': 'مكسرات',
    'en:peanuts': 'فول سوداني',
    'en:milk': 'لبن',
    'en:gluten': 'جلوتين',
    'en:eggs': 'بيض',
    'en:soybeans': 'صويا',
    'en:fish': 'سمك',
    'en:sesame-seeds': 'سمسم',
  };

  static Product? parse(Map<String, dynamic> json, String barcode, {Set<String> allergies = const {}}) {
    final p = json['product'];
    if (json['status'] != 1 || p is! Map) return null;
    final m = Map<String, dynamic>.from(p);

    String? first(List<String> keys) {
      for (final k in keys) {
        final v = (m[k] as String?)?.trim();
        if (v != null && v.isNotEmpty) return v;
      }
      return null;
    }

    final nutr = Map<String, dynamic>.from(m['nutriments'] as Map? ?? const {});
    double? n(String k) {
      final v = nutr[k];
      if (v == null) return null;
      return v is num ? v.toDouble() : double.tryParse('$v');
    }

    final kcal = n('energy-kcal_100g') ?? (n('energy_100g') != null ? n('energy_100g')! / 4.184 : null);
    final sodiumG = n('sodium_100g') ?? ((n('salt_100g') ?? 0) / 2.5);
    final sugar = n('sugars_100g') ?? 0, fat = n('fat_100g') ?? 0, salt = n('salt_100g') ?? sodiumG * 2.5;

    final g = (m['nutriscore_grade'] as String?)?.toUpperCase();
    final grade = g != null && const ['A', 'B', 'C', 'D', 'E'].contains(g) ? g : null;

    final highs = [if (sugar > 15) 'سكر', if (fat > 17.5) 'دهون', if (salt > 1.5) 'ملح'];
    final summary = highs.isNotEmpty
        ? '${highs.join(' و')} ${highs.length > 1 ? 'عالية' : 'عالي'}'
        : (grade == 'A' || grade == 'B') ? 'اختيار كويس' : 'متوسط';

    final tags = <String>{
      ...List<String>.from(m['allergens_tags'] as List? ?? const []),
      ...List<String>.from(m['traces_tags'] as List? ?? const []),
    };
    final hit = allergies.where(tags.contains).toList();
    final warning = hit.isEmpty ? null : 'يحتوي ${hit.map((t) => _allergenAr[t] ?? t.split(':').last).join(' و')} — يتعارض مع حساسيتك';

    final bad = grade == 'D' || grade == 'E' || highs.length >= 2;
    final alts = bad ? ProductAlternative.catalog.where((a) => a.allergens.intersection(allergies).isEmpty).toList() : <ProductAlternative>[];

    final serving = double.tryParse('${m['serving_quantity']}');
    final brand = (m['brands'] as String?)?.split(',').first.trim();

    return Product(
      barcode: barcode,
      name: first(['product_name_ar', 'product_name', 'generic_name']) ?? 'منتج بدون اسم',
      category: (brand == null || brand.isEmpty) ? 'منتج' : brand,
      kcalPer100: kcal?.round(),
      protein100: n('proteins_100g') ?? 0,
      carbs100: n('carbohydrates_100g') ?? 0,
      fat100: fat,
      sugar100: sugar,
      fiber100: n('fiber_100g') ?? 0,
      sodium100: sodiumG * 1000,
      defaultGrams: serving != null && serving > 0 && serving <= 1000 ? serving.round() : 100,
      image: first(['image_front_url', 'image_url']),
      nutriScore: grade,
      summaryTag: summary,
      allergenWarning: warning,
      alternatives: alts,
    );
  }
}
