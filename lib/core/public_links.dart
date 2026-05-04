const String kPublicPaymentPath = '/public/payment';
const String kPublicVoucherPath = '/public/voucher';
const String kPublicClassNotePath = '/public/class-note';

/// Share link for an anonymous class-note viewer (`?t=` share token).
String publicClassNoteUrl(String token) {
  final t = token.trim();
  if (t.isEmpty) return '';
  try {
    final base = Uri.base;
    if (base.hasScheme && base.host.isNotEmpty) {
      return base.replace(
        path: kPublicClassNotePath,
        queryParameters: <String, String>{'t': t},
        fragment: null,
      ).toString();
    }
  } catch (_) {}
  // Fallback when [Uri.base] has no host (e.g. some embeds).
  return Uri(
    path: kPublicClassNotePath,
    queryParameters: <String, String>{'t': t},
  ).toString();
}
