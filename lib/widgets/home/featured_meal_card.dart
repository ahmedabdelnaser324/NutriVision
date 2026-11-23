
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

class FeaturedMealCard extends StatelessWidget {
  const FeaturedMealCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF123D3D),
            Color(0xFF063A4A),
            Color(0xFF17334A),
          ],
        ),
        border: Border.all(
          color: AppColors.orange,
          width: 0.7,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: AppColors.orange,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Text(
              'سفرة: اختيارات أذكى',
              style: AppText.body(
                12,
                color: Colors.black,
                weight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'كُل بتحب،',
            style: AppText.title(23),
          ),

          Text(
            'وتوازن يناسبك',
            style: AppText.title(
              22,
              color: AppColors.orange,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'نظم وجباتك ووصفاتك بالذكاء الاصطناعي من غير حرمان.',
            textAlign: TextAlign.right,
            style: AppText.body(
              12,
              color: AppColors.textSoft,
            ),
          ),

          const SizedBox(height: 15),

          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.black,
              ),
              child: const Text('خطط وجباتك ←'),
            ),
          ),
        ],
      ),
    );
  }
}
