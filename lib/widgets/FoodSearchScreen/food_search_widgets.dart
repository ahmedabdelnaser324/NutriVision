
import 'package:flutter/material.dart';
import 'package:sofrah_project/core/app_theme.dart';

class FoodSearchWidgets {
  static Widget categorySelector({
    required List<String> categories,
    required int selectedCategory,
    required ValueChanged<int> onSelected,
  }) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        reverse: true,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = selectedCategory == index;

          return GestureDetector(
            onTap: () => onSelected(index),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.cyan
                    : const Color(0xFF26345A),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Text(
                categories[index],
                style: AppText.body(
                  12,
                  color: selected ? Colors.black : Colors.white,
                  weight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static Widget foodItem({
    required Map<String, dynamic> food,
    required VoidCallback onAdd,
    required VoidCallback onFavorite,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          GestureDetector(
            onTap: onAdd,
            child: const CircleAvatar(
              radius: 19,
              backgroundColor: Color(0xFF079BC8),
              child: Icon(
                Icons.add,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  food['name'].toString(),
                  style: AppText.title(17),
                ),
                Text(
                  '${food['description']} · ${food['calories']} سعرة',
                  style: AppText.body(
                    12,
                    color: AppColors.textSoft,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onFavorite,
            icon: const Icon(
              Icons.favorite_border,
              color: Colors.redAccent,
            ),
            tooltip: 'إضافة للمفضلة',
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 25,
            backgroundColor: const Color(0xFF354466),
            child: Icon(
              food['icon'] is IconData
                  ? food['icon'] as IconData
                  : Icons.restaurant,
              color: AppColors.orange,
              size: 27,
            ),
          ),
        ],
      ),
    );
  }

  static Widget glow(Color color) {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 100,
            spreadRadius: 35,
          ),
        ],
      ),
    );
  }
}
