
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:sofrah_project/services/meal_service.dart';

import '../core/app_theme.dart';

class MealHistorySection extends StatelessWidget {
  final MealService mealService;
  final VoidCallback onDeleteError;

  const MealHistorySection({
    super.key,
    required this.mealService,
    required this.onDeleteError,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: mealService.getMeals(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return const Text(
            'حدث خطأ أثناء تحميل الوجبات',
            style: TextStyle(color: Colors.white),
          );
        }

        final meals = snapshot.data?.docs ?? [];

        if (meals.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'لسه مسجلتش أي وجبات',
              style: AppText.body(
                13,
                color: AppColors.textSoft,
              ),
            ),
          );
        }

        final totalCalories = meals.fold<int>(
          0,
          (sum, meal) =>
              sum +
              ((meal.data()['calories'] as num?)?.toInt() ?? 0),
        );

        return Column(
          children: [
            ...meals.map((meal) {
              final data = meal.data();

              return Card(
                color: const Color(0xFF202D50),
                child: ListTile(
                  title: Text(
                    data['name']?.toString() ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    '${data['calories'] ?? 0} سعرة حرارية',
                    style: const TextStyle(
                      color: Colors.white70,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => _deleteMeal(meal.id),
                  ),
                ),
              );
            }),
            Card(
              color: const Color(0xFF202D50),
              child: ListTile(
                title: const Text(
                  'إجمالي السعرات',
                  style: TextStyle(color: Colors.white),
                ),
                trailing: Text(
                  '$totalCalories سعرة',
                  style: const TextStyle(
                    color: AppColors.orange,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteMeal(String mealId) async {
    try {
      await mealService.deleteMeal(mealId);
    } catch (_) {
      onDeleteError();
    }
  }
}
