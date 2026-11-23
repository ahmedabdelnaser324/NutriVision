import 'package:flutter/material.dart';
import 'package:sofrah_project/screens/home_screen.dart';

import '../core/app_theme.dart';
import '../services/arabic_digits.dart';
import '../services/diary_controller.dart';
import '../services/models.dart';
import '../widgets/glass_widgets.dart';

class NutritionSummaryScreen extends StatefulWidget {
  final String selectedGoal;

  const NutritionSummaryScreen({super.key, this.selectedGoal = 'maintain'});

  @override
  State<NutritionSummaryScreen> createState() => _NutritionSummaryScreenState();
}

class _NutritionSummaryScreenState extends State<NutritionSummaryScreen> {
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

  String get goalTitle {
    switch (widget.selectedGoal) {
      case 'lose':
        return 'خسارة الوزن';
      case 'gain':
        return 'زيادة الوزن';
      default:
        return 'الحفاظ على الوزن';
    }
  }

  String get goalDescription {
    switch (widget.selectedGoal) {
      case 'lose':
        return 'خطة غذائية تساعدك على خسارة الوزن بطريقة صحية';
      case 'gain':
        return 'خطة غذائية تساعدك على زيادة الوزن بطريقة صحية';
      default:
        return 'خطة غذائية تساعدك على الحفاظ على وزنك الحالي';
    }
  }

  int get dailyCalories {
    switch (widget.selectedGoal) {
      case 'lose':
        return 1800;
      case 'gain':
        return 2600;
      default:
        return 2200;
    }
  }

  int get protein {
    switch (widget.selectedGoal) {
      case 'lose':
        return 120;
      case 'gain':
        return 130;
      default:
        return 110;
    }
  }

  int get carbs {
    switch (widget.selectedGoal) {
      case 'lose':
        return 180;
      case 'gain':
        return 320;
      default:
        return 250;
    }
  }

  int get fat {
    switch (widget.selectedGoal) {
      case 'lose':
        return 60;
      case 'gain':
        return 75;
      default:
        return 70;
    }
  }

  double _progress(double current, double target) {
    if (target <= 0) return 0;
    return (current / target).clamp(0.0, 1.0);
  }

  Widget _macroCard({
    required String title,
    required String amount,
    required String unit,
    required double progress,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 27),
            const SizedBox(height: 12),
            Text(title, style: AppText.body(14, color: AppColors.textSoft)),
            const SizedBox(height: 12),
            SizedBox(
              width: 65,
              height: 65,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 6,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  FittedBox(
                    child: Text(
                      amount,
                      style: AppText.body(15, weight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              unit,
              textAlign: TextAlign.center,
              style: AppText.body(11, color: AppColors.textSoft),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayMeals = [
      for (final t in MealType.values) ..._diary.byType(t),
    ];
    final totalCalories =
    (_diary.totalKcal + _diary.draftKcalOn(_diary.selectedDay)).toDouble();
    final totalProtein =
    dayMeals.fold<int>(0, (s, m) => s + m.macros.protein).toDouble();
    final totalCarbs =
    dayMeals.fold<int>(0, (s, m) => s + m.macros.carbs).toDouble();
    final totalFat =
    dayMeals.fold<int>(0, (s, m) => s + m.macros.fat).toDouble();

    final calorieProgress = _progress(
      totalCalories,
      dailyCalories.toDouble(),
    );
    final remainingKcal =
    (dailyCalories - totalCalories).clamp(0, dailyCalories.toDouble());

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color(0xFF101B3A),
              AppColors.bgDark,
              Color(0xFF08152D),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${ar(7)} / ${ar(9)}',
                      style: AppText.body(14, color: AppColors.textSoft),
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                Text('خطة التغذية بتاعتك', style: AppText.title(28)),

                const SizedBox(height: 10),

                Text(
                  goalDescription,
                  style: AppText.body(15, color: AppColors.textSoft),
                ),

                const SizedBox(height: 28),

                GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        color: AppColors.orange,
                        size: 42,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'السعرات الحرارية اليومية',
                        style: AppText.body(
                          16,
                          color: AppColors.textSoft,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ar(totalCalories.round()),
                        style: AppText.title(42, color: AppColors.orange),
                      ),
                      Text(
                        'من ${ar(dailyCalories)} سعرة حرارية',
                        style: AppText.body(
                          14,
                          color: AppColors.textSoft,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: calorieProgress,
                          minHeight: 10,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.orange,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        totalCalories >= dailyCalories
                            ? 'وصلت لهدفك اليومي ❤️'
                            : 'متبقي ${ar(remainingKcal.round())} سعرة حرارية',
                        style: AppText.body(
                          13,
                          color: AppColors.textSoft,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                Text('توزيع العناصر الغذائية', style: AppText.title(21)),

                const SizedBox(height: 16),

                Row(
                  children: [
                    _macroCard(
                      title: 'بروتين',
                      amount: ar(totalProtein.round()),
                      unit: 'من ${ar(protein)} جرام',
                      progress: _progress(
                        totalProtein,
                        protein.toDouble(),
                      ),
                      color: AppColors.cyan,
                      icon: Icons.fitness_center,
                    ),
                    const SizedBox(width: 10),
                    _macroCard(
                      title: 'كربوهيدرات',
                      amount: ar(totalCarbs.round()),
                      unit: 'من ${ar(carbs)} جرام',
                      progress: _progress(totalCarbs, carbs.toDouble()),
                      color: AppColors.orange,
                      icon: Icons.grain,
                    ),
                    const SizedBox(width: 10),
                    _macroCard(
                      title: 'دهون',
                      amount: ar(totalFat.round()),
                      unit: 'من ${ar(fat)} جرام',
                      progress: _progress(totalFat, fat.toDouble()),
                      color: const Color(0xFFB388FF),
                      icon: Icons.water_drop,
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                GlassCard(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.flag_outlined,
                        color: AppColors.orange,
                        size: 35,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'رحلتك لهدفك',
                              style: AppText.body(
                                17,
                                weight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              goalTitle,
                              style: AppText.body(
                                12,
                                color: AppColors.textSoft,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'حوالي ${ar(3)} شهور',
                              style: AppText.title(
                                22,
                                color: AppColors.cyan,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                GradientButton(
                  text: 'التالي',
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}