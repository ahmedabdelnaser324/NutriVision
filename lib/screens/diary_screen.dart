import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_theme.dart';
import '../services/arabic_digits.dart';
import '../services/dates.dart';
import '../services/photo_store.dart';
import '../widgets/diary_widget/app_chip.dart';
import '../widgets/diary_widget/bottom_bar.dart';
import '../widgets/diary_widget/food_thumb.dart';
import '../widgets/diary_widget/photo_picker_sheet.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/app_background.dart';
import '../widgets/diary_widget/sufra_dialogs.dart';
import '../services/diary_controller.dart';
import '../services/models.dart';
import '../screens/add_food_screen/add_options_sheet.dart';
import '../screens/review_screen.dart';

/// شاشة ١٣ — اليومية
/// كل يوم ليه وجباته، والتغييرات بتتحفظ على الجهاز.
class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  static const _dayInitials = ['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج']; // السبت → الجمعة
  final _diary = DiaryController.instance;

  @override
  void initState() {
    super.initState();
    _diary.addListener(_refresh);
  }

  @override
  void dispose() {
    _diary.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _shiftWeek(int weeks) => _diary.selectDay(
    DateTime(
      _diary.selectedDay.year,
      _diary.selectedDay.month,
      _diary.selectedDay.day + 7 * weeks,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final selected = _diary.selectedDay;
    final start = weekStart(selected);
    final week = List.generate(7, (i) => DateTime(start.year, start.month, start.day + i));
    final isToday = sameDay(selected, _diary.today);
    final draftKcal = _diary.draftKcalOn(selected);
    final total = _diary.totalKcal + draftKcal;
    final progress = (total / DiaryController.dailyGoal).clamp(0, 1).toDouble();
    final pct = (progress * 100).round();
    final hasDrafts = _diary.draftCount > 0;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('اليومية', style: AppText.title(28)),
                      if (!isToday)
                        GestureDetector(
                          onTap: () => _diary.selectDay(_diary.today),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(99),
                              color: Colors.white.withValues(alpha: .12),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              'النهارده',
                              style: AppText.body(
                                13,
                                weight: FontWeight.w700,
                                color: AppColors.orange,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _shiftWeek(-1),
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.chevron_right_rounded),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            arDate(selected),
                            style: AppText.body(14, weight: FontWeight.w700),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _shiftWeek(1),
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.chevron_left_rounded),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (var i = 0; i < 7; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: _DayCell(
                            initial: _dayInitials[i],
                            day: week[i].day,
                            selected: sameDay(week[i], selected),
                            isToday: sameDay(week[i], _diary.today),
                            hasMeals: _diary.hasMealsOn(week[i]),
                            onTap: () => _diary.selectDay(week[i]),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${ar(total)} / ${arThousands(DiaryController.dailyGoal)} سعرة',
                              style: AppText.body(20, weight: FontWeight.w700),
                            ),
                            Text(
                              '${ar(pct)}٪',
                              style: AppText.body(13, color: AppColors.textSoft),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: Container(
                            height: 9,
                            color: Colors.white.withValues(alpha: .12),
                            alignment: Alignment.centerRight,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: progress),
                              duration: const Duration(milliseconds: 700),
                              curve: Curves.easeOut,
                              builder: (_, v, _) => FractionallySizedBox(
                                widthFactor: v,
                                heightFactor: 1,
                                child: const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [AppColors.orange, AppColors.cyan],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final t in MealType.values) ...[
                    const SizedBox(height: 12),
                    _MealSection(
                      type: t,
                      meals: _diary.byType(t),
                      drafts: _diary.draftsFor(t),
                    ),
                  ],
                  if (hasDrafts) ...[
                    const SizedBox(height: 16),
                    GradientButton(
                      text: 'راجع وجباتك (${ar(_diary.draftCount)}) واحفظها',
                      onPressed: () => Navigator.pushNamed(
                        context,
                        '/review',
                        arguments: ReviewArgs(draftDay: selected),
                      ),
                    ),
                  ],
                ],
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: SufraBottomBar(
                  current: 'diary',
                  onAdd: () => showAddOptions(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.initial,
    required this.day,
    required this.selected,
    required this.isToday,
    required this.hasMeals,
    required this.onTap,
  });
  final String initial;
  final int day;
  final bool selected, isToday, hasMeals;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: selected ? null : Colors.white.withValues(alpha: .1),
        border: !selected && isToday
            ? Border.all(color: AppColors.orange.withValues(alpha: .7))
            : null,
        gradient: selected
            ? const LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [AppColors.orange, AppColors.cyan],
        )
            : null,
        boxShadow: selected
            ? [
          BoxShadow(
            color: AppColors.orange.withValues(alpha: .5),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ]
            : null,
      ),
      child: Column(
        children: [
          Text(initial, style: AppText.body(12)),
          Text(ar(day), style: AppText.body(17, weight: FontWeight.w700)),
          const SizedBox(height: 3),
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasMeals
                  ? (selected ? Colors.white : AppColors.cyan)
                  : Colors.transparent,
            ),
          ),
        ],
      ),
    ),
  );
}

class _MealSection extends StatelessWidget {
  const _MealSection({
    required this.type,
    required this.meals,
    required this.drafts,
  });
  final MealType type;
  final List<LoggedMeal> meals;
  final List<DraftEntry> drafts;

