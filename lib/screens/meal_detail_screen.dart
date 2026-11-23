import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../../services/arabic_digits.dart';
import '../../services/dates.dart';
import '../../widgets/diary_widget/app_chip.dart';
import '../../widgets/diary_widget/food_image.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/app_background.dart';
import '../../widgets/diary_widget/photo_picker_sheet.dart';
import '../../widgets/diary_widget/sufra_dialogs.dart';
import '../../services/photo_store.dart';
import '../../services/diary_controller.dart';
import '../../services/food_catalog.dart';
import '../../services/models.dart';

/// شاشة ١٤ — تفاصيل الوجبة (بتقرأ الوجبة من اليومية بالـ id، فأي تعديل بيظهر فوراً).
class MealDetailScreen extends StatefulWidget {
  const MealDetailScreen({super.key, required this.mealId});
  final String mealId;

  @override
  State<MealDetailScreen> createState() => _MealDetailScreenState();
}

/// ألياف/سكر/صوديوم لعنصر: من بياناته، أو من كتالوج الأكلات لو مش متسجّلة (وجبات قديمة).
({double fiber, double sugar, double sodium}) _micros(FoodItem e) {
  if (e.baseFiber + e.baseSugar + e.baseSodium > 0) {
    return (fiber: e.fiber, sugar: e.sugar, sodium: e.sodium);
  }
  final c = FoodCatalog.byName(e.name);
  if (c == null) return (fiber: 0.0, sugar: 0.0, sodium: 0.0);
  return (fiber: c.fiber * e.qty, sugar: c.sugar * e.qty, sodium: c.sodium * e.qty);
}

