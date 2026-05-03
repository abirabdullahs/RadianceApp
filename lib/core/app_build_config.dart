import 'package:flutter/foundation.dart';

/// Web deployment flag:
/// `--dart-define=WEB_ADMIN_ONLY=true`
const bool kWebAdminOnly = bool.fromEnvironment(
  'WEB_ADMIN_ONLY',
  defaultValue: false,
);

bool get isWebAdminOnlyMode => kIsWeb && kWebAdminOnly;
