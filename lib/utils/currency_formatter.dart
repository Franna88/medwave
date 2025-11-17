/// Utility class for currency formatting and conversion
class CurrencyFormatter {
  // Static USD to ZAR exchange rate
  // TODO: Make this dynamic in the future
  static const double usdToZarRate = 1;

  /// Convert USD amount to ZAR
  static double convertToZAR(double usdAmount) {
    return usdAmount * usdToZarRate;
  }

  static String getCurrencySymbol(String countryFilter) {
    switch (countryFilter) {
      case 'sa':
        return 'R';
      case 'usa':
      case 'all':
      default:
        return '\$';
    }
  }

  /// Format currency amount with appropriate symbol and conversion
  ///
  /// [usdAmount] - The amount in USD (stored value)
  /// [countryFilter] - The country filter: 'sa', 'usa', or 'all'
  /// [decimals] - Number of decimal places (default: 2)
  ///
  /// Returns formatted string like "R 1,850.00" or "$ 1,850.00"
  static String formatCurrency(
    double usdAmount,
    String countryFilter, {
    int decimals = 2,
  }) {
    final symbol = getCurrencySymbol(countryFilter);
    final amount = countryFilter == 'sa' ? convertToZAR(usdAmount) : usdAmount;

    // Format with thousand separators and decimal places
    final formatted = _formatNumber(amount, decimals);
    return '$symbol $formatted';
  }

  /// Format number with thousand separators and decimal places
  static String _formatNumber(double value, int decimals) {
    // Split into integer and decimal parts
    final parts = value.toStringAsFixed(decimals).split('.');
    final integerPart = parts[0];
    final decimalPart = parts.length > 1 ? parts[1] : '';

    // Add thousand separators
    String formattedInteger = '';
    for (int i = 0; i < integerPart.length; i++) {
      if (i > 0 && (integerPart.length - i) % 3 == 0) {
        formattedInteger += ',';
      }
      formattedInteger += integerPart[i];
    }

    // Handle negative numbers
    if (formattedInteger.startsWith('-,')) {
      formattedInteger = formattedInteger.replaceFirst('-,', '-');
    }

    return decimals > 0 ? '$formattedInteger.$decimalPart' : formattedInteger;
  }
}
