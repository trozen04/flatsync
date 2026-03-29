class AppCurrency {
  final String code;
  final String label;
  final String symbol;
  final String locale;
  final int decimalDigits;

  const AppCurrency({
    required this.code,
    required this.label,
    required this.symbol,
    required this.locale,
    this.decimalDigits = 2,
  });
}

class AppCurrencies {
  static const String defaultCode = 'INR';

  static const AppCurrency inr = AppCurrency(
    code: 'INR',
    label: 'Indian Rupee',
    symbol: 'Rs. ',
    locale: 'en_IN',
  );

  static const AppCurrency usd = AppCurrency(
    code: 'USD',
    label: 'US Dollar',
    symbol: '\$',
    locale: 'en_US',
  );

  static const AppCurrency eur = AppCurrency(
    code: 'EUR',
    label: 'Euro',
    symbol: 'EUR ',
    locale: 'en_IE',
  );

  static const AppCurrency gbp = AppCurrency(
    code: 'GBP',
    label: 'British Pound',
    symbol: 'GBP ',
    locale: 'en_GB',
  );

  static const AppCurrency aed = AppCurrency(
    code: 'AED',
    label: 'UAE Dirham',
    symbol: 'AED ',
    locale: 'en_AE',
  );

  static const AppCurrency cad = AppCurrency(
    code: 'CAD',
    label: 'Canadian Dollar',
    symbol: 'CA\$',
    locale: 'en_CA',
  );

  static const AppCurrency aud = AppCurrency(
    code: 'AUD',
    label: 'Australian Dollar',
    symbol: 'A\$',
    locale: 'en_AU',
  );

  static const AppCurrency sgd = AppCurrency(
    code: 'SGD',
    label: 'Singapore Dollar',
    symbol: 'S\$',
    locale: 'en_SG',
  );

  static const AppCurrency nzd = AppCurrency(
    code: 'NZD',
    label: 'New Zealand Dollar',
    symbol: 'NZ\$',
    locale: 'en_NZ',
  );

  static const AppCurrency chf = AppCurrency(
    code: 'CHF',
    label: 'Swiss Franc',
    symbol: 'CHF ',
    locale: 'de_CH',
  );

  static const AppCurrency cny = AppCurrency(
    code: 'CNY',
    label: 'Chinese Yuan',
    symbol: 'CNY ',
    locale: 'zh_CN',
  );

  static const AppCurrency hkd = AppCurrency(
    code: 'HKD',
    label: 'Hong Kong Dollar',
    symbol: 'HK\$',
    locale: 'zh_HK',
  );

  static const AppCurrency sar = AppCurrency(
    code: 'SAR',
    label: 'Saudi Riyal',
    symbol: 'SAR ',
    locale: 'ar_SA',
  );

  static const AppCurrency qar = AppCurrency(
    code: 'QAR',
    label: 'Qatari Riyal',
    symbol: 'QAR ',
    locale: 'ar_QA',
  );

  static const AppCurrency zar = AppCurrency(
    code: 'ZAR',
    label: 'South African Rand',
    symbol: 'ZAR ',
    locale: 'en_ZA',
  );

  static const AppCurrency sek = AppCurrency(
    code: 'SEK',
    label: 'Swedish Krona',
    symbol: 'SEK ',
    locale: 'sv_SE',
  );

  static const AppCurrency nok = AppCurrency(
    code: 'NOK',
    label: 'Norwegian Krone',
    symbol: 'NOK ',
    locale: 'nb_NO',
  );

  static const AppCurrency dkk = AppCurrency(
    code: 'DKK',
    label: 'Danish Krone',
    symbol: 'DKK ',
    locale: 'da_DK',
  );

  static const AppCurrency mxn = AppCurrency(
    code: 'MXN',
    label: 'Mexican Peso',
    symbol: 'MXN ',
    locale: 'es_MX',
  );

  static const AppCurrency brl = AppCurrency(
    code: 'BRL',
    label: 'Brazilian Real',
    symbol: 'BRL ',
    locale: 'pt_BR',
  );

  static const AppCurrency myr = AppCurrency(
    code: 'MYR',
    label: 'Malaysian Ringgit',
    symbol: 'MYR ',
    locale: 'ms_MY',
  );

  static const AppCurrency thb = AppCurrency(
    code: 'THB',
    label: 'Thai Baht',
    symbol: 'THB ',
    locale: 'th_TH',
  );

  static const AppCurrency tryCurrency = AppCurrency(
    code: 'TRY',
    label: 'Turkish Lira',
    symbol: 'TRY ',
    locale: 'tr_TR',
  );

  static const AppCurrency pln = AppCurrency(
    code: 'PLN',
    label: 'Polish Zloty',
    symbol: 'PLN ',
    locale: 'pl_PL',
  );

  static const List<AppCurrency> supported = [
    inr,
    usd,
    eur,
    gbp,
    aed,
    cad,
    aud,
    sgd,
    nzd,
    chf,
    cny,
    hkd,
    sar,
    qar,
    zar,
    sek,
    nok,
    dkk,
    mxn,
    brl,
    myr,
    thb,
    tryCurrency,
    pln,
  ];

  static AppCurrency byCode(String? code) {
    final normalized = normalizeCode(code);
    for (final currency in supported) {
      if (currency.code == normalized) return currency;
    }
    return inr;
  }

  static String normalizeCode(String? code) {
    final value = code?.trim().toUpperCase();
    if (value == null || value.isEmpty) return defaultCode;
    return supported.any((currency) => currency.code == value)
        ? value
        : defaultCode;
  }
}
