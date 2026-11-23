
import 'package:flutter/material.dart';
import 'package:sofrah_project/screens/nutrition_summary_screen.dart';

import '../core/app_theme.dart';
import '../widgets/glass_widgets.dart';

class GoalSelectionScreen extends StatefulWidget {
  const GoalSelectionScreen({super.key});

  @override
  State<GoalSelectionScreen> createState() => _GoalSelectionScreenState();
}

class _GoalSelectionScreenState extends State<GoalSelectionScreen> {
  String? selectedGoal;

  final List<Map<String, dynamic>> goals = [
    {
      'id': 'lose',
      'title': 'خسارة الوزن',
      'subtitle': 'عايز أخس وأوصل لوزن صحي',
      'icon': Icons.trending_down,
      'color': const Color(0xFFFF9800),
    },
    {
      'id': 'maintain',
      'title': 'الحفاظ على الوزن',
      'subtitle': 'عايز أحافظ على وزني الحالي',
      'icon': Icons.balance,
      'color': const Color(0xFF38D6F5),
    },
    {
      'id': 'gain',
      'title': 'زيادة الوزن',
      'subtitle': 'عايز أزيد وزني بطريقة صحية',
      'icon': Icons.trending_up,
      'color': const Color(0xFF9C7BFF),
    },
  ];

  void goToNutritionSummary() {
    if (selectedGoal == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NutritionSummaryScreen(
          selectedGoal: selectedGoal!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          child: Padding(
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
                      '06 / 09',
                      style: AppText.body(
                        14,
                        color: AppColors.textSoft,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 35),

                Text(
                  'خلينا نحدد هدفك!',
                  style: AppText.title(30),
                ),

                const SizedBox(height: 12),

                Text(
                  'إيه هدفك من استخدام سفرة؟',
                  style: AppText.body(
                    16,
                    color: AppColors.textSoft,
                  ),
                ),

                const SizedBox(height: 35),

                ...goals.map((goal) {
                  final isSelected = selectedGoal == goal['id'];
                  final goalColor = goal['color'] as Color;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedGoal = goal['id'] as String;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? goalColor.withValues(alpha: 0.15)
                              : AppColors.glass,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isSelected
                                ? goalColor
                                : AppColors.glassBorder,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 55,
                              height: 55,
                              decoration: BoxDecoration(
                                color: goalColor.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                goal['icon'] as IconData,
                                color: goalColor,
                                size: 30,
                              ),
                            ),

                            const SizedBox(width: 16),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    goal['title'] as String,
                                    style: AppText.body(
                                      18,
                                      weight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    goal['subtitle'] as String,
                                    style: AppText.body(
                                      13,
                                      color: AppColors.textSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: isSelected
                                  ? goalColor
                                  : AppColors.textSoft,
                              size: 25,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                const Spacer(),

                GradientButton(
                  text: 'التالي',
                  onPressed:
                      selectedGoal == null ? null : goToNutritionSummary,
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
