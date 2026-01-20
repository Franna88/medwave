import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Reusable PDF styling constants for consistent formatting
class PdfStyles {
  // Colors
  static const PdfColor primaryColor = PdfColor.fromInt(0xFF2196F3);
  static const PdfColor textColor = PdfColor.fromInt(0xFF000000);
  static const PdfColor grayColor = PdfColor.fromInt(0xFF666666);
  static const PdfColor lightGrayColor = PdfColor.fromInt(0xFFEEEEEE);
  static const PdfColor borderColor = PdfColor.fromInt(0xFFDDDDDD);

  // Text Styles
  static pw.TextStyle get h1 => pw.TextStyle(
        fontSize: 24,
        fontWeight: pw.FontWeight.bold,
        color: primaryColor,
      );

  static pw.TextStyle get h2 => pw.TextStyle(
        fontSize: 20,
        fontWeight: pw.FontWeight.bold,
        color: textColor,
      );

  static pw.TextStyle get h3 => pw.TextStyle(
        fontSize: 16,
        fontWeight: pw.FontWeight.bold,
        color: textColor,
      );

  static pw.TextStyle get bodyText => const pw.TextStyle(
        fontSize: 12,
        color: textColor,
      );

  static pw.TextStyle get bodyTextBold => pw.TextStyle(
        fontSize: 12,
        fontWeight: pw.FontWeight.bold,
        color: textColor,
      );

  static pw.TextStyle get smallText => const pw.TextStyle(
        fontSize: 10,
        color: grayColor,
      );

  static pw.TextStyle get labelText => pw.TextStyle(
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
        color: grayColor,
      );

  /// Signature text style with custom font
  static pw.TextStyle signatureText(pw.Font font) => pw.TextStyle(
        font: font,
        fontSize: 20,
        color: textColor,
      );

  // Spacing
  static const double spacingSmall = 8;
  static const double spacingMedium = 16;
  static const double spacingLarge = 24;
  static const double spacingXLarge = 32;

  // Box Decorations
  static pw.BoxDecoration get cardDecoration => pw.BoxDecoration(
        border: pw.Border.all(color: borderColor, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      );

  static pw.BoxDecoration get headerDecoration => pw.BoxDecoration(
        color: primaryColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      );

  static pw.BoxDecoration get certificateDecoration => pw.BoxDecoration(
        border: pw.Border.all(color: primaryColor, width: 2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        color: PdfColor.fromInt(0xFFF5F5F5),
      );

  // Dividers
  static pw.Widget get divider => pw.Container(
        height: 1,
        color: borderColor,
        margin: const pw.EdgeInsets.symmetric(vertical: spacingMedium),
      );

  static pw.Widget get thickDivider => pw.Container(
        height: 2,
        color: textColor,
        margin: const pw.EdgeInsets.symmetric(vertical: spacingMedium),
      );
}

