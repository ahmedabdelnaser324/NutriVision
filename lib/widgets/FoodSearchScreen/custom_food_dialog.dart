
import 'package:flutter/material.dart';
import 'package:sofrah_project/core/app_theme.dart';


class CustomFoodDialog {
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    String initialName = '',
  }) async {
    final nameController = TextEditingController(text: initialName);
    final caloriesController = TextEditingController();
    final proteinController = TextEditingController();
    final carbsController = TextEditingController();
    final fatController = TextEditingController();

    try {
      return await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: const Color(0xFF202D50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Text(
              'إضافة أكلة جديدة',
              textAlign: TextAlign.right,
              style: AppText.title(21),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _manualField(
                    controller: nameController,
                    label: 'اسم الأكلة',
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 12),
                  _manualField(
                    controller: caloriesController,
                    label: 'السعرات الحرارية (مطلوب)',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  _manualField(
                    controller: proteinController,
                    label: 'البروتين بالجرام',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  _manualField(
                    controller: carbsController,
                    label: 'الكربوهيدرات بالجرام',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  _manualField(
                    controller: fatController,
                    label: 'الدهون بالجرام',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  'إلغاء',
                  style: AppText.body(
                    14,
                    color: AppColors.textSoft,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cyan,
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  final name = nameController.text.trim();
                  final calories = int.tryParse(
                    caloriesController.text.trim(),
                  );

                  if (name.isEmpty || calories == null || calories < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'اكتب اسم الأكلة والسعرات بشكل صحيح',
                        ),
                      ),
                    );
                    return;
                  }

                  double readMacro(TextEditingController controller) {
                    return double.tryParse(controller.text.trim()) ?? 0;
                  }

                  Navigator.pop(dialogContext, {
                    'name': name,
                    'description': 'إضافة يدوية',
                    'calories': calories,
                    'protein': readMacro(proteinController),
                    'carbs': readMacro(carbsController),
                    'fat': readMacro(fatController),
                    'category': 'مخصص',
                    'icon': Icons.restaurant,
                  });
                },
                child: const Text('إضافة الأكلة'),
              ),
            ],
          );
        },
      );
    } finally {
      nameController.dispose();
      caloriesController.dispose();
      proteinController.dispose();
      carbsController.dispose();
      fatController.dispose();
    }
  }

  static Widget _manualField({
    required TextEditingController controller,
    required String label,
    required TextInputType keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textAlign: TextAlign.right,
      style: AppText.body(14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppText.body(
          12,
          color: AppColors.textSoft,
        ),
        filled: true,
        fillColor: const Color(0xFF172340),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: AppColors.cyan),
        ),
      ),
    );
  }
}
