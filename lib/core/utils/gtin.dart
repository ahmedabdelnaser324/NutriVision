/// يتحقق من رقم باركود (EAN-8 / UPC-A / EAN-13 / GTIN-14) بخوارزمية GS1 mod-10.
bool isValidGtin(String code) {
  if (!RegExp(r'^\d+$').hasMatch(code)) return false;
  if (![8, 12, 13, 14].contains(code.length)) return false;
  final digits = code.split('').map(int.parse).toList();
  final check = digits.removeLast();
  var sum = 0;
  for (var i = 0; i < digits.length; i++) {
    final fromRight = digits.length - i; // 1 = أقرب رقم لرقم التحقق
    sum += digits[i] * (fromRight.isOdd ? 3 : 1);
  }
  return (10 - sum % 10) % 10 == check;
}
