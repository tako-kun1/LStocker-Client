class AppConfig {
  static const bool enableProductKeyAuth = bool.fromEnvironment(
    'ENABLE_PRODUCT_KEY_AUTH',
    defaultValue: true,
  );

  static const String appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  static const String apiBaseUrlDev = String.fromEnvironment(
    'API_BASE_URL_DEV',
    defaultValue: 'http://10.0.2.2:8080',
  );

  static const String apiBaseUrlStg = String.fromEnvironment(
    'API_BASE_URL_STG',
    defaultValue: 'https://stg.example.com',
  );

  static const String apiBaseUrlProd = String.fromEnvironment(
    'API_BASE_URL_PROD',
    defaultValue: 'https://api.example.com',
  );

  static const String licenseAuthServerBaseUrl = String.fromEnvironment(
    'LICENSE_AUTH_SERVER_BASE_URL',
    defaultValue: 'https://auth.nazono.cloud:8443',
  );

  static String get defaultBaseUrl {
    switch (appEnv) {
      case 'prod':
        return apiBaseUrlProd;
      case 'stg':
        return apiBaseUrlStg;
      case 'dev':
      default:
        return apiBaseUrlDev;
    }
  }

  static const String githubRepoOwner = 'tako-kun1';
  static const String githubRepoName = 'LStocker-Client';
  static const String githubLatestReleaseApi =
      'https://api.github.com/repos/$githubRepoOwner/$githubRepoName/releases/latest';
    static const String githubReleasesPageUrl =
      'https://github.com/tako-kun1/LStocker-Client/releases';
}
