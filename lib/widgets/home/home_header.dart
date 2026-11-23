
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 24,
          backgroundColor: Color(0xFF26345A),
          child: Icon(
            Icons.notifications_none,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 12),

        const CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.orange,
          child: Icon(
            Icons.person,
            color: Colors.white,
            size: 34,
          ),
        ),

        const Spacer(),

        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'صباح الخير',
              style: AppText.body(
                13,
                color: AppColors.orange,
              ),
            ),
            Text(
              'أحمد',
              style: AppText.title(24),
            ),
          ],
        ),

        const SizedBox(width: 10),

        const Icon(
          Icons.restaurant,
          color: AppColors.cyan,
          size: 34,
        ),
      ],
    );
  }
}
