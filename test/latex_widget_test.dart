import 'package:flutter_test/flutter_test.dart';
import 'package:mathswithsd/screens/shared/latex_widget.dart';

void main() {
  group('LaTeXWidget.formatMathSpacing', () {
    test('adds spacing around inline bracket delimiters', () {
      final input = r'Letx\(a+b\)y';
      final output = LaTeXWidget.formatMathSpacing(input);

      expect(output, contains(r'x \('));
      expect(output, contains(r'\) y'));
    });

    test('normalizes incomplete sqrt token', () {
      final input = r'Find \sqrt + 2';
      final output = LaTeXWidget.formatMathSpacing(input);

      expect(output, contains(r'\sqrt{}'));
    });
  });
}
