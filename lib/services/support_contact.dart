class SupportContact {
  static const String contactName = String.fromEnvironment(
    'SUPPORT_CONTACT_NAME',
    defaultValue: 'LStocker開発｜重平 大智',
  );

  static const String contactEmail = String.fromEnvironment(
    'SUPPORT_CONTACT_EMAIL',
    defaultValue: 't.shige@nazono.cloud',
  );

  static const String contactPhone = String.fromEnvironment(
    'SUPPORT_CONTACT_PHONE',
    defaultValue: '',
  );

  static const String contactUrl = String.fromEnvironment(
    'SUPPORT_CONTACT_URL',
    defaultValue: 'https://github.com/tako-kun1/LStocker-Client/issues',
  );

  static String get effectiveName => contactName.trim();

  static String get effectiveEmail => contactEmail.trim();

  static String get effectivePhone => contactPhone.trim();

  static String get effectiveUrl => contactUrl.trim();

  static bool get hasName => effectiveName.isNotEmpty;

  static bool get hasEmail => effectiveEmail.isNotEmpty;

  static bool get hasPhone => effectivePhone.isNotEmpty;

  static bool get hasUrl => effectiveUrl.isNotEmpty;

  static bool get hasAny => hasName || hasEmail || hasPhone || hasUrl;
}
