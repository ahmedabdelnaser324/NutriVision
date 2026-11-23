import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_theme.dart';
import '../../services/arabic_digits.dart';
import '../../widgets/diary_widget/app_chip.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/app_background.dart';
import '../../widgets/diary_widget/sufra_dialogs.dart';
import '../../services/models.dart';
import '../../services/meal_analysis_service.dart';
import '../../services/diary_controller.dart';
import '../../screens/add_food_screen/food_search_sheet.dart';
import '../../widgets/diary_widget/photo_picker_sheet.dart';

enum _Phase { camera, describe, preview, analyzing, result }

/// شاشة ١١ — التصوير والتحليل
/// كاميرا حقيقية (أو صورة من المعرض أو وصف نصي) ← معاينة ← تحليل بـ Gemini ← نتيجة.
class AnalyzeScreen extends StatefulWidget {
  const AnalyzeScreen({super.key, this.initialType});
  final MealType? initialType;

  @override
  State<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends State<AnalyzeScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _notes = ['بدون زيت', 'كمية كبيرة', 'كمية صغيرة', 'سكر زيادة', 'مقلي بالسمن'];
  static const _steps = ['تجهيز', 'إرسال', 'فهم', 'حساب'];

  _Phase _phase = _Phase.camera;
  late MealType _meal = widget.initialType ?? MealTypeX.byHour(DateTime.now().hour);
  final Set<String> _selectedNotes = {};
  final _noteCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _service = MealAnalysisService();
  final _picker = ImagePicker();

  CameraController? _cam;
  Future<void> _camOpLock = Future<void>.value();
  bool _camReady = false;
  String? _camError;
  double _zoom = 1, _minZoom = 1, _maxZoom = 1;
  bool _flash = false;

  File? _photo;
  String? _description;
  MealAnalysis? _result;
  int _step = 0; // الخطوة الحالية 1..4
  int _run = 0; // رقم المحاولة لتجاهل ردود قديمة بعد الإلغاء
  bool _showRequest = false;
  Timer? _timer;