  @override
  Widget build(BuildContext context) {
    final total = meals.fold<int>(0, (s, m) => s + m.kcal) +
        drafts.fold<int>(0, (s, d) => s + d.item.kcal);
    final empty = meals.isEmpty && drafts.isEmpty;
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(type.label, style: AppText.body(15, weight: FontWeight.w700)),
              Row(
                children: [
                  if (empty)
                    Text('لسه فاضي', style: AppText.body(13, color: AppColors.textSoft))
                  else
                    Text(ar(total), style: AppText.body(16, weight: FontWeight.w700)),
                  if (!empty) ...[
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => showAddOptions(context, type: type),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.add_circle_outline_rounded,
                          size: 24,
                          color: AppColors.cyan,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (empty)
            GestureDetector(
              onTap: () => showAddOptions(context, type: type),
              child: GlassCard(
                padding: const EdgeInsets.all(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.orange.withValues(alpha: .6)),
                  ),
                  child: Center(
                    child: Text(
                      '+ ضيف أكلة',
                      style: AppText.body(
                        14,
                        weight: FontWeight.w700,
                        color: AppColors.orange,
                      ),
                    ),
                  ),
                ),
              ),
            )
          else ...[
            for (final m in meals)
              for (final item in m.items) _ItemRow(meal: m, item: item),
            for (final d in drafts) _DraftRow(entry: d),
          ],
        ],
      ),
    );
  }
}

/// عنصر لسه ما اتحفظش (مسودة): اسحب للحذف، واضغط لتعديل الكمية والصورة.
class _DraftRow extends StatelessWidget {
  const _DraftRow({required this.entry});
  final DraftEntry entry;

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    return Dismissible(
      key: ValueKey('draft-${entry.id}'),
      direction: DismissDirection.startToEnd,
      onDismissed: (_) {
        final undo = DiaryController.instance.removeDraft(entry.id);
        showSufraSnack(
          context,
          'اتحذفت "${item.name}"',
          actionLabel: 'تراجع',
          onAction: undo,
        );
      },
      background: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [AppColors.orange.withValues(alpha: .15), AppColors.orange],
          ),
        ),
        child: Text(
          'حذف',
          style: AppText.body(12, weight: FontWeight.w700, color: AppColors.bgDark),
        ),
      ),
      child: GestureDetector(
        onTap: () async {
          final res = await showModalBottomSheet<_SingleItemResult>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _SingleItemSheet(item: item),
          );
          if (res == null || !context.mounted) return;
          if (res.delete) {
            DiaryController.instance.removeDraft(entry.id);
          } else if (res.item != null) {
            DiaryController.instance.updateDraftItem(entry.id, res.item!);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              FoodThumb(
                asset: item.asset ?? entry.photoPath,
                width: 54,
                height: 62,
                image: 60,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        Text(
                          item.name,
                          style: AppText.body(15, weight: FontWeight.w700),
                        ),
                        AppChip('لسه متحفظتش', color: AppColors.orange),
                      ],
                    ),
                    Text(
                      item.portionLabel,
                      style: AppText.body(13, color: AppColors.textSoft),
                    ),
                  ],
                ),
              ),
              Text(ar(item.kcal), style: AppText.body(16, weight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.meal, required this.item});
  final LoggedMeal meal;
  final FoodItem item;

  Future<void> _openItemEditor(BuildContext context) async {
    final res = await showModalBottomSheet<_SingleItemResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SingleItemSheet(item: item),
    );
    if (res == null || !context.mounted) return;
    final diary = DiaryController.instance;
    if (res.delete) {
      diary.removeItem(meal.id, item.id);
      return;
    }
    if (res.item != null) {
      final updatedItems = [
        for (final it in meal.items)
          if (it.id == item.id) res.item! else it,
      ];
      diary.updateMeal(
        meal.id,
        title: DiaryController.titleFor(updatedItems),
        items: updatedItems,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('${meal.id}-${item.id}'),
      direction: DismissDirection.startToEnd,
      onDismissed: (_) {
        final undo = DiaryController.instance.removeItem(meal.id, item.id);
        showSufraSnack(
          context,
          'اتحذفت "${item.name}"',
          actionLabel: 'تراجع',
          onAction: undo,
        );
      },
      background: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [AppColors.orange.withValues(alpha: .15), AppColors.orange],
          ),
        ),
        child: Text(
          'حذف',
          style: AppText.body(12, weight: FontWeight.w700, color: AppColors.bgDark),
        ),
      ),
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/meal-detail', arguments: meal.id),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              FoodThumb(
                asset: item.asset ?? meal.photoPath,
                width: 54,
                height: 62,
                image: 60,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: AppText.body(15, weight: FontWeight.w700),
                    ),
                    Text(
                      item.portionLabel,
                      style: AppText.body(13, color: AppColors.textSoft),
                    ),
                  ],
                ),
              ),
              Text(ar(item.kcal), style: AppText.body(16, weight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SingleItemResult {
  const _SingleItemResult.save(this.item) : delete = false;
  const _SingleItemResult.delete()
      : item = null,
        delete = true;
  final FoodItem? item;
  final bool delete;
}

class _SingleItemSheet extends StatefulWidget {
  const _SingleItemSheet({required this.item});
  final FoodItem item;

  @override
  State<_SingleItemSheet> createState() => _SingleItemSheetState();
}

class _SingleItemSheetState extends State<_SingleItemSheet> {
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
      _SingleItemResult.save(
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
                onTap: () => Navigator.pop(context, const _SingleItemResult.delete()),
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