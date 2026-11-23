import 'package:flutter/material.dart';
import '../../services/models.dart';
import '../../core/app_theme.dart';
import '../../widgets/glass_widgets.dart';

/// رسالة سفلية بسيطة.
void showSufraSnack(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: const Color(0xFF16204A),
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
    duration: const Duration(seconds: 4),
    persist: false, // بدونها السناك بار اللي فيه زرار "تراجع" بيفضل ظاهر للأبد

    content: Text(message, style: AppText.body(14)),
    action: actionLabel == null ? null : SnackBarAction(label: actionLabel, textColor: AppColors.cyan, onPressed: onAction ?? () {}),
  ));
}

/// تأكيد بسيط (حذف مثلاً). بيرجّع true لو المستخدم وافق.
Future<bool> showConfirmSheet(BuildContext context, {required String title, String? message, String confirmLabel = 'حذف'}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + MediaQuery.of(ctx).padding.bottom),
      child: GlassCard(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, textAlign: TextAlign.center, style: AppText.title(20)),
          if (message != null) ...[const SizedBox(height: 6), Text(message, textAlign: TextAlign.center, style: AppText.body(12,color: AppColors.textSoft))],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: GradientButton(text:  confirmLabel, onPressed: () => Navigator.pop(ctx, true))),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx, false),
                child: Container(
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .1), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white24)),
                  child: Text('إلغاء', style: AppText.body(15, weight: FontWeight.w700)),
                ),
              ),
            ),
          ]),
        ]),
      ),
    ),
  );
  return ok ?? false;
}

/// يسأل: الأكلة دي لأنهي وجبة؟ (فطار/غدا/عشا/سناك). بيرجّع null لو اتلغى.
Future<MealType?> pickMealType(BuildContext context, {MealType? initial}) {
  return showModalBottomSheet<MealType>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Material(
          color: const Color(0xFF0E1630),
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('لأنهي وجبة؟', textAlign: TextAlign.center, style: AppText.title(20)),
              const SizedBox(height: 14),
              Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
                for (final t in MealType.values)
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx, t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        gradient: t == initial ? const LinearGradient(colors: [AppColors.cyan, AppColors.orange]) : null,
                        color: t == initial ? null : Colors.white.withValues(alpha: .1),
                        border: Border.all(color: Colors.white.withValues(alpha: .22)),
                      ),
                      child: Text(t.label, style: AppText.body(15, weight: FontWeight.w700)),
                    ),
                  ),
              ]),
            ]),
          ),
        ),
      ),
    ),
  );
}