  late final AnimationController _scan = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enqueueCameraOp(_initCameraInternal);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _scan.dispose();
    _noteCtrl.dispose();
    _descCtrl.dispose();
    final pending = _cam;
    _cam = null;
    if (pending != null) {
      unawaited(pending.dispose());
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _enqueueCameraOp(_releaseCameraInternal);
    } else if (state == AppLifecycleState.resumed && _phase == _Phase.camera && _cam == null) {
      _enqueueCameraOp(_initCameraInternal);
    }
  }

  Future<void> _enqueueCameraOp(Future<void> Function() op) {
    final next = _camOpLock.catchError((Object _) {}).then((_) => op());
    _camOpLock = next.catchError((Object _) {});
    return next;
  }

  // ───────────────────────── الكاميرا ─────────────────────────
  Future<void> _releaseCamera() => _enqueueCameraOp(_releaseCameraInternal);

  Future<void> _releaseCameraInternal() async {
    final c = _cam;
    _cam = null;
    _camReady = false;
    _flash = false;
    if (mounted) setState(() {});
    if (c == null) return;
    if (mounted) {
      await WidgetsBinding.instance.endOfFrame;
    }
    try {
      await c.dispose();
    } catch (_) {}
  }

  Future<void> _initCamera() => _enqueueCameraOp(_initCameraInternal);

  Future<void> _initCameraInternal() async {
    await _releaseCameraInternal();
    if (!mounted || _phase != _Phase.camera) return;
    setState(() => _camError = null);
    CameraController? c;
    try {
      final cams = await availableCameras();
      if (!mounted || _phase != _Phase.camera) return;
      if (cams.isEmpty) throw CameraException('noCamera', 'no camera');
      final back = cams.firstWhere(
            (e) => e.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      c = CameraController(back, ResolutionPreset.medium, enableAudio: false);
      _cam = c;
      await c.initialize();
      final minZ = await c.getMinZoomLevel();
      final maxZ = await c.getMaxZoomLevel();
      if (!mounted || _cam != c || _phase != _Phase.camera) {
        if (_cam == c) _cam = null;
        await c.dispose();
        return;
      }
      setState(() {
        _camReady = true;
        _minZoom = minZ;
        _maxZoom = maxZ;
        _zoom = minZ.clamp(1.0, maxZ);
      });
    } on CameraException catch (e) {
      if (_cam == c) {
        _cam = null;
        _camReady = false;
      }
      try {
        await c?.dispose();
      } catch (_) {}
      if (!mounted) return;
      final denied = e.code.toLowerCase().contains('permission') || e.code.startsWith('CameraAccess');
      setState(() => _camError = denied
          ? 'محتاجين إذن الكاميرا. فعّله من إعدادات الموبايل أو اختار صورة من المعرض.'
          : 'الكاميرا مش شغالة على الجهاز ده. اختار صورة من المعرض أو اوصف الوجبة.');
    } catch (_) {
      if (_cam == c) {
        _cam = null;
        _camReady = false;
      }
      try {
        await c?.dispose();
      } catch (_) {}
      if (!mounted) return;
      setState(() => _camError = 'تعذر تشغيل الكاميرا. جرّب تاني أو اختار من المعرض.');
    }
  }

  Future<void> _toggleFlash() async {
    final c = _cam;
    if (c == null || !_camReady || !c.value.isInitialized) return;
    try {
      await c.setFlashMode(_flash ? FlashMode.off : FlashMode.torch);
      if (mounted) setState(() => _flash = !_flash);
    } catch (_) {
      if (mounted) showSufraSnack(context, 'الفلاش مش متاح على الجهاز ده');
    }
  }

  Future<void> _setZoom(double z) async {
    final c = _cam;
    if (c == null || !_camReady || !c.value.isInitialized) return;
    final target = z.clamp(_minZoom, _maxZoom).toDouble();
    try {
      await c.setZoomLevel(target);
      if (mounted) setState(() => _zoom = target);
    } catch (_) {}
  }

  Future<void> _capture() async {
    final c = _cam;
    if (c == null || !_camReady || !c.value.isInitialized || c.value.isTakingPicture) return;
    try {
      HapticFeedback.mediumImpact();
      final x = await c.takePicture();
      if (!mounted) return;
      await _showPreview(File(x.path));
    } catch (_) {
      if (mounted) showSufraSnack(context, 'مقدرناش نصوّر، جرّب تاني');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final x = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
      if (x != null && mounted) await _showPreview(File(x.path));
    } catch (_) {
      if (mounted) showSufraSnack(context, 'مقدرناش نفتح المعرض. راجع إذن الصور.');
    }
  }

  Future<void> _showPreview(File f) async {
    await _releaseCamera();
    if (!mounted) return;
    setState(() {
      _photo = f;
      _description = null;
      _phase = _Phase.preview;
    });
  }

  void _retake() {
    setState(() {
      _photo = null;
      _result = null;
      _phase = _Phase.camera;
    });
    _initCamera();
  }

  // ───────────────────────── وصف نصي ─────────────────────────
  Future<void> _switchToDescribe() async {
    await _releaseCamera();
    if (!mounted) return;
    setState(() {
      _photo = null;
      _phase = _Phase.describe;
    });
  }

  void _submitDescription() {
    final text = _descCtrl.text.trim();
    if (text.isEmpty) {
      showSufraSnack(context, 'اكتب وصف الوجبة الأول');
      return;
    }
    _photo = null;
    _startAnalysis(description: text);
  }

  // ───────────────────────── صورة النتيجة ─────────────────────────
  Future<void> _pickResultPhoto() async {
    final r = await pickMealPhoto(context, canRemove: _photo != null);
    if (r == null || !mounted) return;
    setState(() => _photo = r.remove ? null : File(r.path!));
  }

  Widget _addPhotoPlaceholder() => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      color: const Color(0xFF141E3A),
      border: Border.all(color: AppColors.cyan.withValues(alpha: .5)),
    ),
    alignment: Alignment.center,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.add_a_photo_rounded, size: 34, color: AppColors.cyan),
      const SizedBox(height: 8),
      Text('أضف صورة للوجبة (اختياري)', style: AppText.body(13, color: AppColors.textSoft)),
    ]),
  );

  // ───────────────────────── التحليل ─────────────────────────
  Future<void> _startAnalysis({String? description}) async {
    final ticket = ++_run;
    setState(() {
      _phase = _Phase.analyzing;
      _step = 1;
      _result = null;
      _description = description;
    });
    _timer?.cancel();
    try {
      final bytes = (_photo != null && description == null) ? await _photo!.readAsBytes() : null;
      if (!mounted || ticket != _run) return;
      setState(() => _step = 2);
      _timer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted && ticket == _run && _phase == _Phase.analyzing && _step == 2) setState(() => _step = 3);
      });
      final notes = [..._selectedNotes, if (_noteCtrl.text.trim().isNotEmpty) _noteCtrl.text.trim()];
      final r = await _service.analyze(
        image: bytes,
        mime: (_photo?.path.toLowerCase().endsWith('.png') ?? false) ? 'image/png' : 'image/jpeg',
        type: _meal,
        notes: notes,
        description: description,
      );
      if (!mounted || ticket != _run) return;
      _timer?.cancel();
      setState(() {
        _result = r;
        _step = 4;
      });
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!mounted || ticket != _run) return;
      setState(() => _phase = _Phase.result);
    } on AnalysisException catch (e) {
      _fail(ticket, e.message);
    } catch (_) {
      _fail(ticket, 'حصل خطأ غير متوقع، جرّب تاني');
    }
  }

  void _fail(int ticket, String message) {
    if (!mounted || ticket != _run) return;
    _timer?.cancel();
    showSufraSnack(context, message);
    if (_photo == null) {
      _retake();
    } else {
      setState(() {
        _phase = _Phase.preview;
        _step = 0;
      });
    }
  }

  void _cancelAnalysis() {
    _run++;
    _timer?.cancel();
    if (_photo == null) {
      _retake();
    } else {
      setState(() {
        _phase = _Phase.preview;
        _step = 0;
      });
    }
  }

  Future<void> _manualEntry() async {
    _run++;
    _timer?.cancel();
    final item = await showFoodSearchSheet(context);
    if (!mounted) return;
    if (item == null) {
      _cancelAnalysis();
      return;
    }
    DiaryController.instance.addDraft(_meal, item, photoPath: _photo?.path);
    Navigator.pushNamedAndRemoveUntil(context, '/diary', (_) => false);
  }

  Widget _photoOrIcon({BoxFit fit = BoxFit.cover}) {
    final p = _photo;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: p != null
          ? Image.file(p, fit: fit, width: double.infinity, height: double.infinity)
          : Container(
        color: const Color(0xFF141E3A),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        child: Text(
          _description ?? '',
          textAlign: TextAlign.center,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          style: AppText.body(15, color: AppColors.textSoft),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F24),
      body: AppBackground(
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: switch (_phase) {
              _Phase.camera => _buildCamera(),
              _Phase.describe => _buildDescribeView(),
              _Phase.preview => _buildPreview(),
              _Phase.analyzing => _buildAnalyzing(),
              _Phase.result => _buildResult(),
            },
          ),
        ),
      ),
    );
  }

  // ───────────────────────── 1) الكاميرا ─────────────────────────
  Widget _buildViewfinder() {
    final c = _cam;
    if (_phase == _Phase.camera && _camReady && c != null && c.value.isInitialized && c.value.previewSize != null) {
      final s = c.value.previewSize!;
      final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
      final w = isPortrait ? s.height : s.width;
      final h = isPortrait ? s.width : s.height;
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(width: w, height: h, child: CameraPreview(c)),
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), color: const Color(0xFF0E1630)),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: _camError == null
          ? const CircularProgressIndicator(color: AppColors.cyan)
          : Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.no_photography_outlined, size: 44, color: AppColors.textSoft),
        const SizedBox(height: 12),
        Text(_camError!, textAlign: TextAlign.center, style: AppText.body(14)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          _SelectChip('جرّب تاني', onTap: _initCamera),
          _SelectChip('من المعرض', onTap: _pickFromGallery),
          _SelectChip('اوصف الوجبة', onTap: _switchToDescribe),
        ]),
      ]),
    );
  }

  Widget _buildDescribeView() {
    return Padding(
      key: const ValueKey('describe'),
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        Row(children: [
          _IconBtn(Icons.close_rounded, onTap: () => Navigator.maybePop(context)),
          const Spacer(),
          _ModeSegment(isDescribe: true, onCamera: _retake, onDescribe: _switchToDescribe),
          const Spacer(),
          const SizedBox(width: 44),
        ]),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF101936),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: .16)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('اوصف اللي أكلته', style: AppText.title(20)),
            const SizedBox(height: 4),
            Text('مثلاً: طبق كشري وسط ونص رغيف عيش وكوباية شاي بلبن', style: AppText.body(12.5, color: AppColors.textSoft)),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              autofocus: true,
              maxLines: 4,
              style: AppText.body(14),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF19254A),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: .2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.cyan),
                ),
              ),
            ),
            const SizedBox(height: 14),
            GradientButton(text: 'حلّل الوصف', onPressed: _submitDescription),
          ]),
        ),
      ]),
    );
  }

  Widget _buildCamera() {
    return Stack(key: const ValueKey('camera'), children: [
      Positioned.fill(top: 90, bottom: 210, left: 14, right: 14, child: _buildViewfinder()),
      if (_camReady) ...[
        const Positioned.fill(top: 110, bottom: 220, left: 18, right: 18, child: _ScanFrame()),
        Positioned.fill(
          top: 110,
          bottom: 220,
          left: 18,
          right: 18,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _scan,
              builder: (_, _) => Align(
                alignment: Alignment(0, -1 + 2 * _scan.value),
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Colors.transparent, AppColors.cyan, Colors.white, AppColors.cyan, Colors.transparent]),
                    boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: .7), blurRadius: 14, spreadRadius: 2)],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
      Positioned(
        top: 8,
        left: 14,
        right: 14,
        child: Row(children: [
          _IconBtn(Icons.close_rounded, onTap: () => Navigator.maybePop(context)),
          const Spacer(),
          _ModeSegment(isDescribe: false, onCamera: _retake, onDescribe: _switchToDescribe),
          const Spacer(),
          _IconBtn(Icons.bolt_rounded, active: _flash, onTap: _toggleFlash),
        ]),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 128,
        child: Column(children: [
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Text(
              _camReady ? 'وجّه الكاميرا للطبق واضغط للتصوير' : 'بنجهّز الكاميرا…',
              style: AppText.body(13, weight: FontWeight.w700, color: Colors.greenAccent.shade400),
            ),
          ),
          const SizedBox(height: 10),
          const _ChecklistBar(),
        ]),
      ),
      Positioned(left: 16, right: 16, bottom: 20, child: _buildDock()),
    ]);
  }

  Widget _buildDock() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        GestureDetector(
          onTap: _pickFromGallery,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: .3)),
            ),
            child: const Icon(Icons.photo_library_outlined, size: 24),
          ),
        ),
        GestureDetector(
          onTap: _capture,
          child: Opacity(
            opacity: _camReady ? 1 : .4,
            child: Container(
              width: 74,
              height: 74,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.cyan, width: 3),
                boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: .6), blurRadius: 18)],
              ),
              child: const DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .08), borderRadius: BorderRadius.circular(99)),
          child: Row(children: [
            for (final z in const [.5, 1.0, 2.0])
              GestureDetector(
                onTap: () => _setZoom(z),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: _zoom == z ? Colors.white : Colors.transparent),
                  child: Text(
                    z == .5 ? '٠٫٥' : '${ar(z.toInt())}×',
                    style: AppText.body(13, weight: FontWeight.w700, color: _zoom == z ? Colors.black87 : Colors.white70),
                  ),
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  // ───────────────────────── 2) المعاينة ─────────────────────────
  Widget _buildPreview() {
    return Stack(key: const ValueKey('preview'), children: [
      Positioned(top: 70, left: 24, right: 24, height: 280, child: _photoOrIcon()),
      Positioned(
        top: 8,
        left: 16,
        right: 16,
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          GestureDetector(
            onTap: _retake,
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                const Icon(Icons.refresh_rounded, size: 18),
                const SizedBox(width: 7),
                Text('إعادة التصوير', style: AppText.body(13)),
              ]),
            ),
          ),
          Text('الصورة جاهزة؟', style: AppText.title(24)),
          const SizedBox(width: 44),
        ]),
      ),
      Positioned(
        top: 366,
        bottom: 100,
        left: 16,
        right: 16,
        child: GlassCard(
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('نوع الوجبة', style: AppText.body(12.5, color: AppColors.textSoft)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in MealType.values) _SelectChip(m.label, selected: _meal == m, onTap: () => setState(() => _meal = m)),
                ],
              ),
              const SizedBox(height: 14),
              Text('ملاحظات تساعد الذكاء الاصطناعي (اختياري)', style: AppText.body(12.5, color: AppColors.textSoft)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final n in _notes)
                    _SelectChip(
                      n,
                      outlined: true,
                      selected: _selectedNotes.contains(n),
                      onTap: () => setState(() => _selectedNotes.contains(n) ? _selectedNotes.remove(n) : _selectedNotes.add(n)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: .22)),
                ),
                child: Row(children: [
                  const Icon(Icons.edit_note_rounded, color: AppColors.cyan, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _noteCtrl,
                      style: AppText.body(14),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'أو اكتب ملاحظة بإيدك',
                        hintStyle: AppText.body(13, color: Colors.white38),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.textSoft),
                const SizedBox(width: 6),
                Expanded(child: Text('الصورة بتتبعت مشفّرة لتحليل الوجبة بس', style: AppText.body(12, color: AppColors.textSoft))),
              ]),
            ]),
          ),
        ),
      ),
      Positioned(
        left: 16,
        right: 16,
        bottom: 30,
        child: GradientButton(text: 'حلّل بالذكاء الاصطناعي', onPressed: _startAnalysis),
      ),
    ]);
  }

  // ───────────────────────── 3) التحليل ─────────────────────────
  Widget _buildAnalyzing() {
    final items = _result?.items;
    return Stack(key: const ValueKey('analyzing'), children: [
      Positioned(top: 80, left: 40, right: 40, height: 230, child: _photoOrIcon()),
      Positioned(
        top: 8,
        left: 16,
        right: 16,
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _IconBtn(Icons.code_rounded, onTap: () => setState(() => _showRequest = !_showRequest)),
          Column(children: [
            Text('بنحلّل وجبتك', style: AppText.title(24)),
            Text(_stepSubtitle, style: AppText.body(12, color: AppColors.cyan)),
          ]),
          const SizedBox(width: 44),
        ]),
      ),
      if (_showRequest) Positioned(top: 70, left: 16, right: 16, child: _RequestPeek(onClose: () => setState(() => _showRequest = false))),
      Positioned(
        top: 330,
        bottom: 30,
        left: 16,
        right: 16,
        child: GlassCard(
          child: Column(children: [
            _Stepper(current: _step, labels: _steps),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('المكتشف في طبقك', style: AppText.body(15, weight: FontWeight.w700)),
              const AppChip('Gemini', color: Color(0x597C3AED), textColor: Color(0xFFE9D5FF)),
            ]),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(physics: const NeverScrollableScrollPhysics(), padding: EdgeInsets.zero, children: [
                if (items == null)
                  for (var i = 0; i < 3; i++) const _SkeletonRow()
                else
                  for (var i = 0; i < items.length; i++) _AnalyzeRow(index: i + 1, item: items[i], loaded: true),
              ]),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _SelectChip('إلغاء', onTap: _cancelAnalysis),
              const SizedBox(width: 10),
              _SelectChip('أدخل يدوياً', onTap: _manualEntry),
            ]),
          ]),
        ),
      ),
    ]);
  }

  String get _stepSubtitle => switch (_step) {
    1 => 'بنجهّز الصورة…',
    2 => 'بنبعت للتحليل…',
    3 => 'بنفهم مكونات الطبق…',
    _ => 'بنحسب السعرات…',
  };

  // ───────────────────────── 4) النتيجة ─────────────────────────
  Widget _buildResult() {
    final r = _result!;
    final m = r.macros;
    final kc = m.protein * 4 + m.carbs * 4 + m.fat * 9;
    double share(num g, num k) => kc == 0 ? 0 : (g * k / kc).toDouble();
    return Stack(key: const ValueKey('result'), children: [
      Positioned(
        top: 50,
        left: 60,
        right: 60,
        height: 180,
        child: GestureDetector(
          onTap: _pickResultPhoto,
          child: _photo == null ? _addPhotoPlaceholder() : _photoOrIcon(),
        ),
      ),
      Positioned(top: 8, left: 16, right: 16, child: Center(child: Text('الوجبة جاهزة', style: AppText.title(24)))),
      Positioned(
        top: 250,
        bottom: 30,
        left: 16,
        right: 16,
        child: GlassCard(
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: r.totalKcal.toDouble()),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOut,
                    builder: (_, v, _) => Text(ar(v.round()), style: AppText.body(46, weight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 4),
                  Text('سعرة · النطاق المتوقع ${ar(r.rangeMin)} – ${ar(r.rangeMax)}', style: AppText.body(12.5, color: AppColors.textSoft)),
                ]),
                AppChip(
                  'ثقة ${r.confidence.label}',
                  color: r.confidence == Confidence.low ? AppColors.orange : Colors.greenAccent.shade400,
                  icon: const Icon(Icons.check_rounded, size: 13, color: Colors.black87),
                ),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                _MacroTile('بروتين', m.protein, share(m.protein, 4), const [AppColors.cyan, AppColors.cyan]),
                const SizedBox(width: 8),
                _MacroTile('كارب', m.carbs, share(m.carbs, 4), const [AppColors.orange, AppColors.cyan]),
                const SizedBox(width: 8),
                _MacroTile('دهون', m.fat, share(m.fat, 9), const [AppColors.textSoft, AppColors.textSoft]),
              ]),
              const SizedBox(height: 12),
              if (r.isDemo)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.orange.withValues(alpha: .5)),
                  ),
                  child: Text(
                    'تحليل تجريبي: مفتاح Gemini مش متضاف (--dart-define=GEMINI_API_KEY).',
                    style: AppText.body(12.5, color: AppColors.cyan),
                  ),
                ),
              for (var i = 0; i < r.items.length; i++) _AnalyzeRow(index: i + 1, item: r.items[i], loaded: true),
              if (r.warning != null)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.orange.withValues(alpha: .5)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.cyan, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(r.warning!, style: AppText.body(12.5, color: AppColors.cyan))),
                  ]),
                ),
              const SizedBox(height: 14),
              GradientButton(
                text: 'أضف للوجبة',
                onPressed: () {
                  DiaryController.instance.addDraftAll(r.type, r.items, photoPath: _photo?.path);
                  Navigator.pushNamedAndRemoveUntil(context, '/diary', (_) => false);
                },
              ),
            ]),
          ),
        ),
      ),
    ]);
  }
}

