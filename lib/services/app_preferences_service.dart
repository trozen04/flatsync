import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_currencies.dart';

class AppPreferencesService extends ChangeNotifier {
  static const String _preferredCurrencyKey = 'preferred_currency_code_v1';
  static const String _biometricEnabledKey = 'biometric_enabled_v1';
  static const String _currencyManuallySelectedKey =
      'currency_manually_selected_v1';

  SharedPreferences? _prefs;
  String _preferredCurrencyCode = AppCurrencies.defaultCode;
  bool _biometricEnabled = false;
  bool _currencyManuallySelected = false;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    _preferredCurrencyCode =
        AppCurrencies.normalizeCode(prefs.getString(_preferredCurrencyKey));
    _biometricEnabled = prefs.getBool(_biometricEnabledKey) ?? false;
    _currencyManuallySelected =
        prefs.getBool(_currencyManuallySelectedKey) ?? false;
  }

  String get preferredCurrencyCode => _preferredCurrencyCode;
  AppCurrency get preferredCurrency => AppCurrencies.byCode(_preferredCurrencyCode);
  bool get biometricEnabled => _biometricEnabled;
  bool get currencyManuallySelected => _currencyManuallySelected;

  Future<void> setPreferredCurrency(
    String code, {
    bool manuallySelected = true,
  }) async {
    final normalized = AppCurrencies.normalizeCode(code);
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;

    if (normalized == _preferredCurrencyCode &&
        manuallySelected == _currencyManuallySelected) {
      return;
    }

    await prefs.setString(_preferredCurrencyKey, normalized);
    await prefs.setBool(_currencyManuallySelectedKey, manuallySelected);
    _preferredCurrencyCode = normalized;
    _currencyManuallySelected = manuallySelected;
    notifyListeners();
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    if (enabled == _biometricEnabled) return;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setBool(_biometricEnabledKey, enabled);
    _biometricEnabled = enabled;
    notifyListeners();
  }

  Future<void> autoSetCurrencyFromCountry(String? countryIsoCode) async {
    if (_currencyManuallySelected) return;

    final mapped = _currencyForCountry(countryIsoCode);
    if (mapped == null) return;

    await setPreferredCurrency(mapped, manuallySelected: false);
  }

  Future<void> resetForLogout({bool preserveBiometric = true}) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;

    final biometricValue = preserveBiometric ? _biometricEnabled : false;

    await prefs.clear();

    if (preserveBiometric && biometricValue) {
      await prefs.setBool(_biometricEnabledKey, true);
    }

    _preferredCurrencyCode = AppCurrencies.defaultCode;
    _biometricEnabled = preserveBiometric ? biometricValue : false;
    _currencyManuallySelected = false;
    notifyListeners();
  }

  String? _currencyForCountry(String? isoCode) {
    final code = isoCode?.trim().toUpperCase();
    if (code == null || code.isEmpty) return null;

    const inrCountries = {'IN', 'BT'};
    const usdCountries = {
      'US',
      'EC',
      'SV',
      'GU',
      'MH',
      'FM',
      'MP',
      'PW',
      'PR',
      'TC',
      'VI',
    };
    const gbpCountries = {'GB'};
    const aedCountries = {'AE'};
    const cadCountries = {'CA'};
    const audCountries = {'AU'};
    const sgdCountries = {'SG'};
    const nzdCountries = {'NZ'};
    const chfCountries = {'CH', 'LI'};
    const cnyCountries = {'CN'};
    const hkdCountries = {'HK'};
    const sarCountries = {'SA'};
    const qarCountries = {'QA'};
    const zarCountries = {'ZA'};
    const sekCountries = {'SE'};
    const nokCountries = {'NO'};
    const dkkCountries = {'DK'};
    const mxnCountries = {'MX'};
    const brlCountries = {'BR'};
    const myrCountries = {'MY'};
    const thbCountries = {'TH'};
    const tryCountries = {'TR'};
    const plnCountries = {'PL'};
    const eurCountries = {
      'AD',
      'AT',
      'BE',
      'CY',
      'DE',
      'EE',
      'ES',
      'FI',
      'FR',
      'GR',
      'HR',
      'IE',
      'IT',
      'LT',
      'LU',
      'LV',
      'MC',
      'ME',
      'MT',
      'NL',
      'PT',
      'SI',
      'SK',
      'SM',
      'VA',
      'XK',
    };

    if (inrCountries.contains(code)) return 'INR';
    if (usdCountries.contains(code)) return 'USD';
    if (eurCountries.contains(code)) return 'EUR';
    if (gbpCountries.contains(code)) return 'GBP';
    if (aedCountries.contains(code)) return 'AED';
    if (cadCountries.contains(code)) return 'CAD';
    if (audCountries.contains(code)) return 'AUD';
    if (sgdCountries.contains(code)) return 'SGD';
    if (nzdCountries.contains(code)) return 'NZD';
    if (chfCountries.contains(code)) return 'CHF';
    if (cnyCountries.contains(code)) return 'CNY';
    if (hkdCountries.contains(code)) return 'HKD';
    if (sarCountries.contains(code)) return 'SAR';
    if (qarCountries.contains(code)) return 'QAR';
    if (zarCountries.contains(code)) return 'ZAR';
    if (sekCountries.contains(code)) return 'SEK';
    if (nokCountries.contains(code)) return 'NOK';
    if (dkkCountries.contains(code)) return 'DKK';
    if (mxnCountries.contains(code)) return 'MXN';
    if (brlCountries.contains(code)) return 'BRL';
    if (myrCountries.contains(code)) return 'MYR';
    if (thbCountries.contains(code)) return 'THB';
    if (tryCountries.contains(code)) return 'TRY';
    if (plnCountries.contains(code)) return 'PLN';

    return null;
  }
}
