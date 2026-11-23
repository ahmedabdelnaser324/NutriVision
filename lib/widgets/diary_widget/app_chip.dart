import 'package:flutter/material.dart';
import '../../core/app_theme.dart';


/// الشارة الصغيرة (.chip): خلفية ملونة ونص غامق.
class AppChip extends StatelessWidget {
  const AppChip(this.label, {super.key, this.color = AppColors.cyan, this.textColor = AppColors.bgDark, this.border, this.icon});

  final String label;
  final Color color;
  final Color textColor;
  final Color? border;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
        border: border == null ? null : Border.all(color: border!),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[icon!, const SizedBox(width: 4)],
        Text(label, style: AppText.body(12, weight: FontWeight.w700, color: textColor)),
      ]),
    );
  }
}