// ───────────────────────── مكوّنات خاصة بالشاشة ─────────────────────────

class _IconBtn extends StatelessWidget {
  const _IconBtn(this.icon, {required this.onTap, this.active = false});
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? const Color(0xFFFDE68A) : Colors.white.withValues(alpha: .12),
        border: Border.all(color: Colors.white.withValues(alpha: .28)),
      ),
      child: Icon(icon, size: 21, color: active ? Colors.black87 : Colors.white),
    ),
  );
}

class _ModeSegment extends StatelessWidget {
  const _ModeSegment({required this.isDescribe, required this.onCamera, required this.onDescribe});
  final bool isDescribe;
  final VoidCallback onCamera;
  final VoidCallback onDescribe;

  @override
  Widget build(BuildContext context) {
    Widget seg(String t, {required bool on}) => AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        gradient: on ? const LinearGradient(colors: [AppColors.orange, AppColors.cyan]) : null,
      ),
      child: Text(t, style: AppText.body(13, weight: on ? FontWeight.w700 : FontWeight.w400, color: on ? Colors.white : AppColors.textSoft)),
    );
    return GlassCard(
      padding: const EdgeInsets.all(4),
      child: Row(children: [
        GestureDetector(onTap: onDescribe, child: seg('وصف', on: isDescribe)),
        GestureDetector(onTap: onCamera, child: seg('صورة', on: !isDescribe)),
        GestureDetector(onTap: () => Navigator.pushReplacementNamed(context, '/barcode'), child: seg('باركود', on: false)),
      ]),
    );
  }
}

