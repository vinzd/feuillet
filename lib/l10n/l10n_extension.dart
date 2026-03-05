import 'package:flutter/widgets.dart';
import 'package:feuillet/l10n/app_localizations.dart';

export 'package:feuillet/l10n/app_localizations.dart';

extension L10nExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
