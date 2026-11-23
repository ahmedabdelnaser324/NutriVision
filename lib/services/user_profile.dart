import 'package:shared_preferences/shared_preferences.dart';

/// حساسية المستخدم (وسوم Open Food Facts). بتتظبط من شاشة الإعداد/الحساب.
class UserProfile {
  UserProfile._();
  static const _key = 'sufra.allergies';
  static Set<String> allergies = {};

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    allergies = (p.getStringList(_key) ?? const []).toSet();
  }

  static Future<void> setAllergies(Set<String> value) async {
    allergies = value;
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_key, value.toList());
  }
}
