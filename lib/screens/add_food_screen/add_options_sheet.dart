import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../widgets/diary_widget/sufra_dialogs.dart';
import '../../services/models.dart';
import '../../services/diary_controller.dart';
import 'food_search_sheet.dart';

/// "ضيف أكلة": اختيار الوجبة (فطار/غدا/عشا/سناك) + تصوير / باركود / بحث يدوي.
Future<void> showAddOptions(BuildContext context, {MealType? type}) async {
  try {
    final initialType = type ?? MealTypeX.byHour(DateTime.now().hour);
    final result = await showModalBottomSheet<_AddOptionSelection>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddOptionsBody(initialType: initialType),
    );
    if (result == null || !context.mounted) return;

    final chosenType = result.mealType;
    switch (result.choice) {
      case 'photo':
        Navigator.pushNamed(context, '/analyze', arguments: chosenType);
      case 'barcode':
        Navigator.pushNamed(context, '/barcode');
      case 'search':
        final item = await showFoodSearchSheet(context);
        if (item != null && context.mounted) {
          DiaryController.instance.addDraft(chosenType, item);
          showSufraSnack(context, 'اتضافت "${item.name}" لـ ${chosenType.label}');
        }
    }
  } catch (e, st) {
    debugPrint('showAddOptions failed: $e\n$st');
    if (context.mounted) showSufraSnack(context, 'خطأ: $e');
  }
}

class _AddOptionSelection {
  const _AddOptionSelection({required this.choice, required this.mealType});
  final String choice;
  final MealType mealType;
}

class _AddOptionsBody extends StatefulWidget {
  const _AddOptionsBody({required this.initialType});
  final MealType initialType;

  @override
  State<_AddOptionsBody> createState() => _AddOptionsBodyState();
}

class _AddOptionsBodyState extends State<_AddOptionsBody> {
  late MealType _selectedType = widget.initialType;

  Widget _option(BuildContext ctx, IconData icon, String label, String hint, String id) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.pop(
        ctx,
        _AddOptionSelection(choice: id, mealType: _selectedType),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .1),
                border: Border.all(color: Colors.white24),
              ),
              child: Icon(icon, color: AppColors.cyan),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppText.body(15, weight: FontWeight.w700)),
                  Text(hint, style: AppText.body(12, color: AppColors.textSoft)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Material(
          color: const Color(0xFF0E1630),
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('ضيف أكلة في أنهي وجبة؟', style: AppText.title(20)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in MealType.values)
                      GestureDetector(
                        onTap: () => setState(() => _selectedType = t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(99),
                            gradient: _selectedType == t
                                ? const LinearGradient(colors: [AppColors.cyan, AppColors.orange])
                                : null,
                            color: _selectedType == t
                                ? null
                                : Colors.white.withValues(alpha: .08),
                            border: Border.all(
                              color: _selectedType == t
                                  ? Colors.transparent
                                  : Colors.white.withValues(alpha: .22),
                            ),
                          ),
                          child: Text(
                            t.label,
                            style: AppText.body(
                              13,
                              weight: _selectedType == t ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _option(
                  context,
                  Icons.photo_camera_rounded,
                  'صوّر الطبق',
                  'الذكاء الاصطناعي يحسب السعرات',
                  'photo',
                ),
                _option(
                  context,
                  Icons.qr_code_scanner_rounded,
                  'امسح باركود',
                  'لمنتج معبّأ',
                  'barcode',
                ),
                _option(
                  context,
                  Icons.search_rounded,
                  'دوّر بالاسم',
                  'من قائمة الأكلات المصرية',
                  'search',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}