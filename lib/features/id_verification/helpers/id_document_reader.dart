import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Reads an ID card or passport photo on the phone (ML Kit, nothing sent anywhere) and guesses the document
/// number and the expiry date. Only a suggestion: the person checks both before sending.
class IdDocumentReader {
  IdDocumentReader._();

  static Future<({String? number, DateTime? expires})> read(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(InputImage.fromFilePath(imagePath));
      return parse(result.text);
    } catch (_) {
      return (number: null, expires: null);
    } finally {
      recognizer.close();
    }
  }

  /// The number: a run of digits (with up to 2 letters in front, as on passports) that is not a date.
  /// The expiry: the latest date on the document that is still to come.
  static ({String? number, DateTime? expires}) parse(String text) {
    final upper = text.toUpperCase();
    final dates = <DateTime>[];
    for (final m in RegExp(r'\b(\d{2})[./\- ](\d{2})[./\- ](\d{4})\b').allMatches(upper)) {
      final d = int.parse(m.group(1)!), mo = int.parse(m.group(2)!), y = int.parse(m.group(3)!);
      if (d >= 1 && d <= 31 && mo >= 1 && mo <= 12 && y > 1900 && y < 2100) dates.add(DateTime(y, mo, d));
    }
    final now = DateTime.now();
    final future = dates.where((d) => d.isAfter(now)).toList()..sort();
    final DateTime? expires = future.isEmpty ? null : future.last;

    // Dates and the machine-readable lines (with "<") are not the number.
    final cleaned = upper.replaceAll(RegExp(r'\b\d{2}[./\- ]\d{2}[./\- ]\d{4}\b'), ' ').split('\n').where((l) => !l.contains('<')).join('\n');
    String? number;
    for (final m in RegExp(r'\b([A-Z]{0,2}\d{7,12})\b').allMatches(cleaned)) {
      number = m.group(1);
      break;
    }
    return (number: number, expires: expires);
  }
}
