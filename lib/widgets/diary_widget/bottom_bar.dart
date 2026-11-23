import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../widgets/glass_widgets.dart';

/// شريط التنقل السفلي الزجاجي مع زر + المركزي.
class SufraBottomBar extends StatelessWidget {
  const SufraBottomBar({super.key, this.current = 'diary', this.onAdd});
  final String current; // main | diary | stats | account
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    Widget item(String id, String label, String route) {
      final on = current == id;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!on && ModalRoute.of(context)?.settings.name != route) {
            Navigator.pushReplacementNamed(context, route);
          }
        },
        child: Text(label,
            style: AppText.body(12, weight: on ? FontWeight.w700 : FontWeight.w400, color: on ? AppColors.cyan : AppColors.textSoft)),
      );
    }

    return SizedBox(
      height: 70,
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
        GlassCard(
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: 70,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              item('main', 'الرئيسية', '/main'),
              item('diary', 'اليومية', '/diary'),
              const SizedBox(width: 58),
              item('stats', 'تقدمي', '/stats'),
              item('account', 'حسابي', '/account'),
            ]),
          ),
        ),
        Positioned(
          top: -30,
          child: GestureDetector(
            onTap: onAdd ?? () => Navigator.pushNamed(context, '/analyze'),
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft,
                    colors: [AppColors.cyan, AppColors.orange]),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: .4), width: 2)),
                boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: .6),
                    blurRadius: 28, offset: const Offset(0, 10))],
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
            ),
          ),
        ),
      ]),
    );
  }
}
