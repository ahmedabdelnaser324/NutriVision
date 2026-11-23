
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

class HomeBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const HomeBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      Icons.home_outlined,
      Icons.restaurant_menu,
      Icons.add_circle_outline,
      Icons.bar_chart_outlined,
      Icons.person_outline,
    ];

    final labels = [
      'الرئيسية',
      'يومياتي',
      'إضافة',
      'تقدمي',
      'حسابي',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111A32),
        border: Border(
          top: BorderSide(color: AppColors.glassBorder),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (index) {
          final isSelected = selectedIndex == index;

          return GestureDetector(
            onTap: () => onItemSelected(index),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  items[index],
                  size: index == 2 ? 32 : 24,
                  color: isSelected ? AppColors.orange : AppColors.textSoft,
                ),
                const SizedBox(height: 4),
                Text(
                  labels[index],
                  style: AppText.body(
                    10,
                    color: isSelected ? AppColors.orange : AppColors.textSoft,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
