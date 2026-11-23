import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 1. استيراد فايرستور
import 'package:firebase_auth/firebase_auth.dart'; // 2. استيراد المصادقة لجلب الـ UID
import 'models.dart';

/// مصدر حفظ اليومية. النسخة الحالية محلية على الجهاز؛
/// أو سحابية باستخدام Firestore.
abstract class MealRepository {
  Future<List<LoggedMeal>> load();
  Future<void> save(List<LoggedMeal> meals);
}

class LocalMealRepository implements MealRepository {
  static const _key = 'sufra.meals.v1';

  @override
  Future<List<LoggedMeal>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return [for (final e in list) LoggedMeal.fromJson(Map<String, dynamic>.from(e as Map))];
    } catch (_) {
      return []; // بيانات تالفة: ابدأ من جديد بدل ما التطبيق يقع
    }
  }

  @override
  Future<void> save(List<LoggedMeal> meals) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(meals.map((m) => m.toJson()).toList()));
  }
}

/// للاختبارات.
class InMemoryMealRepository implements MealRepository {
  String _store = '[]';

  @override
  Future<List<LoggedMeal>> load() async =>
      [for (final e in jsonDecode(_store) as List) LoggedMeal.fromJson(Map<String, dynamic>.from(e as Map))];

  @override
  Future<void> save(List<LoggedMeal> meals) async => _store = jsonEncode(meals.map((m) => m.toJson()).toList());
}

/// 🚀 مصدر الحفظ الجديد على سحابة Cloud Firestore
class FirestoreMealRepository implements MealRepository {
  // بيجيب الـ UID بتاع المستخدم اللي مسجل حالياً ديناميكياً
  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? 'test_user';

  // مسار حفظ الوجبات خاص بكل مستخدم: users/{userId}/meals
  CollectionReference get _mealsRef =>
      FirebaseFirestore.instance.collection('users').doc(_userId).collection('meals');

  @override
  Future<List<LoggedMeal>> load() async {
    try {
      final snapshot = await _mealsRef.get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // ضمان حفظ الـ ID الخاص بالمستند
        return LoggedMeal.fromJson(data);
      }).toList();
    } catch (_) {
      return []; // لو فيه مشكلة في الشبكة، يرجع لستة فاضية بدل ما التطبيق يقع
    }
  }

  @override
  @override
  Future<void> save(List<LoggedMeal> meals) async {
    // حفظ الوجبات وحذف العناصر المحذوفة باستخدام الـ Batch لضمان السرعة والأمان
    final batch = FirebaseFirestore.instance.batch();

    // 1. جلب الوجبات الحالية من الفايربيس لمعرفة ما تم حذفه
    final snapshot = await _mealsRef.get();
    final incomingIds = meals.map((m) => m.id).toSet();

    // 2. حذف أي مستند لم يعد موجوداً في القائمة الحالية
    for (final doc in snapshot.docs) {
      if (!incomingIds.contains(doc.id)) {
        batch.delete(doc.reference);
      }
    }

    // 3. تحديث أو إضافة الوجبات الموجودة حالياً
    for (final meal in meals) {
      final docRef = _mealsRef.doc(meal.id);
      batch.set(docRef, meal.toJson());
    }

    await batch.commit();
  }
}