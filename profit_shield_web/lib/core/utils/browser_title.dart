import 'package:flutter/services.dart';

/// Updates the browser tab title (web) and app switcher label.
void setBrowserTitle(String pageTitle) {
  final label = pageTitle.trim().isEmpty
      ? 'ProfitShield'
      : (pageTitle.contains('ProfitShield') ? pageTitle : '$pageTitle · ProfitShield');

  SystemChrome.setApplicationSwitcherDescription(
    ApplicationSwitcherDescription(
      label: label,
      primaryColor: 0xFF00234E,
    ),
  );
}
