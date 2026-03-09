import '../constants/app_constants.dart';

/// Input validation helpers.
class Validators {
  Validators._();

  static String? username(String? value) {
    if (value == null || value.isEmpty) return 'Username is required';
    if (value.length < AppConstants.usernameMinLength) return 'Min ${AppConstants.usernameMinLength} characters';
    if (value.length > AppConstants.usernameMaxLength) return 'Max ${AppConstants.usernameMaxLength} characters';
    if (!AppConstants.usernameRegex.hasMatch(value)) return 'Only letters, numbers, _ and -';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(value)) return 'Invalid email';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Min 8 characters';
    return null;
  }

  static String? entryFee(String? value) {
    if (value == null || value.isEmpty) return 'Entry fee is required';
    final fee = double.tryParse(value);
    if (fee == null) return 'Invalid amount';
    if (fee < AppConstants.minEntryFee) return 'Min €${AppConstants.minEntryFee}';
    if (fee > AppConstants.maxEntryFee) return 'Max €${AppConstants.maxEntryFee}';
    return null;
  }
}
