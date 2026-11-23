import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../../services/arabic_digits.dart';
import '../../widgets/diary_widget/app_chip.dart';
import '../../widgets/diary_widget/food_thumb.dart';
import '../../widgets/glass_widgets.dart';
import '../widgets/app_background.dart';
import '../../widgets/diary_widget/sufra_dialogs.dart';
import '../../services/diary_controller.dart';
import '../../services/models.dart';
import '../../services/photo_store.dart';
import '../screens/add_food_screen/food_search_sheet.dart';
import '../../services/dates.dart';
import '../../widgets/diary_widget/photo_picker_sheet.dart';

/// وسائط شاشة المراجعة: وجبة جديدة من تحليل، أو تعديل وجبة محفوظة، أو مراجعة مسودات يوم.
class ReviewArgs {
  const ReviewArgs({
    this.analysis,
    this.photoPath,
    this.editing,
    this.fromAi = false,
    this.draftDay,
  });
  final MealAnalysis? analysis;
  final String? photoPath;
  final LoggedMeal? editing;
  final bool fromAi;
  final DateTime? draftDay;
}

/// شاشة ١٢ — راجع وجبتك
/// وضع الإنشاء: بيعرض تحليل الذكاء الاصطناعي. وضع التعديل: بيعدّل وجبة محفوظة.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, this.args = const ReviewArgs()});
  final ReviewArgs args;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  ReviewArgs? _activeArgs;
  LoggedMeal? _editing;
  MealAnalysis _analysis = MealAnalysis(
    type: MealTypeX.byHour(DateTime.now().hour),
    items: const [],
  );
  List<FoodItem> _items = [];
  MealType _type = MealTypeX.byHour(DateTime.now().hour);
  bool _saving = false;
  bool _initializedFromRoute = false;

  void _syncArgs(ReviewArgs args) {
    _activeArgs = args;
    _editing = args.editing;
    _analysis = args.analysis ??
        MealAnalysis(
          type: _editing?.type ?? MealTypeX.byHour(DateTime.now().hour),
          items: const [],
        );
    _items = List<FoodItem>.of(_editing?.items ?? _analysis.items);
    _type = _editing?.type ?? _analysis.type;
    _saving = false;
  }

  @override
  void initState() {
    super.initState();
    _syncArgs(widget.args);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    final resolved = routeArgs is ReviewArgs ? routeArgs : widget.args;
    if (!_initializedFromRoute || resolved != _activeArgs) {
      _initializedFromRoute = true;
      _syncArgs(resolved);
    }
  }

  bool get _isEdit => _editing != null;
  int get _total => _items.fold(0, (s, e) => s + e.kcal);

  Future<void> _editItem(int i) async {
    final result = await showModalBottomSheet<_SheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuantitySheet(item: _items[i]),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (result.delete) {
        _items.removeAt(i);
      } else {
        _items[i] = result.item!;
      }
    });
  }

  Future<void> _addItem() async {
    final item = await showFoodSearchSheet(context);
    if (item != null && mounted) setState(() => _items.add(item));
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_items.isEmpty) {
      showSufraSnack(context, 'ضيف عنصر واحد على الأقل');
      return;
    }
    setState(() => _saving = true);
    final confirmed = [
      for (final e in _items) e.needsReview ? e.copyWith(needsReview: false) : e,
    ];
    final diary = DiaryController.instance;
    if (_isEdit) {
      diary.updateMeal(
        _editing!.id,
        type: _type,
        title: DiaryController.titleFor(confirmed),
        items: confirmed,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } else {
      final photo = await PhotoStore.persist(_activeArgs?.photoPath ?? widget.args.photoPath);
      diary.addAnalysis(
        MealAnalysis(type: _type, items: confirmed),
        photoPath: photo,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/diary', (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    final effectiveArgs = routeArgs is ReviewArgs ? routeArgs : widget.args;

    if (effectiveArgs.draftDay != null) {
      return DraftReviewScreen(day: effectiveArgs.draftDay!);
    }

    final total = _total;
    final fromAi = effectiveArgs.fromAi || widget.args.fromAi;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_isEdit ? 'عدّل وجبتك' : 'راجع وجبتك', style: AppText.title(26)),
                    GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      child: const Icon(Icons.close_rounded, size: 26),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _isEdit
                      ? 'اضغط على أي عنصر لتعديل كميته أو صورته، واسحب لحذفه'
                      : (fromAi
                      ? 'حلّلناها بالذكاء الاصطناعي، راجع الكميات'
                      : 'راجع الكميات وضيف أو احذف قبل ما تحفظ'),
                  style: AppText.body(13, color: AppColors.textSoft),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final t in MealType.values)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: _TypeChip(
                            t.label,
                            selected: _type == t,
                            onTap: () => setState(() => _type = t),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      if (_analysis.isDemo && !_isEdit)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.orange.withValues(alpha: .15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.orange.withValues(alpha: .5),
                            ),
                          ),
                          child: Text(
                            'ده تحليل تجريبي لإن مفتاح الذكاء الاصطناعي مش متضاف في lib/core/secrets.dart.',
                            style: AppText.body(12.5, color: AppColors.orange),
                          ),
                        ),
                      for (var i = 0; i < _items.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Dismissible(
                            key: ValueKey(_items[i].id),
                            direction: DismissDirection.startToEnd,
                            onDismissed: (_) => setState(() => _items.removeAt(i)),
                            background: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              alignment: Alignment.centerRight,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    AppColors.orange.withValues(alpha: .15),
                                    AppColors.orange,
                                  ],
                                ),
                              ),
                              child: Text(
                                'حذف',
                                style: AppText.body(
                                  13,
                                  weight: FontWeight.w700,
                                  color: AppColors.bgDark,
                                ),
                              ),
                            ),
                            child: _ReviewRow(
                              item: _items[i],
                              fallbackImage: _editing?.photoPath,
                              onTap: () => _editItem(i),
                            ),
                          ),
                        ),
                      GestureDetector(
                        onTap: _addItem,
                        child: GlassCard(
                          padding: const EdgeInsets.all(14),
                          child: Center(
                            child: Text(
                              '+ ضيف عنصر',
                              style: AppText.body(
                                14,
                                weight: FontWeight.w700,
                                color: AppColors.cyan,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('الإجمالي (تقدير)', style: AppText.body(14)),
                          Text(
                            '${ar(total)} سعرة',
                            style: AppText.body(28, weight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        total == 0
                            ? 'لسه مفيش عناصر'
                            : 'النطاق المتوقع ${ar((total * .94).round())} – ${ar((total * 1.06).round())}',
                        style: AppText.body(12, color: AppColors.textSoft),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                GradientButton(
                  text: _isEdit ? 'احفظ التعديل' : 'بالهنا والشفا — احفظ',
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip(this.label, {required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        gradient: selected
            ? const LinearGradient(colors: [AppColors.cyan, AppColors.orange])
            : null,
        color: selected ? null : Colors.white.withValues(alpha: .1),
        border: Border.all(
          color: selected ? Colors.transparent : Colors.white.withValues(alpha: .22),
        ),
      ),
      child: Text(
        label,
        style: AppText.body(
          13,
          weight: selected ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    ),
  );
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.item, required this.onTap, this.fallbackImage});
  final FoodItem item;
  final String? fallbackImage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final warn = item.needsReview;
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            FoodThumb(asset: item.asset ?? fallbackImage),
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
                      if (item.tag != null)
                        AppChip(
                          item.tag!,
                          color: item.tagColor ?? AppColors.cyan,
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.portionLabel,
                    style: AppText.body(12, color: AppColors.textSoft),
                  ),
                ],
              ),
            ),
            Text(
              warn ? '+${ar(item.kcal)}' : ar(item.kcal),
              style: AppText.body(22, weight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetResult {
  const _SheetResult.save(this.item) : delete = false;
  const _SheetResult.delete()
      : item = null,
        delete = true;
  final FoodItem? item;
  final bool delete;
}

/// تعديل عنصر: الكمية (×) أو السعرات مباشرة، أو صورة الصنف (كاميرا/معرض/حذف)، أو حذفه.
class _QuantitySheet extends StatefulWidget {
  const _QuantitySheet({required this.item});
  final FoodItem item;

  @override
  State<_QuantitySheet> createState() => _QuantitySheetState();
}

class _QuantitySheetState extends State<_QuantitySheet> {
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
      _SheetResult.save(
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
                onTap: () => Navigator.pop(context, const _SheetResult.delete()),
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

/// "راجع وجبتك": كل اللي اخترته في اليومية (فطار/غدا/عشا/سناك) في صفحة واحدة، وبعدها احفظ مرة واحدة.
class DraftReviewScreen extends StatefulWidget {
  const DraftReviewScreen({super.key, required this.day});
  final DateTime day;

  @override
  State<DraftReviewScreen> createState() => _DraftReviewScreenState();
}

class _DraftReviewScreenState extends State<DraftReviewScreen> {
  final _diary = DiaryController.instance;
  bool _saving = false;

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
    if (!mounted) return;
    setState(() {});
    if (!_saving && _diary.draftsOn(widget.day).isEmpty) Navigator.maybePop(context);
  }

  Future<void> _edit(DraftEntry d) async {
    final r = await showModalBottomSheet<_SheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuantitySheet(item: d.item),
    );
    if (r == null || !mounted) return;
    if (r.delete) {
      _diary.removeDraft(d.id);
    } else {
      _diary.updateDraftItem(d.id, r.item!);
    }
  }

  Future<void> _add(MealType t) async {
    final item = await showFoodSearchSheet(context);
    if (item != null && mounted) _diary.addDraft(t, item, day: widget.day);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await _diary.commitDrafts(widget.day, photoSaver: PhotoStore.persist);
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/diary', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final all = _diary.draftsOn(widget.day);
    final total = all.fold<int>(0, (s, d) => s + d.item.kcal);
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('راجع وجباتك', style: AppText.title(26)),
                    GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      child: const Icon(Icons.close_rounded, size: 26),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${arDate(widget.day)} · اضغط على أي عنصر لتعديل كميته، واسحب لحذفه',
                  style: AppText.body(13, color: AppColors.textSoft),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      for (final t in MealType.values)
                        if (all.any((d) => d.type == t)) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8, top: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      t.label,
                                      style: AppText.body(16, weight: FontWeight.w700),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${ar(all.where((d) => d.type == t).fold<int>(0, (s, d) => s + d.item.kcal))} سعرة',
                                      style: AppText.body(
                                        12.5,
                                        color: AppColors.textSoft,
                                      ),
                                    ),
                                  ],
                                ),
                                GestureDetector(
                                  onTap: () => _add(t),
                                  behavior: HitTestBehavior.opaque,
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Text(
                                      '+ ضيف',
                                      style: AppText.body(
                                        13,
                                        weight: FontWeight.w700,
                                        color: AppColors.cyan,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          for (final d in all.where((d) => d.type == t))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Dismissible(
                                key: ValueKey('rv-${d.id}'),
                                direction: DismissDirection.startToEnd,
                                onDismissed: (_) => _diary.removeDraft(d.id),
                                background: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  alignment: Alignment.centerRight,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        AppColors.orange.withValues(alpha: .15),
                                        AppColors.orange,
                                      ],
                                    ),
                                  ),
                                  child: Text(
                                    'حذف',
                                    style: AppText.body(
                                      13,
                                      weight: FontWeight.w700,
                                      color: AppColors.bgDark,
                                    ),
                                  ),
                                ),
                                child: _ReviewRow(
                                  item: d.item,
                                  fallbackImage: d.photoPath,
                                  onTap: () => _edit(d),
                                ),
                              ),
                            ),
                          const SizedBox(height: 4),
                        ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('الإجمالي (تقدير)', style: AppText.body(14)),
                          Text(
                            '${ar(total)} سعرة',
                            style: AppText.body(28, weight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        total == 0
                            ? 'لسه مفيش عناصر'
                            : 'النطاق المتوقع ${ar((total * .94).round())} – ${ar((total * 1.06).round())}',
                        style: AppText.body(12, color: AppColors.textSoft),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                GradientButton(text: 'بالهنا والشفا — احفظ', onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}