class PhoneHelper {
  /// International number for wa.me links: digits only, and a local 9-digit
  /// Cameroon mobile number gets 237.
  static String waDigits(String number) {
    String d = number.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.startsWith('00')) d = d.substring(2);
    if (d.length == 9 && d.startsWith('6')) d = '237$d';
    return d;
  }
}