class _ScanFrame extends StatelessWidget {
  const _ScanFrame();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _CornersPainter());
}

class _CornersPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    const len = 46.0, r = 24.0;
    final p = Paint()
      ..color = const Color(0xFF22C55E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    Path corner(double x, double y, double dx, double dy) => Path()
      ..moveTo(x, y + dy * len)
      ..lineTo(x, y + dy * r)
      ..quadraticBezierTo(x, y, x + dx * r, y)
      ..lineTo(x + dx * len, y);
    c.drawPath(corner(0, 0, 1, 1), p);
    c.drawPath(corner(s.width, 0, -1, 1), p);
    c.drawPath(corner(0, s.height, 1, -1), p);
    c.drawPath(corner(s.width, s.height, -1, -1), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _ChecklistBar extends StatelessWidget {
  const _ChecklistBar();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        for (final t in const ['إضاءة كافية', 'ثبّت إيدك', 'الطبق كامل'])
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(color: Color(0xFF22c55E), shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, size: 13, color: Colors.black87),
            ),
            const SizedBox(width: 6),
            Text(t, style: AppText.body(12.5)),
          ]),
      ]),
    ),
  );
}

class _SelectChip extends StatelessWidget {
  const _SelectChip(this.label, {required this.onTap, this.selected = false, this.outlined = false});
  final String label;
  final VoidCallback onTap;
  final bool selected, outlined;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        gradient: selected ? const LinearGradient(colors: [AppColors.orange, AppColors.cyan]) : null,
        color: selected ? null : Colors.white.withValues(alpha: outlined ? .04 : .1),
        border: Border.all(
          color: selected ? Colors.transparent : (outlined ? AppColors.cyan.withValues(alpha: .45) : Colors.white.withValues(alpha: .22)),
        ),
        boxShadow: selected ? [BoxShadow(color: AppColors.cyan.withValues(alpha: .4), blurRadius: 14)] : null,
      ),
      child: Text(label, style: AppText.body(13, weight: selected ? FontWeight.w700 : FontWeight.w400)),
    ),
  );
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.current, required this.labels});
  final int current;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < labels.length; i++) {
      final n = i + 1;
      final done = current > n, active = current == n;
      children.add(Column(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done || active ? AppColors.orange : Colors.white.withValues(alpha: .12),
            boxShadow: active ? [BoxShadow(color: AppColors.orange.withValues(alpha: .7), blurRadius: 12)] : null,
          ),
          child: done ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : Text(ar(n), style: AppText.body(13, weight: FontWeight.w700)),
        ),
        const SizedBox(height: 4),
        Text(labels[i], style: AppText.body(11, color: current >= n ? Colors.white : AppColors.textSoft)),
      ]));
      if (i < labels.length - 1) {
        children.add(Expanded(
          child: Container(
            height: 3,
            margin: const EdgeInsets.only(top: 11, left: 4, right: 4),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: Colors.white.withValues(alpha: .12)),
            alignment: Alignment.centerRight,
            child: AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 600),
              widthFactor: current > n ? 1 : 0,
              child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: AppColors.orange)),
            ),
          ),
        ));
      }
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

