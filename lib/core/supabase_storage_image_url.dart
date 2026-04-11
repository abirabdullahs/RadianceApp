/// Builds a Supabase Storage **image transformation** URL from a public object URL.
/// Requires Storage image transformations to be enabled for the bucket (Supabase Pro).
/// Falls back to the original URL if the path is not a public object URL.
String supabaseStorageRenderImageUrl(
  String publicObjectUrl, {
  int? width,
  int? height,
  int quality = 75,
}) {
  if (publicObjectUrl.isEmpty) return publicObjectUrl;
  final u = Uri.parse(publicObjectUrl);
  const seg = '/storage/v1/object/public/';
  final path = u.path;
  final idx = path.indexOf(seg);
  if (idx < 0) return publicObjectUrl;
  final newPath = path.replaceFirst(seg, '/storage/v1/render/image/public/');
  final q = <String, String>{...u.queryParameters};
  if (width != null) q['width'] = '$width';
  if (height != null) q['height'] = '$height';
  q['quality'] = '$quality';
  return u.replace(path: newPath, queryParameters: q).toString();
}
