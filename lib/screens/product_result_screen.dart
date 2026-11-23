import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/arabic_digits.dart';
import '../../widgets/diary_widget/app_chip.dart';
import '../../widgets/diary_widget/food_image.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/app_background.dart';
import '../../services/diary_controller.dart';
import '../../services/models.dart';
import '../../widgets/diary_widget/sufra_dialogs.dart';

/// شاشة ١٦ — نتيجة المنتج
class ProductResultScreen extends StatefulWidget {
  const ProductResultScreen({super.key, this.product = Product.demo});
  final Product product;

  @override
  State<ProductResultScreen> createState() => _ProductResultScreenState();
}

class _ProductResultScreenState extends State<ProductResultScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat(reverse: true);

  static const _grades = ['A', 'B', 'C', 'D', 'E'];
  static const _gradeColors = [AppColors.cyan, Colors.teal,AppColors.orange, Colors.deepOrange, Colors.redAccent];

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _addToDiary() async {
    final p = widget.product;
    if (p.kcalPer100 == null) {
      showSufraSnack(context, 'المنتج ده مفيهوش بيانات سعرات، مقدرناش نضيفه');
      return;
    }
    final type = await pickMealType(context, initial: MealTypeX.byHour(DateTime.now().hour));
    if (type == null || !mounted) return;
    // بيتضاف للمسودة (الكمية بتتعدّل من علامة ⊕ في اليومية)، وبعدين "راجع وجبتك" تحت.
    DiaryController.instance.addDraft(type, p.toFoodItem(p.defaultGrams));
    Navigator.pushNamedAndRemoveUntil(context, '/diary', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final bad = p.nutriScore == 'E' || p.nutriScore == 'D' || p.alternatives.isNotEmpty;
    final accent = bad ? AppColors.orange : AppColors.cyan;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: ListView(padding: EdgeInsets.zero, children: [
              // بطاقة المنتج
              GlassCard(
                child: Row(children: [
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, _) => Transform.scale(
                          scale: 1 + .12 * _pulse.value,
                          child: Container(
                            width: 116,
                            height: 116,
                            decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [accent.withValues(alpha: .6 - .3 * _pulse.value), Colors.transparent])),
                          ),
                        ),
                      ),
                      Transform.rotate(angle: -.14, child: FoodImage(p.image, width: 96, height: 96)),
                    ]),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, style: AppText.title(24)),
                      const SizedBox(height: 2),
                      Text(p.kcalPer100 == null ? '${p.category} · السعرات مش متاحة' : '${p.category} · ${ar(p.kcalPer100!)} سعرة / ${ar(100)} جم',
                          style: AppText.body(12,color: AppColors.textSoft)),
                      const SizedBox(height: 6),
                      AppChip(p.summaryTag, color: bad ? AppColors.orange : AppColors.cyan),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              // نوتري سكور
              GlassCard(
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('نوتري سكور', style: AppText.body(12,weight: FontWeight.w700)),
                    Text(p.nutriScore == null ? 'مش متاح للمنتج ده' : 'الأقل صحة', style: AppText.body(12,color: AppColors.textSoft)),
                  ]),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 54,
                    child: Directionality(
                      textDirection: TextDirection.ltr, // A ← E من اليسار لليمين
                      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        for (var i = 0; i < 5; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          Expanded(child: _GradeBox(_grades[i], _gradeColors[i], active: _grades[i] == p.nutriScore, pulse: _pulse)),
                        ],
                      ]),
                    ),
                  ),
                ]),
              ),
              if (p.kcalPer100 != null) ...[
                const SizedBox(height: 12),
                GlassCard(
                  child: Row(children: [
                    _Fact('بروتين', p.protein100),
                    _Fact('كارب', p.carbs100),
                    _Fact('دهون', p.fat100),
                    _Fact('سكر', p.sugar100),
                  ]),
                ),
              ],
              if (p.allergenWarning != null) ...[
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, child) => Transform.translate(offset: Offset(0, -2 * _pulse.value), child: child),
                  child: GlassCard(
                    padding: const EdgeInsets.all(14),
                      child: Row(children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                      const SizedBox(width: 10),
                      Expanded(child: Text(p.allergenWarning!, style: AppText.body(14, weight: FontWeight.w700))),
                    ]),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (p.alternatives.isNotEmpty) ...[
                GradientButton(text:  'بدائل أصح لك', onPressed: () => Navigator.pushNamed(context, '/alternatives', arguments: p)),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: .98,
                  children: [for (final a in p.alternatives.take(2)) _AlternativeCard(a)],
                ),
              ],
                ]),
              ),
              GestureDetector(
                onTap: _addToDiary,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: Text('+ أضف لوجباتي', style: AppText.body(15, weight: FontWeight.w700, color: AppColors.cyan))),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _GradeBox extends StatelessWidget {
  const _GradeBox(this.grade, this.color, {required this.active, required this.pulse});
  final String grade;
  final Color color;
  final bool active;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, _) => Container(
        height: active ? 54 : 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: active ? 1 : .45),
          borderRadius: BorderRadius.circular(12),
          boxShadow: active ? [BoxShadow(color: color.withValues(alpha: .6 + .3 * pulse.value), blurRadius: 22)] : null,
        ),
        child: Text(grade, style: TextStyle(
            fontWeight: FontWeight.w700, fontSize: active ? 22 : 16, color: Colors.white)),
      ),
    );
  }
}

class _AlternativeCard extends StatelessWidget {
  const _AlternativeCard(this.alt);
  final ProductAlternative alt;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(10),
      child: Stack(children: [
        Positioned(top: 0, left: 0, child: AppChip(alt.grade, color: AppColors.cyan)),
        Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Image.asset(alt.asset, width: 64, height: 64, fit: BoxFit.contain),
            const SizedBox(height: 4),
            Text(alt.name, textAlign: TextAlign.center, style: AppText.body(14, weight: FontWeight.w700)),
            Text('${ar(alt.kcal)} سعرة', style: AppText.body(12,color: AppColors.textSoft)),
          ]),
        ),
      ]),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.grams);
  final String label;
  final double grams;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text('${arNum(double.parse(grams.toStringAsFixed(1)))} جم', style: AppText.body(15,weight: FontWeight.w700)),
          Text(label, style: AppText.body(11.5,color: AppColors.textSoft)),
        ]),
      );
}
