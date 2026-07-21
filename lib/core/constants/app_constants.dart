class AppConstants {
  const AppConstants._();
  static const String platform = 'android';
  static const String appChannel = 'google';
  static const String appVersion = '1.9.29';
  static const String appVersionNumber = '35';

  /// 域名/图片 CDN 兜底值——startup API 返回后会被动态覆盖。
  static const String fallbackBaseUrl = 'https://jdforrepam.com';
  static const String fallbackImageCdn = 'https://tp.spfcas.com/rhe951l4q/';

  static const int domainFailureThreshold = 3;
}
