import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// بينسخ صورة الوجبة لمكان دائم (الكاميرا بتحط الصور في مجلد مؤقت).
class PhotoStore {
  PhotoStore._();

  static Future<String?> persist(String? tempPath) async {
    if (tempPath == null) return null;
    try {
      final dir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'meals'));
      await dir.create(recursive: true);
      final dest = p.join(dir.path, 'meal_${DateTime.now().microsecondsSinceEpoch}${p.extension(tempPath)}');
      await File(tempPath).copy(dest);
      return dest;
    } catch (_) {
      return tempPath;
    }
  }
}
