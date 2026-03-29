import 'dart:developer' as developer;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../constants/app_ads.dart';

class InterstitialAdService {
  InterstitialAd? _ad;
  bool _isLoading = false;
  int _expenseCount = 0;

  InterstitialAdService() {
    _preload();
  }

  void _preload() {
    if (_isLoading || _ad != null) return;
    _isLoading = true;
    developer.log('[AdService] Loading interstitial...');

    InterstitialAd.load(
      adUnitId: AppAds.interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _isLoading = false;
          developer.log('[AdService] Interstitial loaded ✓');
        },
        onAdFailedToLoad: (error) {
          _ad = null;
          _isLoading = false;
          developer.log('[AdService] Interstitial failed: ${error.message}');
        },
      ),
    );
  }

  /// Call after every successful expense add.
  /// Shows interstitial every [AppAds.interstitialEveryN] times.
  void onExpenseAdded() {
    _expenseCount++;
    developer.log('[AdService] expenseCount=$_expenseCount, threshold=${AppAds.interstitialEveryN}');

    if (_expenseCount % AppAds.interstitialEveryN != 0) return;
    _show();
  }

  void _show() {
    if (_ad == null) {
      developer.log('[AdService] Ad not ready, preloading for next time');
      _preload();
      return;
    }

    developer.log('[AdService] Showing interstitial...');
    _ad!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) =>
          developer.log('[AdService] Interstitial shown ✓'),
      onAdDismissedFullScreenContent: (ad) {
        developer.log('[AdService] Interstitial dismissed, preloading next');
        ad.dispose();
        _ad = null;
        _preload();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        developer.log('[AdService] Failed to show: ${error.message}');
        ad.dispose();
        _ad = null;
        _preload();
      },
    );

    _ad!.show();
    _ad = null;
  }

  void dispose() {
    _ad?.dispose();
    _ad = null;
  }
}
