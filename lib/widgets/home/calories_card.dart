
import 'package:flutter/material.dart';
import 'package:sofrah_project/services/meal_service.dart';

import '../../core/app_theme.dart';

class CaloriesCard extends StatefulWidget {
  const CaloriesCard({super.key});

  @override
  State<CaloriesCard> createState() => _CaloriesCardState();
}

class _CaloriesCardState extends State<CaloriesCard> {
  final MealService mealService = MealService();

  final int dailyGoal = 2200;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: mealService.getTodayMeals(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('حدث خطأ في تحميل السعرات');
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final meals = snapshot.data!.docs;

        int totalCalories = 0;

        for (final meal in meals) {
          totalCalories +=
              (meal.data()['calories'] as num?)?.toInt() ?? 0;
        }

        final remaining =
            (dailyGoal - totalCalories).clamp(0, dailyGoal);

        final progress =
            (totalCalories / dailyGoal).clamp(0.0, 1.0);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF17213D),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'السعرات الحرارية',
                style: AppText.title(17),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$totalCalories / $dailyGoal',
                    style: AppText.title(20),
                  ),
                  Text(
                    'سعرة حرارية',
                    style: AppText.body(13),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation(
                    AppColors.cyan,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'متبقي $remaining سعرة حرارية',
                style: AppText.body(
                  13,
                  color: AppColors.textSoft,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
