import 'package:flutter_test/flutter_test.dart';
import '../lib/test/calculator.dart';

void main() {
  group('Calculator functions tests', () {
    test('sum should return correct result', () {
      final result = sum(2, 3);
      expect(result, 5);
    });

    test('subtract should return correct result', () {
      final result = subtract(10, 4);
      expect(result, 6);
    });

    test('divide should throw ArgumentError when dividing by zero', () {
      expect(() => divide(10, 0), throwsArgumentError);
    });
  });
}