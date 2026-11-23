import 'package:flutter/material.dart';
import 'package:sofrah_project/services/favorite_service.dart';
import 'package:sofrah_project/services/meal_service.dart';

import '../core/app_theme.dart';
import '../screens/add_food_screen/add_options_sheet.dart';
import '../services/arabic_digits.dart';
import '../services/diary_controller.dart';
import '../services/models.dart';
import '../widgets/diary_widget/bottom_bar.dart';
import '../widgets/home/featured_meal_card.dart';
import '../widgets/home/home_header.dart';
import 'diary_screen.dart';
import 'food_search_screen.dart';
import 'nutrition_summary_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;

  final FavoriteService favoriteService = FavoriteService();
  final MealService mealService = MealService();
  final DiaryController _diary = DiaryController.instance;

  @override
  void initState() {
    super.initState();
    _diary.addListener(_onDiaryChanged);
  }

  @override
  void dispose() {
    _diary.removeListener(_onDiaryChanged);
    super.dispose();
  }

  void _onDiaryChanged() {
    if (mounted) setState(() {});
  }

  // فتح البحث واستقبال الوجبة وحفظها في Firebase
  Future<void> openFoodSearch() async {
    final food = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const FoodSearchScreen(),
    ),
    );

    if (food == null || !mounted) return;

    try {
      await mealService.addMeal(
        name: food['name'].toString(),
        calories: (food['calories'] as num).toInt(),
        protein: (food['protein'] as num?)?.toDouble() ?? 0,
        carbs: (food['carbs'] as num?)?.toDouble() ?? 0,
        fat: (food['fat'] as num?)?.toDouble() ?? 0,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تمت إضافة الوجبة إلى يومياتك بنجاح ❤️'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل إضافة الوجبة: $e'),
        ),
      );
    }
  }

  // التنقل بين الشاشات
  void onNavigationSelected(int index) {
    if (index == 0) {
      setState(() {
        selectedIndex = 0;
      });
      return;
    }

    if (index == 2) {
      openFoodSearch();
      return;
    }

    Widget? screen;

    switch (index) {
      case 1:
        screen = const DiaryScreen();
        break;

      case 3:
        screen = NutritionSummaryScreen();
        break;

      case 4:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('شاشة حسابي لم يتم تنفيذها بعد'),
          ),
        );
        return;
    }

    setState(() {
      selectedIndex = index;
    });

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen!),
    ).then((_) {
      if (!mounted) return;

      setState(() {
        selectedIndex = 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final dayMeals = [
      for (final t in MealType.values) ..._diary.byType(t),
    ];
    final totalKcal = _diary.totalKcal + _diary.draftKcalOn(_diary.selectedDay);
    final totalProtein = dayMeals.fold<int>(0, (s, m) => s + m.macros.protein);
    final totalCarbs = dayMeals.fold<int>(0, (s, m) => s + m.macros.carbs);
    final totalFat = dayMeals.fold<int>(0, (s, m) => s + m.macros.fat);
    final remainingKcal =
    (DiaryController.dailyGoal - totalKcal).clamp(0, DiaryController.dailyGoal);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const HomeHeader(),

              const SizedBox(height: 25),

              // البحث عن الوجبات
              TextField(
                onTap: openFoodSearch,
                readOnly: true,
                textAlign: TextAlign.right,
                style: AppText.body(14),
                decoration: InputDecoration(
                  hintText: 'ابحث عن وجبتك المفضلة...',
                  hintStyle: AppText.body(
                    13,
                    color: AppColors.textSoft,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.cyan,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF17213D),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 22),

              const FeaturedMealCard(),

              const SizedBox(height: 25),

              Text(
                'ملخص يومك',
                style: AppText.title(20),
              ),

              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF17213D),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('سعرة حرارية', style: AppText.body(14)),
                        Text(
                          '${ar(totalKcal)} / ${arThousands(DiaryController.dailyGoal)}',
                          style: AppText.body(
                            18,
                            weight: FontWeight.w700,
                            color: AppColors.cyan,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'متبقي ${ar(remainingKcal)} سعرة حرارية',
                      style: AppText.body(12, color: AppColors.textSoft),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              Text(
                'العناصر الغذائية',
                style: AppText.title(20),
              ),

              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF17213D),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('البروتين', style: AppText.body(14)),
                        Text(
                          '${ar(totalProtein)} جم',
                          style: AppText.body(
                            14,
                            weight: FontWeight.w700,
                            color: AppColors.cyan,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('الكربوهيدرات', style: AppText.body(14)),
                        Text(
                          '${ar(totalCarbs)} جم',
                          style: AppText.body(
                            14,
                            weight: FontWeight.w700,
                            color: AppColors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('الدهون', style: AppText.body(14)),
                        Text(
                          '${ar(totalFat)} جم',
                          style: AppText.body(
                            14,
                            weight: FontWeight.w700,
                            color: AppColors.textSoft,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              Text(
                'وجباتك المفضلة',
                style: AppText.title(20),
              ),

              const SizedBox(height: 14),

              // الوجبات المفضلة من Firebase
              StreamBuilder(
                stream: favoriteService.getFavorites(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text(
                      'حصل خطأ في تحميل المفضلة',
                      style: AppText.body(
                        13,
                        color: Colors.redAccent,
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final favorites = snapshot.data!.docs;

                  if (favorites.isEmpty) {
                    return Text(
                      'لسه مفيش وجبات في المفضلة ❤️',
                      style: AppText.body(
                        13,
                        color: AppColors.textSoft,
                      ),
                    );
                  }

                  return Column(
                    children: favorites.map((favorite) {
                      final food = favorite.data();

                      return Card(
                        color: const Color(0xFF17213D),
                        child: ListTile(
                          title: Text(
                            food['name']?.toString() ?? '',
                            style: AppText.body(14),
                          ),
                          subtitle: Text(
                            '${food['calories'] ?? 0} سعر حراري',
                            style: AppText.body(
                              12,
                              color: AppColors.textSoft,
                            ),
                          ),
                          leading: const Icon(
                            Icons.favorite,
                            color: Colors.redAccent,
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                            ),
                            onPressed: () async {
                              try {
                                await favoriteService.deleteFavorite(
                                  favorite.id,
                                );
                              } catch (e) {
                                if (!context.mounted) return;

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'تعذر حذف الوجبة من المفضلة',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),

      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 30, 12, 8),
          child: SufraBottomBar(
            current: 'main',
            onAdd: () => showAddOptions(context),
          ),
        ),
      ),
    );
  }
}