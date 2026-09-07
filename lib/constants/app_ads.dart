import 'package:flutter/foundation.dart';

class AppAds {
  // Test mode - automatically enabled in debug mode, disabled for production release
  static const bool _isTest = kDebugMode;

  // --- Test IDs (Google official test IDs) ---
  static const String _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testNativeAndroid = 'ca-app-pub-3940256099942544/2247696110';
  static const String _testNativeIos = 'ca-app-pub-3940256099942544/3986624511';

  // --- Production IDs ---
  static const String _prodBanner = 'ca-app-pub-7247180021367190/4206142735';
  static const String _prodInterstitial = 'ca-app-pub-7247180021367190/4174353145';
  static const String _prodNative = 'ca-app-pub-7247180021367190/6417373106';

  static String get bannerId => _isTest ? _testBanner : _prodBanner;
  static String get interstitialId => _isTest ? _testInterstitial : _prodInterstitial;
  static String get nativeId =>
      _isTest
          ? (defaultTargetPlatform == TargetPlatform.iOS
              ? _testNativeIos
              : _testNativeAndroid)
          : _prodNative;

  // Interstitial frequency: show after every N actions
  static const int interstitialEveryN = 3;
  // Inline native ad slot frequency inside long lists.
  static const int nativeAdEveryN = 6;
}
