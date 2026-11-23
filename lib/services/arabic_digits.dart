const _ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

/// يحوّل أي رقم/نص إلى أرقام عربية-هندية (٠١٢٣...).
String ar(Object value) =>
    value.toString().replaceAllMapped(RegExp(r'[0-9]'), (m) => _ar[int.parse(m[0]!)]);

/// ١٬٨٥٠ — فاصل آلاف عربي.
String arThousands(int v) {
  final s = v.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('٬');
    buf.write(s[i]);
  }
  return ar(buf.toString());
}

/// كمية عشرية بصيغة عربية: ١ ← "١"، ١٫٢٥ ← "١٫٢٥".
String arNum(double v) {
  final text = v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  return ar(text).replaceAll('.', '٫');
}
