import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../../core/utils/gtin.dart';
import '../../widgets/glass_widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../widgets/app_background.dart';
import '../../services/models.dart';
import '../../services/api_client.dart';
import '../../services/product_service.dart';
import '../../services/user_profile.dart';

enum _ScanState { idle, searching, ok, warn }

/// شاشة ١٥ — الباركود
/// مسح حقيقي بالكاميرا (mobile_scanner) أو كتابة الرقم يدوياً مع تحقق من الـ checksum،
/// والاستعلام عن المنتج من Open Food Facts عبر Dio.
class BarcodeScreen extends StatefulWidget {
  const BarcodeScreen({super.key});

  @override
  State<BarcodeScreen> createState() => _BarcodeScreenState();
}

class _BarcodeScreenState extends State<BarcodeScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _ctrl = TextEditingController();
  final _service = ProductService();
  final _scanner = MobileScannerController(
    autoStart: false,
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA],
  );
  Future<void> _scannerLock = Future<void>.value();
  bool _busy = false;
  bool _navigating = false;
  late final AnimationController _laser =
  AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);

  _ScanState _state = _ScanState.idle;
  bool _cameraOn = false;
  bool _flash = false;
  bool _invalid = false;
  String _message = 'وجّه الكاميرا ناحية الباركود';

  Color get _frameColor => switch (_state) {
    _ScanState.idle || _ScanState.searching => const Color(0xFF22D3EE),
    _ScanState.ok => Colors.greenAccent.shade400,
    _ScanState.warn => const Color(0xFFFB923C),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_scanner.dispose());
    _ctrl.dispose();
    _laser.dispose();
    super.dispose();
  }

  Future<void> _enqueueScannerOp(Future<void> Function() op) {
    final next = _scannerLock.catchError((Object _) {}).then((_) => op());
    _scannerLock = next.catchError((Object _) {});
    return next;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_cameraOn || _navigating) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(_enqueueScannerOp(() async {
        try {
          await _scanner.start();
        } catch (_) {}
      }));
    } else if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      unawaited(_enqueueScannerOp(() async {
        try {
          await _scanner.stop();
        } catch (_) {}
      }));
    }
  }

  void _setMessage(_ScanState st, String msg, {bool invalid = false}) {
    if (!mounted) return;
    setState(() {
      _state = st;
      _message = msg;
      _invalid = invalid;
    });
  }

  Future<void> _startCamera() => _enqueueScannerOp(() async {
    if (!mounted) return;
    setState(() {
      _cameraOn = true;
      _flash = false;
    });
    try {
      await _scanner.start();
    } on MobileScannerException catch (e) {
      if (!mounted) return;
      setState(() => _cameraOn = false);
      _setMessage(
        _ScanState.warn,
        e.errorCode == MobileScannerErrorCode.permissionDenied
            ? 'محتاجين إذن الكاميرا من الإعدادات، أو اكتب الرقم'
            : 'الكاميرا مش متاحة، اكتب الرقم يدوي',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _cameraOn = false);
      _setMessage(_ScanState.warn, 'الكاميرا مش متاحة، اكتب الرقم يدوي');
    }
  });

  Future<void> _toggleTorch() async {
    if (!_cameraOn) return;
    try {
      await _scanner.toggleTorch();
      if (mounted) setState(() => _flash = !_flash);
    } catch (_) {}
  }

  void _onDetect(BarcodeCapture capture) {
    if (_busy) return;
    for (final b in capture.barcodes) {
      final v = b.rawValue;
      if (v != null && isValidGtin(v)) {
        _ctrl.text = v;
        _search(v);
        return;
      }
    }
  }

  Future<void> _search([String? code]) async {
    if (_busy) return;
    final value = (code ?? _ctrl.text).trim();
    if (!isValidGtin(value)) {
      HapticFeedback.mediumImpact();
      _setMessage(_ScanState.warn, 'الرقم غير صحيح، راجع الباركود', invalid: true);
      return;
    }
    _busy = true;
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();
    _setMessage(_ScanState.searching, 'بندوّر على المنتج…');
    try {
      final product = await _service.fetch(value, allergies: UserProfile.allergies);
      if (!mounted) return;
      if (product == null) {
        _setMessage(_ScanState.warn, 'المنتج ده مش موجود في قاعدة البيانات');
        await Future<void>.delayed(const Duration(seconds: 2));
        _setMessage(_ScanState.idle, 'وجّه الكاميرا ناحية الباركود');
        return;
      }
      _setMessage(_ScanState.ok, 'تم التعرف على المنتج');
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      await _openProduct(product);
    } on ApiException catch (e) {
      _setMessage(_ScanState.warn, e.message);
      await Future<void>.delayed(const Duration(seconds: 2));
    } catch (_) {
      _setMessage(_ScanState.warn, 'حصل خطأ، جرّب تاني');
      await Future<void>.delayed(const Duration(seconds: 2));
    } finally {
      _busy = false;
    }
  }

  Future<void> _openProduct(Product p) async {
    _navigating = true;
    final wasCameraOn = _cameraOn;
    if (wasCameraOn) {
      await _enqueueScannerOp(() async {
        try {
          await _scanner.stop();
        } catch (_) {}
      });
    }
    if (!mounted) return;
    await Navigator.pushNamed(context, '/product', arguments: p);
    _navigating = false;
    if (!mounted) return;
    _setMessage(_ScanState.idle, 'وجّه الكاميرا ناحية الباركود');
    if (wasCameraOn) {
      await _enqueueScannerOp(() async {
        if (!mounted) return;
        try {
          await _scanner.start();
        } catch (_) {}
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: AppBackground(
        child: Stack(children: [
          if (_cameraOn) ...[
            Positioned.fill(child: MobileScanner(controller: _scanner, onDetect: _onDetect)),
            Positioned.fill(child: ColoredBox(color: Colors.black.withValues(alpha: .35))),
          ] else
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -.45),
                    radius: .9,
                    colors: [const Color(0xFF22D3EE).withValues(alpha: .16), Colors.transparent],
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Column(children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                      child: Row(children: [
                        _RoundBtn(Icons.close_rounded, onTap: () => Navigator.maybePop(context)),
                        Expanded(child: Center(child: Text('امسح الباركود', style: AppText.body(17, weight: FontWeight.w700)))),
                        _RoundBtn(Icons.bolt_rounded, active: _flash, onTap: _toggleTorch),
                      ]),
                    ),
                    const SizedBox(height: 40),
                    _buildFrame(),
                    const SizedBox(height: 18),
                    GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _frameColor,
                            boxShadow: [BoxShadow(color: _frameColor, blurRadius: 10)],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_message, style: AppText.body(13, weight: FontWeight.w700)),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Wrap(spacing: 6, children: [
                        for (final f in const ['EAN-13', 'EAN-8', 'UPC', 'Code 128'])
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .1),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(f, style: AppText.body(11, color: AppColors.textSoft)),
                          ),
                      ]),
                    ),
                  ]),
                ),
              ),
              _buildSheet(),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildFrame() {
    const w = 310.0, h = 196.0;
    return SizedBox(
      width: w,
      height: h,
      child: Stack(children: [
        if (!_cameraOn)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 36),
              child: Opacity(
                opacity: .2,
                child: Row(children: [
                  for (final bw in const [4, 3, 6, 3, 2, 2, 5, 2, 2, 4, 2, 2, 2, 3, 2, 2, 6, 6, 2, 3, 2, 2, 6, 2, 5, 2, 2, 3, 3, 3, 2, 2, 2, 2]) ...[
                    Container(width: bw.toDouble(), color: Colors.white),
                    const SizedBox(width: 3),
                  ],
                ]),
              ),
            ),
          ),
        Positioned.fill(child: CustomPaint(painter: _BracketPainter(_frameColor))),
        if (_state == _ScanState.idle)
          AnimatedBuilder(
            animation: _laser,
            builder: (_, _) => Positioned(
              left: 12,
              right: 12,
              top: 8 + (h - 24) * _laser.value,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.transparent, AppColors.cyan, Colors.white, AppColors.cyan, Colors.transparent],
                  ),
                  boxShadow: [BoxShadow(color: const Color(0xFF22D3EE).withValues(alpha: .75), blurRadius: 16, spreadRadius: 3)],
                ),
              ),
            ),
          ),
        if (_state == _ScanState.ok)
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.greenAccent.shade400.withValues(alpha: .2),
                  border: Border.all(color: Colors.greenAccent.shade400, width: 3),
                  boxShadow: [BoxShadow(color: Colors.greenAccent.shade400.withValues(alpha: .7), blurRadius: 40)],
                ),
                child: const Icon(Icons.check_rounded, color: Colors.greenAccent, size: 40),
              ),
            ),
          ),
        if (!_cameraOn && _state != _ScanState.ok)
          Center(
            child: GestureDetector(
              onTap: _startCamera,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: const LinearGradient(colors: [AppColors.cyan, AppColors.orange]),
                  boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: .5), blurRadius: 24, offset: const Offset(0, 8))],
                ),
                child: Text('شغّل الكاميرا', style: AppText.body(14, weight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildSheet() {
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 14 + MediaQuery.of(context).viewInsets.bottom),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(9)))),
          const SizedBox(height: 10),
          Text('أو اكتب الرقم اللي تحت الباركود', style: AppText.body(12.5, color: AppColors.textSoft)),
          const SizedBox(height: 8),
          Row(children: [
            GestureDetector(
              onTap: () => _search(),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(colors: [AppColors.cyan, AppColors.orange]),
                ),
                child: Text('دوّر', style: AppText.body(15, weight: FontWeight.w700, color: Colors.white)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 48,
                child: TextField(
                  controller: _ctrl,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.number,
                  maxLength: 14,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {
                    _invalid = false;
                    if (_state == _ScanState.warn) {
                      _state = _ScanState.idle;
                      _message = 'وجّه الكاميرا ناحية الباركود';
                    }
                  }),
                  onSubmitted: (_) => _search(),
                  style: AppText.body(19, color: Colors.white24).copyWith(letterSpacing: 3),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '0000000000000',
                    hintStyle: AppText.body(19, color: Colors.white24).copyWith(letterSpacing: 2),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: .08),
                    contentPadding: EdgeInsets.zero,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: _invalid ? AppColors.orange : Colors.white.withValues(alpha: .25)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: _invalid ? AppColors.orange : AppColors.cyan, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _SheetAction('جرّب منتج تجريبي', onTap: () => _openProduct(Product.demo)),
            ),
            const SizedBox(width: 8),
            Expanded(child: _SheetAction('صوّر الجدول الغذائي', onTap: () => Navigator.pushReplacementNamed(context, '/analyze'))),
          ]),
        ]),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction(this.label, {required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .2)),
      ),
      child: Text(label, style: AppText.body(12.5)),
    ),
  );
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn(this.icon, {required this.onTap, this.active = false});
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? const Color(0xFFFDE68A) : Colors.white.withValues(alpha: .12),
        border: Border.all(color: Colors.white.withValues(alpha: .28)),
      ),
      child: Icon(icon, size: 20, color: active ? Colors.black87 : Colors.white),
    ),
  );
}

class _BracketPainter extends CustomPainter {
  _BracketPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    const len = 46.0, r = 26.0;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    Path corner(double x, double y, double dx, double dy) => Path()
      ..moveTo(x, y + dy * len)
      ..lineTo(x, y + dy * r)
      ..quadraticBezierTo(x, y, x + dx * r, y)
      ..lineTo(x + dx * len, y);
    canvas.drawPath(corner(0, 0, 1, 1), p);
    canvas.drawPath(corner(s.width, 0, -1, 1), p);
    canvas.drawPath(corner(0, s.height, 1, -1), p);
    canvas.drawPath(corner(s.width, s.height, -1, -1), p);
  }

  @override
  bool shouldRepaint(covariant _BracketPainter old) => old.color != color;
}