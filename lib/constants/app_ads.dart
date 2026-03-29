class AppAds {
  // Test mode — release ke time false karo aur real IDs uncomment karo
  static const bool _isTest = true;

  // --- Test IDs (Google official test IDs) ---
  static const String _testBanner      = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testNative      = 'ca-app-pub-3940256099942544/2247696110';

  // --- Production IDs (Play Console se milenge, release pe replace karo) ---
  static const String _prodBanner      = 'ca-app-pub-XXXXXXXX/XXXXXXXXXX';
  static const String _prodInterstitial = 'ca-app-pub-XXXXXXXX/XXXXXXXXXX';
  static const String _prodNative      = 'ca-app-pub-XXXXXXXX/XXXXXXXXXX';

  static String get bannerId      => _isTest ? _testBanner      : _prodBanner;
  static String get interstitialId => _isTest ? _testInterstitial : _prodInterstitial;
  static String get nativeId      => _isTest ? _testNative      : _prodNative;

  // Testing ke liye 1 rakho — production mein 3 karo
  static const int interstitialEveryN = 1;
}
