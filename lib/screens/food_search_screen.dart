
import 'package:flutter/material.dart';
import 'package:sofrah_project/services/favorite_service.dart';
import 'package:sofrah_project/services/food_service.dart';
import 'package:sofrah_project/widgets/FoodSearchScreen/custom_food_dialog.dart';
import 'package:sofrah_project/widgets/FoodSearchScreen/food_search_widgets.dart';

import '../core/app_theme.dart';


class FoodSearchScreen extends StatefulWidget {
  const FoodSearchScreen({super.key});

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final FoodService foodService = FoodService();
  final FavoriteService favoriteService = FavoriteService();
  final TextEditingController searchController = TextEditingController();

  int selectedCategory = 0;

  final List<String> categories = [
    'الكل',
    'أكل مصري',
    'منتجات',
    'وصفات',
  ];

  final Map<String, IconData> foodIcons = {
    'كشري': Icons.rice_bowl,
    'فول مدمس': Icons.soup_kitchen,
    'طعمية': Icons.lunch_dining,
    'ملوخية': Icons.ramen_dining,
    'بيض مسلوق': Icons.egg_alt,
    'زبادي': Icons.icecream,
  };

  final Map<String, String> foodDescriptions = {
    'كشري': 'طبق رئيسي',
    'فول مدمس': 'فطار',
    'طعمية': 'فطار',
    'ملوخية': 'طبق رئيسي',
    'بيض مسلوق': 'فطار',
    'زبادي': 'منتج ألبان',
  };

  List<Map<String, dynamic>> filterFoods(
    List<Map<String, dynamic>> foods,
  ) {
    final query = searchController.text.trim().toLowerCase();

    return foods.where((food) {
      final arabicName = (food['name'] ?? '').toString().toLowerCase();
      final englishName = (food['name_en'] ?? '').toString().toLowerCase();

      final matchesSearch =
          arabicName.contains(query) || englishName.contains(query);

      final matchesCategory = selectedCategory == 0 ||
          food['category'] == categories[selectedCategory];

      return matchesSearch && matchesCategory;
    }).map((food) {
      final name = food['name'].toString();

      return {
        ...food,
        'description': foodDescriptions[name] ?? 'وجبة',
        'icon': foodIcons[name] ?? Icons.restaurant,
      };
    }).toList();
  }

  void addFood(Map<String, dynamic> food) {
    Navigator.pop(context, food);
  }

  Future<void> addCustomFood() async {
    final food = await CustomFoodDialog.show(
      context,
      initialName: searchController.text.trim(),
    );

    if (food != null && mounted) {
      addFood(food);
    }
  }

  Future<void> toggleFavorite(Map<String, dynamic> food) async {
    try {
      final added = await favoriteService.toggleFavorite(
        name: food['name'].toString(),
        calories: (food['calories'] as num).toInt(),
        protein: (food['protein'] as num?)?.toDouble() ?? 0,
        carbs: (food['carbs'] as num?)?.toDouble() ?? 0,
        fat: (food['fat'] as num?)?.toDouble() ?? 0,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            added
                ? 'تمت الإضافة للمفضلة ❤️'
                : 'تمت إزالة الوجبة من المفضلة',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حصل خطأ: $e')),
      );
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: foodService.getFoods(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text(
                'حصل خطأ في تحميل الأطعمة',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final results = filterFoods(snapshot.data ?? []);

        return Scaffold(
          backgroundColor: AppColors.bgDark,
          body: SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: -90,
                  left: -70,
                  child: FoodSearchWidgets.glow(
                    const Color(0xFF6536B7),
                  ),
                ),
                Positioned(
                  bottom: -80,
                  right: -80,
                  child: FoodSearchWidgets.glow(
                    const Color(0xFF087EAA),
                  ),
                ),
                Column(
                  children: [
                    _buildHeader(),
                    _buildSearchField(),
                    const SizedBox(height: 14),
                    FoodSearchWidgets.categorySelector(
                      categories: categories,
                      selectedCategory: selectedCategory,
                      onSelected: (index) {
                        setState(() {
                          selectedCategory = index;
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: _buildResults(results),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_forward,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          Text(
            'دور على أكلك...',
            style: AppText.title(22),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: TextField(
        controller: searchController,
        textAlign: TextAlign.right,
        style: AppText.body(14),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'دور على أكلة...',
          hintStyle: AppText.body(
            13,
            color: AppColors.textSoft,
          ),
          suffixIcon: const Icon(
            Icons.search,
            color: AppColors.cyan,
          ),
          filled: true,
          fillColor: const Color(0xFF202D50),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: AppColors.cyan),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: AppColors.cyan),
          ),
        ),
      ),
    );
  }

  Widget _buildResults(List<Map<String, dynamic>> results) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            selectedCategory == 0
                ? 'أكل مصري'
                : categories[selectedCategory],
            style: AppText.title(21),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF202D50),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white24),
          ),
          child: results.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'مفيش نتائج مطابقة للبحث',
                    textAlign: TextAlign.center,
                    style: AppText.body(
                      14,
                      color: AppColors.textSoft,
                    ),
                  ),
                )
              : Column(
                  children: results.map((food) {
                    return FoodSearchWidgets.foodItem(
                      food: food,
                      onAdd: () => addFood(food),
                      onFavorite: () => toggleFavorite(food),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: addCustomFood,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF202D50),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.cyan.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              children: [
                Text(
                  'مش لاقيين الأكلة؟',
                  style: AppText.body(
                    13,
                    color: AppColors.textSoft,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'ضيفها بنفسك',
                  style: AppText.title(
                    19,
                    color: AppColors.cyan,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
