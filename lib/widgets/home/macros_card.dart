
import 'package:flutter/material.dart';
import 'package:sofrah_project/services/meal_service.dart';

import '../../core/app_theme.dart';

class MacrosCard extends StatelessWidget {
  const MacrosCard({super.key});

  @override
  Widget build(BuildContext context) {
    final mealService = MealService();

    return StreamBuilder(
      stream: mealService.getTodayMeals(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('حدث خطأ في تحميل العناصر الغذائية');
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        double totalProtein = 0;
        double totalCarbs = 0;
        double totalFat = 0;

        for (final meal in snapshot.data!.docs) {
          final data = meal.data();

          totalProtein +=
              (data['protein'] as num?)?.toDouble() ?? 0;

          totalCarbs +=
              (data['carbs'] as num?)?.toDouble() ?? 0;

          totalFat +=
              (data['fat'] as num?)?.toDouble() ?? 0;
        }

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
                'البروتين',
                style: AppText.body(14),
              ),
              const SizedBox(height: 8),
              _buildMacroRow(
                'البروتين',
                totalProtein,
                110,
                Colors.cyan,
              ),
              const SizedBox(height: 18),
              _buildMacroRow(
                'الكربوهيدرات',
                totalCarbs,
                250,
                Colors.orange,
              ),
              const SizedBox(height: 18),
              _buildMacroRow(
                'الدهون',
                totalFat,
                70,
                Colors.pinkAccent,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMacroRow(
    String title,
    double current,
    double goal,
    Color color,
  ) {
    final progress = (current / goal).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${current.toStringAsFixed(1)} / ${goal.toStringAsFixed(0)} جم',
              style: AppText.body(13),
            ),
            Text(
              title,
              style: AppText.body(14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 9,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}
