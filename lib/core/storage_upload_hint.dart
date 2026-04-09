/// Content-Type for [FileOptions] on storage uploads.
String mimeForStorageExtension(String ext) {
  switch (ext.toLowerCase()) {
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'pdf':
      return 'application/pdf';
    case 'doc':
      return 'application/msword';
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    default:
      return 'application/octet-stream';
  }
}

/// User-facing hint when Supabase Storage upload fails (e.g. missing bucket).
String storageUploadHint(Object error) {
  final s = error.toString().toLowerCase();
  if (s.contains('bucket') ||
      s.contains('not found') ||
      s.contains('404') ||
      s.contains('no such') ||
      s.contains('object not found')) {
    return 'স্টোরেজ বাকেট বা পারমিশন ঠিক নেই। অ্যাডমিন Supabase-এ `community` বাকেট ও মাইগ্রেশন চালান।';
  }
  return error.toString();
}
