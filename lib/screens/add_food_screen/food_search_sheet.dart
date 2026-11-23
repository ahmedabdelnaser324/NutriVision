import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_theme.dart';
import '../../services/arabic_digits.dart';
import '../../widgets/diary_widget/food_thumb.dart';
import '../../widgets/glass_widgets.dart';
import '../../services/food_catalog.dart';
import '../../services/models.dart';

/// بحث يدوي في كتالوج الأكلات أو إضافة أكلة مخصصة. بيرجّع FoodItem أو null.
Future<FoodItem?> showFoodSearchSheet(BuildContext context) {
  return showModalBottomSheet<FoodItem>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF0E1630),
    builder: (_) => const _FoodSearchSheet(),
  );
}

class _FoodSearchSheet extends StatefulWidget {
  const _FoodSearchSheet();
  @override
  State<_FoodSearchSheet> createState() => _FoodSearchSheetState();
}

class _FoodSearchSheetState extends State<_FoodSearchSheet> {
  final _q = TextEditingController();
  final _kcal = TextEditingController();
  bool _custom = false;
  
  // 1️⃣ متغيرات اختيار الصورة المخصصة
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _q.dispose();
    _kcal.dispose();
    super.dispose();
  }

  // 2️⃣ دالة اختيار الصورة من المعرض
  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  void _addCustom() {
    final name = _q.text.trim();
    final k = int.tryParse(_kcal.text.trim());
    if (name.isEmpty || k == null || k <= 0) return;
    
    // تمرير مسار الصورة المخصصة لو المستخدم اختر، وإلا استخدام المطابقة الافتراضية
    Navigator.pop(
      context,
      FoodItem(
        name: name,
        portion: 'حصة واحدة',
        kcal: k,
        asset: _selectedImage?.path ?? FoodAssets.match(name),
      ),
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: AppText.body(14, color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withValues(alpha: .08),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: .25))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.cyan, width: 1.5)),
      );

  @override
  Widget build(BuildContext context) {
    final results = FoodCatalog.search(_q.text);
    final mq = MediaQuery.of(context);
    final h = mq.size.height;
    final kb = mq.viewInsets.bottom;
    final bottomInset = kb > mq.padding.bottom ? kb : mq.padding.bottom;
    final sheetH = (h - kb - mq.padding.top - 60).clamp(320.0, h * .78).toDouble();
    
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottomInset),
      child: GlassCard(
         child: SizedBox(
          height: sheetH,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(9)))),
            const SizedBox(height: 12),
            Text('دوّر على أكلة', style: AppText.title(20)),
            const SizedBox(height: 10),
            TextField(controller: _q, autofocus: false, style: AppText.body(14), onChanged: (_) => setState(() {}), decoration: _dec('اكتب اسم الأكلة (كشري، فول، فراخ...)')),
            const SizedBox(height: 10),
            Expanded(
              child: _custom
                  ? ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        Text('اكتب اسم الأكلة فوق وسعراتها هنا', style: AppText.body(12,color: AppColors.textSoft)),
                        const SizedBox(height: 12),
                        
                        // 3️⃣ زرار وعرض الصورة المخصصة
                        Center(
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.cyan.withValues(alpha: .5), width: 1.5),
                              ),
                              child: _selectedImage != null
                                  ? Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  image: DecorationImage(
                                    image: FileImage(_selectedImage!),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.add_a_photo, color: AppColors.cyan, size: 28),
                                        SizedBox(height: 4),
                                        Text('صورة', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        TextField(
                          controller: _kcal,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: AppText.body(18,weight: FontWeight.w700),
                          decoration: _dec('السعرات (رقم)'),
                        ),
                        const SizedBox(height: 24),
                        GradientButton(text: 'أضف', onPressed: _addCustom),
                      ],
                    )
                  : ListView(padding: EdgeInsets.zero, children: [
                      for (final e in results)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => Navigator.pop(context, e.toItem()),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(children: [
                              FoodThumb(asset: e.image, width: 44, height: 50, image: 46, float: false),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(e.name, style: AppText.body(15, weight: FontWeight.w700)),
                                  Text(e.portion, style: AppText.body(12,color: AppColors.textSoft)),
                                ]),
                              ),
                              Text(ar(e.kcal), style: AppText.body(16,weight: FontWeight.w700)),
                            ]),
                          ),
                        ),
                      if (results.isEmpty) Padding(padding: const EdgeInsets.all(16),
                          child: Center(child: Text('مفيش نتيجة بالاسم ده', style: AppText.body(12,color: AppColors.textSoft)))),
                    ]),
            ),
            if (!_custom) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => setState(() => _custom = true),
                child: Container(
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: AppColors.orange.withValues(alpha: .14),
                    border: Border.all(color: AppColors.cyan.withValues(alpha: .7)),
                  ),
                  child: Text('+ أضف أكلة بسعراتي (يدوي)',
                      style: AppText.body(15, weight: FontWeight.w700, color: AppColors.cyan)),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}