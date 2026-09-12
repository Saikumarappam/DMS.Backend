import 'package:flutter/services.dart';

/// Indian PAN format: AAAAA9999A (5 letters, 4 digits, 1 letter).
class PanInput {
  PanInput._();

  static const int maxLength = 10;

  static bool expectsDigit(int length) => length >= 5 && length <= 8;

  static bool expectsLetter(int length) => length < 5 || length == 9;

  static TextInputType keyboardTypeFor(String value) {
    if (expectsDigit(value.length)) {
      return TextInputType.number;
    }
    return TextInputType.text;
  }

  static Object keyboardKeyFor(String value) => keyboardTypeFor(value).index;
}

class PanInputFormatter extends TextInputFormatter {
  const PanInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final buffer = StringBuffer();

    for (var i = 0; i < raw.length && i < PanInput.maxLength; i++) {
      final ch = raw[i];
      if (PanInput.expectsLetter(i)) {
        if (RegExp(r'[A-Z]').hasMatch(ch)) buffer.write(ch);
      } else if (RegExp(r'[0-9]').hasMatch(ch)) {
        buffer.write(ch);
      }
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
