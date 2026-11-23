import 'arabic_digits.dart';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// بداية الأسبوع = السبت.
DateTime weekStart(DateTime d) => DateTime(d.year, d.month, d.day - ((d.weekday + 1) % 7));

const _months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
const _weekdays = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];

String arDayName(DateTime d) => _weekdays[d.weekday - 1];

String arDate(DateTime d) => '${arDayName(d)} ${ar(d.day)} ${_months[d.month - 1]}';

String arTime(DateTime t) {
  final h = t.hour, m = t.minute;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '${ar(h12)}:${ar(m.toString().padLeft(2, '0'))} ${h >= 12 ? 'م' : 'ص'}';
}
