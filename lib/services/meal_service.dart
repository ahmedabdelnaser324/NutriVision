
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MealService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _meals {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('يجب تسجيل الدخول أولاً');
    }

    return _db.collection('users').doc(user.uid).collection('meals');
  }

  Future<void> addMeal({
    required String name,
    required int calories,
    double protein = 0,
    double carbs = 0,
    double fat = 0,
  }) async {
    await _meals.add({
      'name': name,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // جميع الوجبات المسجلة
  Stream<QuerySnapshot<Map<String, dynamic>>> getMeals() {
    return _meals.orderBy('createdAt', descending: true).snapshots();
  }

  // وجبات اليوم الحالي فقط
  Stream<QuerySnapshot<Map<String, dynamic>>> getTodayMeals() {
    final now = DateTime.now();

    final startOfDay = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final startOfNextDay = startOfDay.add(
      const Duration(days: 1),
    );

    return _meals
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where(
          'createdAt',
          isLessThan: Timestamp.fromDate(startOfNextDay),
        )
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> deleteMeal(String mealId) async {
    await _meals.doc(mealId).delete();
  }
}
