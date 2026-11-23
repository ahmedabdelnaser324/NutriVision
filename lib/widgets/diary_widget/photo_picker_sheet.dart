import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_theme.dart';
import 'sufra_dialogs.dart';

/// نتيجة اختيار صورة الوجبة: ملف جديد، أو طلب إزالة الصورة الحالية.
class PhotoPick {
  const PhotoPick.file(String this.path) : remove = false;
  const PhotoPick.remove()
      : path = null,
        remove = true;
  final String? path;
  final bool remove;
}

/// المستخدم هو اللي بيضيف صورة وجبته: يصوّر بالكاميرا أو يختار من المعرض (أو يشيل الصورة).
Future<PhotoPick?> pickMealPhoto(BuildContext context, {bool canRemove = false}) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      Widget opt(IconData icon, String label, String id, {Color? color}) => InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.pop(ctx, id),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .1),
                      border: Border.all(color: Colors.white24)),
                  child: Icon(icon, color: color ?? AppColors.cyan),
                ),
                const SizedBox(width: 12),
                Text(label, style: AppText.body(15, weight: FontWeight.w700)),
              ]),
            ),
          );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Material(
            color: const Color(0xFF0E1630),
            borderRadius: BorderRadius.circular(30),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('صورة الوجبة', style: AppText.title(20)),
                const SizedBox(height: 6),
                opt(Icons.photo_camera_rounded, 'صوّر بالكاميرا', 'camera'),
                opt(Icons.photo_library_rounded, 'اختار من المعرض', 'gallery'),
                if (canRemove) opt(Icons.delete_outline_rounded, 'شيل الصورة', 'remove', color: AppColors.orange),
              ]),
            ),
          ),
        ),
      );
    },
  );
  if (choice == null) return null;
  if (choice == 'remove') return const PhotoPick.remove();
  try {
    final x = await ImagePicker().pickImage(
      source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    return x == null ? null : PhotoPick.file(x.path);
  } catch (_) {
    if (context.mounted) showSufraSnack(context, 'مقدرناش نفتح الكاميرا أو المعرض. راجع الأذونات.');
    return null;
  }
}