class _AnalyzeRow extends StatelessWidget {
  const _AnalyzeRow({required this.index, required this.item, required this.loaded});
  final int index;
  final FoodItem item;
  final bool loaded;

  @override
  Widget build(BuildContext context) {
    final warn = item.needsReview;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: warn ? AppColors.orange.withValues(alpha: .7) : Colors.white.withValues(alpha: .12)),
      ),
      child: Row(children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, color: warn ? AppColors.orange : AppColors.cyan),
          child: Text(ar(index), style: AppText.body(13, color: Colors.black87, weight: FontWeight.w700)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(item.name, style: AppText.body(14, weight: FontWeight.w700)),
              if (warn && loaded) ...[const SizedBox(width: 6), const AppChip('راجعه', color: AppColors.orange)],
            ]),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                loaded ? item.portion : 'بنقدّر الكمية…',
                key: ValueKey(loaded),
                style: AppText.body(12, color: loaded ? AppColors.textSoft : AppColors.cyan),
              ),
            ),
          ]),
        ),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: loaded ? item.kcal.toDouble() : 0),
          duration: const Duration(milliseconds: 700),
          builder: (_, v, _) => Text(
            loaded ? '${warn ? '+' : ''}${ar(v.round())}' : '٠٠٠',
            style: AppText.body(18, color: loaded ? AppColors.textSoft : Colors.white38),
          ),
        ),
      ]),
    );
  }
}

