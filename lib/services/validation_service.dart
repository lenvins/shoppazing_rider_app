class ValidationService {
  // Comprehensive email validation regex
  static final RegExp _emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$');

  /// Validates email format according to RFC 5322 standards
  /// Returns null if valid, error message if invalid
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'Email is required';
    }

    // Trim whitespace
    email = email.trim();

    // Check basic format
    if (!_emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address';
    }

    // Additional checks for common issues
    if (email.startsWith('.') || email.endsWith('.')) {
      return 'Email cannot start or end with a dot';
    }

    if (email.contains('..')) {
      return 'Email cannot contain consecutive dots';
    }

    if (email.contains('@.') || email.contains('.@')) {
      return 'Email cannot contain dots adjacent to @ symbol';
    }

    // Check length constraints
    if (email.length > 254) {
      return 'Email is too long (maximum 254 characters)';
    }

    // Split email into local and domain parts
    final parts = email.split('@');
    if (parts.length != 2) {
      return 'Email must contain exactly one @ symbol';
    }

    final localPart = parts[0];
    final domainPart = parts[1];

    // Validate local part (before @)
    if (localPart.isEmpty) {
      return 'Email local part cannot be empty';
    }

    if (localPart.length > 64) {
      return 'Email local part is too long (maximum 64 characters)';
    }

    // Validate domain part (after @)
    if (domainPart.isEmpty) {
      return 'Email domain cannot be empty';
    }

    if (domainPart.length > 253) {
      return 'Email domain is too long (maximum 253 characters)';
    }

    // Check if domain has at least one dot (for top-level domain)
    if (!domainPart.contains('.')) {
      return 'Email domain must contain a top-level domain';
    }

    // Check if domain parts are valid
    final domainParts = domainPart.split('.');
    for (final part in domainParts) {
      if (part.isEmpty) {
        return 'Domain parts cannot be empty';
      }
      if (part.startsWith('-') || part.endsWith('-')) {
        return 'Domain parts cannot start or end with a hyphen';
      }
    }

    return null; // Email is valid
  }

  /// Validates password strength
  /// Returns null if valid, error message if invalid
  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }

    if (password.length < 8) {
      return 'Password must be at least 8 characters long';
    }

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Password must contain at least one uppercase letter';
    }

    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Password must contain at least one lowercase letter';
    }

    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Password must contain at least one number';
    }

    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      return 'Password must contain at least one special character';
    }

    return null; // Password is valid
  }

  /// Validates name fields (first name, last name)
  /// Returns null if valid, error message if invalid
  static String? validateName(String? name, String fieldName) {
    if (name == null || name.isEmpty) {
      return '$fieldName is required';
    }

    if (name.length < 2) {
      return '$fieldName must be at least 2 characters';
    }

    if (name.length > 50) {
      return '$fieldName is too long (maximum 50 characters)';
    }

    // Use a simpler regex pattern that works - avoiding apostrophe issues
    if (!RegExp(r"^[a-zA-Z\s\-'']+$").hasMatch(name)) {
      return '$fieldName can only contain letters, spaces, hyphens, and apostrophes';
    }

    return null; // Name is valid
  }

  /// Validates phone number format
  /// Returns null if valid, error message if invalid
  static String? validatePhoneNumber(String? phone) {
    if (phone == null || phone.isEmpty) {
      return 'Phone number is required';
    }

    // Remove all non-digit characters
    final digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');

    if (digitsOnly.length < 10 || digitsOnly.length > 15) {
      return 'Phone number must be between 10 and 15 digits';
    }

    return null; // Phone number is valid
  }
}
