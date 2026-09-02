void saveBytesToFile({
  required String fileName,
  required List<int> bytes,
  String mimeType = 'application/octet-stream',
}) {
  throw UnsupportedError('File download is only supported in the web app.');
}
