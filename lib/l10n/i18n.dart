import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

/// Global, context-free accessor for localized strings.
///
/// During a widget build the active [BuildContext] is registered (see
/// [registerAppContext], invoked from MaterialApp.builder), so [tr] resolves
/// to the user's selected locale. Outside a build, or before the first frame
/// is drawn, it falls back to the Simplified-Chinese template, which always
/// holds the authoritative copy — so non-UI code paths (e.g. strings built in
/// callbacks) never crash and always show correct Chinese.
BuildContext? _registeredContext;

/// Call once per frame from a context that lives inside MaterialApp, so that
/// [S.of] can resolve the active locale. Safe to call repeatedly.
void registerAppContext(BuildContext context) {
  _registeredContext = context;
}

S get tr {
  final ctx = _registeredContext;
  if (ctx != null) {
    final localized = S.of(ctx);
    if (localized != null) return localized;
  }
  return lookupS(const Locale('zh', 'CN'));
}