class _MealDetailScreenState extends State<MealDetailScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin =
  AnimationController(vsync: this, duration: const Duration(seconds: 14))
    ..repeat();
  final _diary = DiaryController.instance;

  @override
  void initState() {
    super.initState();
    _diary.addListener(_onChange);
  }

  @override
  void dispose() {
    _diary.removeListener(_onChange);
    _spin.dispose();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    if (_diary.mealById(widget.mealId) == null) {
      Navigator.maybePop(context);
    } else {
      setState(() {});
    }
  }

  // نسب الماكروز بالسعرات (٤/٤/٩)، أو ٣٠/٤٥/٢٥ لو مفيش بيانات.
  List<double> _split(LoggedMeal meal) {
    final m = meal.macros;
    final p = m.protein * 4.0, c = m.carbs * 4.0, f = m.fat * 9.0;
    final t = p + c + f;
    return t == 0 ? [.30, .45, .25] : [p / t, c / t, f / t];
  }

  Future<void> _changePhoto(LoggedMeal meal) async {
    final r = await pickMealPhoto(context, canRemove: meal.photoPath != null);
    if (r == null || !mounted) return;
    if (r.remove) {
      _diary.setMealPhoto(meal.id, null);
      return;
    }
    final saved = await PhotoStore.persist(r.path);
    if (!mounted) return;
    _diary.setMealPhoto(meal.id, saved);
  }

  Future<void> _editMealItem(LoggedMeal meal) async {
    if (meal.items.isEmpty) return;
    final targetItem = meal.items.first;
    final res = await showModalBottomSheet<_DetailEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemEditorSheet(item: targetItem),
    );
    if (res == null || !mounted) return;
    if (res.delete) {
      if (meal.items.length == 1) {
        _diary.removeMeal(meal.id);
      } else {
        _diary.removeItem(meal.id, targetItem.id);
      }
      return;
    }
    if (res.item != null) {
      final updatedItems = [
        for (final it in meal.items)
          if (it.id == targetItem.id) res.item! else it,
      ];
      _diary.updateMeal(
        meal.id,
        title: DiaryController.titleFor(updatedItems),
        items: updatedItems,
      );
    }
  }

  Future<void> _delete(LoggedMeal meal) async {
    final ok = await showConfirmSheet(
      context,
      title: 'تحذف "${meal.title}"؟',
      message: 'تقدر تتراجع بعد الحذف مباشرة',
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final undo = _diary.removeMeal(meal.id);
    messenger.showSnackBar(
      SnackBar(
        content: Text('اتحذفت الوجبة', style: AppText.body(14)),
        backgroundColor: const Color(0xFF16204A),
        duration: const Duration(seconds: 4),
        persist: false,
        action: SnackBarAction(
          label: 'تراجع',
          textColor: AppColors.cyan,
          onPressed: undo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meal = _diary.mealById(widget.mealId);
    if (meal == null) return const Scaffold(body: SizedBox.shrink());
    final s = _split(meal);
    final pct = s.map((e) => (e * 100).round()).toList();
    final micros = meal.items.map(_micros).toList();
    final fiber = micros.fold(0.0, (a, e) => a + e.fiber);
    final sugar = micros.fold(0.0, (a, e) => a + e.sugar);
    final sodium = micros.fold(0.0, (a, e) => a + e.sodium);
    final img = meal.mainAsset;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${meal.type.label} · ${arTime(meal.time)} · ${arDate(meal.time)}',
                            style: AppText.body(12, color: AppColors.textSoft),
                          ),
                          Text(meal.title, style: AppText.title(26)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _diary.toggleFavorite(meal.id),
                      child: AppChip(
                        meal.favorite ? 'مفضلة' : 'أضف للمفضلة',
                        color: AppColors.cyan,
                        icon: Icon(
                          meal.favorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 14,
                          color: AppColors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GlassCard(
                          padding: EdgeInsets.zero,
                          child: SizedBox(
                            height: 200,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                RotationTransition(
                                  turns: _spin,
                                  child: CustomPaint(
                                    size: const Size(170, 170),
                                    painter: _DashedCirclePainter(),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _changePhoto(meal),
                                  child: FoodImage(
                                    img,
                                    width: meal.photoPath != null ? 180 : 150,
                                    height: meal.photoPath != null ? 180 : 150,
                                  ),
                                ),
                                Positioned(
                                  bottom: 14,
                                  right: 14,
                                  child: GestureDetector(
                                    onTap: () => _changePhoto(meal),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(99),
                                        color: Colors.black.withValues(alpha: .35),
                                        border: Border.all(color: Colors.white24),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.photo_camera_rounded, size: 16),
                                          const SizedBox(width: 6),
                                          Text(
                                            meal.photoPath != null ? 'غيّر الصورة' : 'أضف صورة',
                                            style: AppText.body(12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 14,
                                  right: 14,
                                  child: GlassCard(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          ar(meal.kcal),
                                          style: AppText.body(26, weight: FontWeight.w700),
                                        ),
                                        Text(
                                          'سعرة',
                                          style: AppText.body(11, color: AppColors.textSoft),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (meal.macros.protein > 0)
                                  Positioned(
                                    bottom: 14,
                                    left: 14,
                                    child: AppChip(
                                      '${ar(meal.macros.protein)} جم بروتين',
                                      color: AppColors.cyan,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        GlassCard(
                          child: Row(
                            children: [
                              SizedBox(
                                width: 96,
                                height: 96,
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: 1),
                                  duration: const Duration(milliseconds: 1200),
                                  curve: Curves.easeOutCubic,
                                  builder: (_, t, _) => CustomPaint(
                                    painter: _DonutPainter(s, t),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _Legend(AppColors.cyan, 'بروتين ${ar(pct[0])}٪'),
                                  const SizedBox(height: 8),
                                  _Legend(AppColors.orange, 'كارب ${ar(pct[1])}٪'),
                                  const SizedBox(height: 8),
                                  _Legend(AppColors.textSoft, 'دهون ${ar(pct[2])}٪'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _LevelBar(
                                'ألياف',
                                fiber >= 8 ? 'كويس' : fiber >= 4 ? 'متوسط' : 'قليل',
                                (fiber / 10).clamp(0.0, 1.0),
                                AppColors.cyan,
                              ),
                              const SizedBox(height: 12),
                              _LevelBar(
                                'سكر',
                                sugar >= 25 ? 'عالي' : sugar >= 10 ? 'متوسط' : 'قليل',
                                (sugar / 30).clamp(0.0, 1.0),
                                sugar >= 25 ? AppColors.orange : AppColors.cyan,
                              ),
                              const SizedBox(height: 12),
                              _LevelBar(
                                'صوديوم',
                                sodium >= 1000 ? 'عالي' : sodium >= 500 ? 'متوسط' : 'قليل',
                                (sodium / 1500).clamp(0.0, 1.0),
                                sodium >= 1000 ? AppColors.orange : AppColors.cyan,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'مصدر البيانات: مكونات الطبق وقاعدة الأكلات (قيم تقديرية)',
                                style: AppText.body(11, color: AppColors.textSoft),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GradientButton(
                        text: 'تعديل',
                        onPressed: () => _editMealItem(meal),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GradientButton(
                        text: 'حذف',
                        onPressed: () => _delete(meal),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailEditResult {
  const _DetailEditResult.save(this.item) : delete = false;
  const _DetailEditResult.delete()
      : item = null,
        delete = true;
  final FoodItem? item;
  final bool delete;
}

class _ItemEditorSheet extends StatefulWidget {
  const _ItemEditorSheet({required this.item});
  final FoodItem item;

  @override
  State<_ItemEditorSheet> createState() => _ItemEditorSheetState();
}

class _ItemEditorSheetState extends State<_ItemEditorSheet> {
  late double _qty = widget.item.qty;
  late final _kcal = TextEditingController(text: '${widget.item.kcal}');
  late String? _currentAsset = widget.item.asset;
  bool _kcalEdited = false;

  @override
  void dispose() {
    _kcal.dispose();
    super.dispose();
  }

  void _step(double d) {
    setState(() {
      _qty = (_qty + d).clamp(.25, 8).toDouble();
      _kcalEdited = false;
      _kcal.text = '${(widget.item.baseKcal * _qty).round()}';
    });
  }

  Future<void> _pickPhoto() async {
    final pick = await pickMealPhoto(context, canRemove: _currentAsset != null);
    if (pick == null || !mounted) return;
    if (pick.remove) {
      setState(() => _currentAsset = null);
      return;
    }
    final saved = await PhotoStore.persist(pick.path);
    if (!mounted) return;
    setState(() => _currentAsset = saved);
  }

  void _confirm() {
    var base = widget.item.baseKcal;
    if (_kcalEdited) {
      final typed = int.tryParse(_kcal.text.trim());
      if (typed != null && typed >= 0) base = (typed / _qty).round();
    }
    Navigator.pop(
      context,
      _DetailEditResult.save(
        widget.item.copyWith(
          qty: _qty,
          kcal: base,
          asset: _currentAsset,
          needsReview: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget round(IconData i, VoidCallback f) => GestureDetector(
      onTap: f,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: .14),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(i),
      ),
    );

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        12,
        12,
        12 + (bottomInset > bottomPad ? bottomInset : bottomPad),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgDark.withValues(alpha: .96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: .18)),
        ),
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              const SizedBox(height: 14),
              Text(widget.item.name, style: AppText.title(20)),
              Text(
                widget.item.portion,
                style: AppText.body(12, color: AppColors.textSoft),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickPhoto,
                icon: Icon(
                  _currentAsset != null
                      ? Icons.photo_camera_back_rounded
                      : Icons.add_a_photo_rounded,
                  size: 18,
                  color: AppColors.cyan,
                ),
                label: Text(
                  _currentAsset != null
                      ? 'تغيير أو حذف صورة الصنف'
                      : 'إضافة صورة للصنف',
                  style: AppText.body(13, weight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  round(Icons.add_rounded, () => _step(.25)),
                  SizedBox(
                    width: 120,
                    child: Text(
                      '×${arNum(_qty)}',
                      textAlign: TextAlign.center,
                      style: AppText.body(30, color: AppColors.textSoft),
                    ),
                  ),
                  round(Icons.remove_rounded, () => _step(-.25)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 110,
                    height: 46,
                    child: TextField(
                      controller: _kcal,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => _kcalEdited = true,
                      style: AppText.body(
                        20,
                        weight: FontWeight.w700,
                        color: AppColors.cyan,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: .08),
                        contentPadding: EdgeInsets.zero,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: .25),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.cyan),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'سعرة (تقدر تعدّلها بإيدك)',
                    style: AppText.body(12.5, color: AppColors.textSoft),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GradientButton(text: 'تأكيد', onPressed: _confirm),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.pop(context, const _DetailEditResult.delete()),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    'حذف العنصر ده',
                    style: AppText.body(
                      14,
                      weight: FontWeight.w700,
                      color: AppColors.orange,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.text);
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text('●', style: TextStyle(color: color, fontSize: 13)),
      const SizedBox(width: 6),
      Text(text, style: AppText.body(13)),
    ],
  );
}

class _LevelBar extends StatelessWidget {
  const _LevelBar(this.label, this.level, this.value, this.color);
  final String label, level;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppText.body(13)),
          Text(level, style: AppText.body(13, weight: FontWeight.w700, color: color)),
        ],
      ),
      const SizedBox(height: 5),
      Container(
        height: 9,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.centerRight,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value),
          duration: const Duration(milliseconds: 1400),
          curve: Curves.easeOut,
          builder: (_, v, _) => FractionallySizedBox(
            widthFactor: v,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(9),
                boxShadow: [BoxShadow(color: color, blurRadius: 10)],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: .3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final r = size.width / 2 - 1;
    const dashes = 48;
    for (var i = 0; i < dashes; i++) {
      final a = i * 2 * math.pi / dashes;
      canvas.drawArc(
        Rect.fromCircle(center: size.center(Offset.zero), radius: r),
        a,
        math.pi / dashes,
        false,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// دونات الماكروز: بروتين / كارب / دهون.
class _DonutPainter extends CustomPainter {
  _DonutPainter(this.parts, this.t);
  final List<double> parts;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    const colors = [AppColors.orange, AppColors.orange, AppColors.cyan];
    final rect = Rect.fromLTWH(10, 10, size.width - 20, size.height - 20);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.butt;
    var start = -math.pi / 2;
    for (var i = 0; i < parts.length; i++) {
      final sweep = 2 * math.pi * parts[i] * t;
      canvas.drawArc(
        rect,
        start,
        math.max(0, sweep - .03),
        false,
        paint..color = colors[i],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.t != t || old.parts != parts;
}