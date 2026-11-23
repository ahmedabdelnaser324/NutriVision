import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../services//dates.dart';
import 'meal_repository.dart';
import 'models.dart';

/// عنصر اختاره المستخدم ولسه ما اتحفظش (مسودة). بيتحفظ كله مرة واحدة من "راجع وجبتك".
class DraftEntry {
  DraftEntry({
    String? id,
    required this.day,
    required this.type,
    required this.item,
    this.photoPath,
  }) : id = id ?? newId();
  final String id;
  final DateTime day;
  final MealType type;
  FoodItem item;
  final String? photoPath;
}

/// حالة اليومية. كل وجبة ليها تاريخ، وكل تغيير بيتحفظ على الجهاز.
class DiaryController extends ChangeNotifier {
  DiaryController(this._repo, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        _selected = dateOnly((clock ?? DateTime.now)());

  /// بيتبدّل في main.dart بنسخة بتحفظ فعلياً.
  static DiaryController instance = DiaryController(InMemoryMealRepository());

  static const dailyGoal = 1850;

  final MealRepository _repo;
  final DateTime Function() _clock;
  final List<LoggedMeal> _meals = [];
  final List<DraftEntry> _drafts = []; // في الذاكرة بس لحد ما تتحفظ
  DateTime _selected;

  DateTime get today => dateOnly(_clock());
  DateTime get selectedDay => _selected;
  List<LoggedMeal> get meals => List.unmodifiable(_meals);

  Future<void> load() async {
    final loaded = await _repo.load();
    _meals
      ..clear()
      ..addAll(loaded);
    notifyListeners();
  }

  void selectDay(DateTime d) {
    _selected = dateOnly(d);
    notifyListeners();
  }

  LoggedMeal? mealById(String id) {
    for (final m in _meals) {
      if (m.id == id) return m;
    }
    return null;
  }

  List<LoggedMeal> mealsOn(DateTime day) {
    final list = _meals.where((m) => sameDay(m.time, day)).toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    return list;
  }

  List<LoggedMeal> byType(MealType t, [DateTime? day]) =>
      mealsOn(day ?? _selected).where((m) => m.type == t).toList();
  int totalKcalOn(DateTime day) => mealsOn(day).fold(0, (s, m) => s + m.kcal);
  bool hasMealsOn(DateTime day) => _meals.any((m) => sameDay(m.time, day));

  /// إجمالي اليوم المختار.
  int get totalKcal => totalKcalOn(_selected);
  double get progress => (totalKcal / dailyGoal).clamp(0, 1).toDouble();

  /// وقت التسجيل: اليوم المختار + الساعة الحالية.
  DateTime _stamp(DateTime? at) {
    if (at != null) return at;
    final n = _clock();
    return DateTime(_selected.year, _selected.month, _selected.day, n.hour, n.minute);
  }

  static String titleFor(List<FoodItem> items) {
    if (items.isEmpty) return 'وجبة';
    final names = items.take(2).map((e) => e.name).toList();
    return names.join(' و ');
  }

  void _mergeItemIntoList(List<FoodItem> target, FoodItem incoming) {
    final normalizedName = incoming.name.trim();
    final idx = target.indexWhere((e) => e.name.trim() == normalizedName);
    if (idx < 0) {
      target.add(incoming);
      return;
    }
    final existing = target[idx];
    target[idx] = existing.copyWith(
      qty: existing.qty + incoming.qty,
      asset: incoming.asset ?? existing.asset,
    );
  }

  LoggedMeal addAnalysis(MealAnalysis a, {String? title, String? photoPath, DateTime? at}) {
    final m = LoggedMeal(
      type: a.type,
      title: title ?? titleFor(a.items),
      time: _stamp(at),
      items: a.items,
      photoPath: photoPath,
    );
    _meals.add(m);
    _commit();
    return m;
  }

  LoggedMeal addFood(MealType t, FoodItem item, {DateTime? at}) {
    final m = LoggedMeal(type: t, title: item.name, time: _stamp(at), items: [item]);
    _meals.add(m);
    _commit();
    return m;
  }

  /// تعديل وجبة موجودة (النوع / الاسم / العناصر). لو العناصر فاضية الوجبة بتتحذف.
  void updateMeal(String id, {MealType? type, String? title, List<FoodItem>? items}) {
    final m = mealById(id);
    if (m == null) return;
    if (type != null) m.type = type;
    if (title != null) m.title = title;
    if (items != null) {
      m.items
        ..clear()
        ..addAll(items);
      if (m.items.isEmpty) _meals.remove(m);
    }
    _commit();
  }

  /// بيرجّع دالة "تراجع".
  VoidCallback removeMeal(String id) {
    final i = _meals.indexWhere((m) => m.id == id);
    if (i < 0) return () {};
    final m = _meals.removeAt(i);
    _commit();
    return () {
      _meals.insert(math.min(i, _meals.length), m);
      _commit();
    };
  }

  VoidCallback removeItem(String mealId, String itemId) {
    final mi = _meals.indexWhere((m) => m.id == mealId);
    if (mi < 0) return () {};
    final meal = _meals[mi];
    final ii = meal.items.indexWhere((e) => e.id == itemId);
    if (ii < 0) return () {};
    final item = meal.items.removeAt(ii);
    final mealRemoved = meal.items.isEmpty;
    if (mealRemoved) _meals.removeAt(mi);
    _commit();
    return () {
      if (mealRemoved && !_meals.contains(meal)) {
        _meals.insert(math.min(mi, _meals.length), meal);
      }
      meal.items.insert(math.min(ii, meal.items.length), item);
      _commit();
    };
  }

  /// صورة الوجبة: path جديد، أو null لإزالتها.
  void setMealPhoto(String id, String? path) {
    final m = mealById(id);
    if (m == null) return;
    m.photoPath = path;
    _commit();
  }

  void toggleFavorite(String id) {
    final m = mealById(id);
    if (m == null) return;
    m.favorite = !m.favorite;
    _commit();
  }

  // ───────────────────────── المسودة (قبل الحفظ) ─────────────────────────
  List<DraftEntry> draftsOn(DateTime day) =>
      _drafts.where((d) => sameDay(d.day, day)).toList();
  List<DraftEntry> draftsFor(MealType t, [DateTime? day]) =>
      draftsOn(day ?? _selected).where((d) => d.type == t).toList();
  int get draftCount => draftsOn(_selected).length;
  int draftKcalOn(DateTime day) => draftsOn(day).fold(0, (s, d) => s + d.item.kcal);

  void addDraft(MealType t, FoodItem item, {String? photoPath, DateTime? day}) {
    _drafts.add(
      DraftEntry(
        day: dateOnly(day ?? _selected),
        type: t,
        item: item,
        photoPath: photoPath,
      ),
    );
    notifyListeners();
  }

  void addDraftAll(MealType t, List<FoodItem> items, {String? photoPath, DateTime? day}) {
    for (final it in items) {
      _drafts.add(
        DraftEntry(
          day: dateOnly(day ?? _selected),
          type: t,
          item: it,
          photoPath: photoPath,
        ),
      );
    }
    notifyListeners();
  }

  void updateDraftItem(String entryId, FoodItem item) {
    for (final d in _drafts) {
      if (d.id == entryId) d.item = item;
    }
    notifyListeners();
  }

  VoidCallback removeDraft(String entryId) {
    final i = _drafts.indexWhere((d) => d.id == entryId);
    if (i < 0) return () {};
    final d = _drafts.removeAt(i);
    notifyListeners();
    return () {
      _drafts.insert(math.min(i, _drafts.length), d);
      notifyListeners();
    };
  }

  void clearDrafts(DateTime day) {
    _drafts.removeWhere((d) => sameDay(d.day, day));
    notifyListeners();
  }

  /// يحفظ كل مسودة اليوم: يجمع الأصناف المتشابهة في نفس الوجبة واليوم.
  Future<void> commitDrafts(
      DateTime day, {
        Future<String?> Function(String? path)? photoSaver,
      }) async {
    final entries = draftsOn(day);
    if (entries.isEmpty) return;
    final now = _clock();
    for (final t in MealType.values) {
      final group = entries.where((e) => e.type == t).toList();
      if (group.isEmpty) continue;

      final savedItems = <FoodItem>[];
      for (final e in group) {
        final rawPhoto = e.item.asset ?? e.photoPath;
        final savedPhoto = photoSaver != null ? await photoSaver(rawPhoto) : rawPhoto;
        _mergeItemIntoList(savedItems, e.item.copyWith(asset: savedPhoto));
      }

      final existingMealIndex = _meals.indexWhere(
            (m) => m.type == t && sameDay(m.time, day),
      );

      if (existingMealIndex >= 0) {
        final existingMeal = _meals[existingMealIndex];
        final mergedItems = List<FoodItem>.of(existingMeal.items);
        for (final item in savedItems) {
          _mergeItemIntoList(mergedItems, item);
        }
        existingMeal.items
          ..clear()
          ..addAll(mergedItems);
        existingMeal.title = titleFor(mergedItems);
      } else {
        _meals.add(
          LoggedMeal(
            type: t,
            title: titleFor(savedItems),
            time: DateTime(day.year, day.month, day.day, now.hour, now.minute),
            items: savedItems,
          ),
        );
      }
    }
    _drafts.removeWhere((d) => sameDay(d.day, day));
    _commit();
  }

  void _commit() {
    notifyListeners();
    _repo.save(List.of(_meals)).catchError((Object e) => debugPrint('تعذر حفظ اليومية: $e'));
  }
}