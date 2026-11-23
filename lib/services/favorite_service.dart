import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoriteService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _favorites {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('يجب تسجيل الدخول أولاً');
    }

    return _db.collection('users').doc(user.uid).collection('favorites');
  }

  Future<void> addFavorite({
    required String name,
    required int calories,
    double protein = 0,
    double carbs = 0,
    double fat = 0,
  }) async {
    await _favorites.add({
      'name': name,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> toggleFavorite({
    required String name,
    required int calories,
    double protein = 0,
    double carbs = 0,
    double fat = 0,
  }) async {
    final existing = await _favorites.where('name', isEqualTo: name).get();

    if (existing.docs.isNotEmpty) {
      for (final doc in existing.docs) {
        await doc.reference.delete();
      }
      return false;
    }

    await addFavorite(
      name: name,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
    );

    return true;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getFavorites() {
    return _favorites.orderBy('createdAt', descending: true).snapshots();
  }

  Future<void> deleteFavorite(String favoriteId) async {
    await _favorites.doc(favoriteId).delete();
  }
}