class _MacroTile extends StatelessWidget {
  const _MacroTile(this.label, this.grams, this.fill, this.colors);
  final String label;
  final int grams;
  final double fill;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${ar(grams)} جم', style: AppText.body(15, weight: FontWeight.w700)),
        Text(label, style: AppText.body(11.5, color: AppColors.textSoft)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 5,
            color: Colors.white.withValues(alpha: .12),
            alignment: Alignment.centerRight,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fill),
              duration: const Duration(milliseconds: 1000),
              builder: (_, v, _) => FractionallySizedBox(
                widthFactor: v,
                child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: colors))),
              ),
            ),
          ),
        ),
      ]),
    ),
  );
}

class _RequestPeek extends StatelessWidget {
  const _RequestPeek({required this.onClose});
  final VoidCallback onClose;

  Widget _section(String label, String text, {bool ltr = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppText.body(12, weight: FontWeight.w700, color: AppColors.cyan)),
      const SizedBox(height: 3),
      Directionality(
        textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
        child: SelectableText(
          text,
          style: TextStyle(fontFamily: ltr ? 'monospace' : null, fontSize: 11.5, color: AppColors.cyan, height: 1.45),
        ),
      ),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final d = MealAnalysisService.lastDebug;
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .55),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('حوار الذكاء الاصطناعي (للمطوّر)', style: AppText.body(13, color: AppColors.cyan)),
              GestureDetector(onTap: onClose, child: const Icon(Icons.close_rounded, size: 18)),
            ]),
            const SizedBox(height: 8),
            if (d == null)
              _section(
                'الحالة',
                MealAnalysisService.isConfigured
                    ? 'لسه مفيش طلب اتبعت.'
                    : 'مفيش مفتاح في lib/core/secrets.dart، فالتحليل تجريبي ومبيتبعتش لأي خدمة.',
              )
            else ...[
              _section('المزوّد / الموديل', '${d.provider} · ${d.model}', ltr: true),
              _section('الرابط (POST)', d.url, ltr: true),
              _section('محتوى الطلب', d.hasImage ? 'صورة (base64) + البرومبت' : 'البرومبت فقط (وصف نصي)'),
              _section('البرومبت المبعوت', d.prompt),
              _section('الرد الخام', d.response ?? d.error ?? 'لسه مستنيين الرد…', ltr: d.response != null),
            ],
          ]),
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: .12)),
    ),
    child: Row(children: [
      Container(width: 26, height: 26, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .12))),
      const SizedBox(width: 10),
      Expanded(child: Text('بنقدّر الكمية…', style: AppText.body(12, color: AppColors.cyan))),
      Text('٠٠٠', style: AppText.body(18, color: Colors.white38)),
    ]),
  );
}