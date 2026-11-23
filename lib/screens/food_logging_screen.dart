
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/models.dart';
import 'add_food_screen/food_search_sheet.dart';
import 'package:sofrah_project/screens/analyze_screen.dart';
import 'package:sofrah_project/screens/barcode_screen.dart';
import 'package:sofrah_project/services/favorite_service.dart';
import 'package:sofrah_project/services/meal_service.dart';
import 'package:sofrah_project/widgets/FoodLoggingScreen/food_logging_widgets.dart';
import 'package:sofrah_project/widgets/meal_history_section.dart';

import '../core/app_theme.dart';
import 'food_search_screen.dart';


class FoodLoggingScreen extends StatefulWidget {
  const FoodLoggingScreen({super.key});

  @override
  State<FoodLoggingScreen> createState() => _FoodLoggingScreenState();
}

class _FoodLoggingScreenState extends State<FoodLoggingScreen> {
  final MealService mealService = MealService();
  final FavoriteService favoriteService = FavoriteService();

  Future<void> saveFood(Map<String, dynamic> food) async {
    try {
      await mealService.addMeal(
        name: food['name'].toString(),
        calories: (food['calories'] as num?)?.toInt() ?? 0,
        protein: (food['protein'] as num?)?.toDouble() ?? 0,
        carbs: (food['carbs'] as num?)?.toDouble() ?? 0,
        fat: (food['fat'] as num?)?.toDouble() ?? 0,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تسجيل الوجبة بنجاح ❤️'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء تسجيل الوجبة: $e'),
        ),
      );
    }
  }

  Future<void> openFoodSearch() async {
    final FoodItem? item = await showFoodSearchSheet(context);
    if (item != null && mounted) {
      await saveFood({
        'name': item.name,
        'calories': item.kcal,
        'protein': 0,
        'carbs': 0,
        'fat': 0,
      });
    }
  }

  Future<void> openFavorites() async {
    final food = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: const Color(0xFF202D50),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.65,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Spacer(),
                      Text(
                        'وجباتك المفضلة ❤️',
                        style: AppText.title(21),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<
                      QuerySnapshot<Map<String, dynamic>>>(
                    stream: favoriteService.getFavorites(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'حدث خطأ أثناء تحميل المفضلة',
                            style: AppText.body(
                              14,
                              color: Colors.white,
                            ),
                          ),
                        );
                      }

                      final favorites = snapshot.data?.docs ?? [];

                      if (favorites.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.favorite_border,
                                color: AppColors.orange,
                                size: 55,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'لسه مفيش وجبات في المفضلة',
                                style: AppText.body(
                                  14,
                                  color: AppColors.textSoft,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'ضيف وجبات للمفضلة من شاشة البحث',
                                style: AppText.body(
                                  12,
                                  color: AppColors.textSoft,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: favorites.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final food = favorites[index].data();

                          return Card(
                            color: const Color(0xFF29395F),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: ListTile(
                              onTap: () {
                                Navigator.pop(sheetContext, food);
                              },
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFF873E70),
                                child: Icon(
                                  Icons.favorite,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                food['name']?.toString() ?? 'وجبة',
                                textAlign: TextAlign.right,
                                style: AppText.title(16),
                              ),
                              subtitle: Text(
                                '${food['calories'] ?? 0} سعرة حرارية',
                                textAlign: TextAlign.right,
                                style: AppText.body(
                                  12,
                                  color: AppColors.textSoft,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.add_circle_outline,
                                color: AppColors.cyan,
                                size: 27,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (food != null && mounted) {
      await saveFood(food);
    }
  }

  void showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature غير متاحة حاليًا'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -70,
              right: -70,
              child: FoodLoggingWidgets.glow(
                const Color(0xFF7437C8),
              ),
            ),
            Positioned(
              bottom: -70,
              left: -70,
              child: FoodLoggingWidgets.glow(
                const Color(0xFF087EAA),
              ),
            ),
            Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildTitle(),
                        const SizedBox(height: 28),

                        FoodLoggingWidgets.loggingOption(
                          title: 'بالصوت أو الكتابة',
                          subtitle: 'قول "طبقين كشري" وسفرة تحسبها',
                          icon: Icons.mic_none,
                          color: const Color(0xFF6536B7),
                          onTap: openFoodSearch,
                        ),

                        const SizedBox(height: 18),

                        Row(
                          children: [
                            Expanded(
                              child: FoodLoggingWidgets.loggingOption(
                                title: 'امسح باركود',
                                subtitle: 'منتج معبأ',
                                icon: Icons.qr_code_scanner,
                                color: const Color(0xFF9B5A20),
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_)=> const BarcodeScreen() ));
                                }
                                ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FoodLoggingWidgets.loggingOption(
                                title: 'صوّر وجبتك',
                                subtitle: 'تعرّف تلقائي',
                                icon: Icons.camera_alt_outlined,
                                color: const Color(0xFF087E9B),
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_)=> const AnalyzeScreen()));
                                }

                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: FoodLoggingWidgets.loggingOption(
                                title: 'من المفضلة',
                                subtitle: 'بلمسة واحدة',
                                icon: Icons.favorite_border,
                                color: const Color(0xFF873E70),
                                onTap: openFavorites,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FoodLoggingWidgets.loggingOption(
                                title: 'ابحث يدوياً',
                                subtitle: 'آلاف الأصناف',
                                icon: Icons.search,
                                color: const Color(0xFF16775D),
                                onTap: openFoodSearch,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        _buildRecentMealsHeader(),

                        const SizedBox(height: 12),

                        MealHistorySection(
                          mealService: mealService,
                          onDeleteError: () {
                            if (!mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تعذر حذف الوجبة'),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 25),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
          const Icon(
            Icons.wb_sunny_outlined,
            color: AppColors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'تسجل أكلك إزاي؟',
          style: AppText.title(29),
        ),
        const SizedBox(height: 8),
        Text(
          'اختار الطريقة الأنسب، وخليها لمسة واحدة',
          style: AppText.body(
            13,
            color: AppColors.textSoft,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentMealsHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF202D50),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFF34466B),
            child: Icon(
              Icons.restaurant,
              color: AppColors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'آخر وجباتك',
                  style: AppText.title(17),
                ),
                Text(
                  'سجل وجبتك التالية بسهولة',
                  style: AppText.body(
                    12,
                    color: AppColors.textSoft,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: openFoodSearch,
            child: const Text(
              'أعد التسجيل',
              style: TextStyle(color: AppColors.cyan),
            ),
          ),
        ],
      ),
    );
  }
}
