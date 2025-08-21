class SouthAfricanIdValidator {
  /// Validates South African ID number format
  /// Returns true if the ID is valid, false otherwise
  static bool isValidSAId(String idNumber) {
    if (idNumber.length != 13) return false;
    if (!RegExp(r'^\d{13}$').hasMatch(idNumber)) return false;
    
    // Extract date components
    final year = int.tryParse(idNumber.substring(0, 2));
    final month = int.tryParse(idNumber.substring(2, 4));
    final day = int.tryParse(idNumber.substring(4, 6));
    
    if (year == null || month == null || day == null) return false;
    
    // Validate date
    if (month < 1 || month > 12) return false;
    if (day < 1 || day > 31) return false;
    
    // Check Luhn algorithm (checksum)
    return _validateChecksum(idNumber);
  }
  
  /// Extracts date of birth from South African ID
  /// Returns null if ID is invalid
  static DateTime? getDateOfBirth(String idNumber) {
    if (!isValidSAId(idNumber)) return null;
    
    final year = int.parse(idNumber.substring(0, 2));
    final month = int.parse(idNumber.substring(2, 4));
    final day = int.parse(idNumber.substring(4, 6));
    
    // Determine century (if year > 21, assume 1900s, otherwise 2000s)
    final fullYear = year > 21 ? 1900 + year : 2000 + year;
    
    try {
      return DateTime(fullYear, month, day);
    } catch (e) {
      return null;
    }
  }
  
  /// Determines gender from South African ID
  /// Returns 'M' for male, 'F' for female, null if invalid
  static String? getGender(String idNumber) {
    if (!isValidSAId(idNumber)) return null;
    
    final genderDigit = int.parse(idNumber.substring(6, 10));
    return genderDigit < 5000 ? 'F' : 'M';
  }
  
  /// Validates checksum using Luhn algorithm
  static bool _validateChecksum(String idNumber) {
    final digits = idNumber.split('').map(int.parse).toList();
    final checkDigit = digits.last;
    
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      if (i % 2 == 0) {
        sum += digits[i];
      } else {
        int doubled = digits[i] * 2;
        sum += doubled > 9 ? doubled - 9 : doubled;
      }
    }
    
    final calculatedCheck = (10 - (sum % 10)) % 10;
    return calculatedCheck == checkDigit;
  }
  
  /// Formats ID number for display (XXX XXX XXXX X)
  static String formatIdNumber(String idNumber) {
    if (idNumber.length != 13) return idNumber;
    return '${idNumber.substring(0, 6)} ${idNumber.substring(6, 10)} ${idNumber.substring(10, 12)} ${idNumber.substring(12)}';
  }
}
