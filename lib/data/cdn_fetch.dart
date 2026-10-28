import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'cdn_catalog.dart';

/// Streams one CDN module, feeding every chunk to [onChunk] and reporting
/// progress, then verifies the result against the catalog: the content length
/// while streaming (a mismatch means the CDN file was replaced without a
/// version bump) and the SHA-256 of the assembled bytes at the end.
///
/// [isCancelled] is polled between chunks; returning true aborts with
/// [CdnDownloadCancelledException] and no chunk sink calls after that.
Future<void> streamCdnModule(
  CdnModule module, {
  required void Function(List<int> chunk) onChunk,
  void Function(int received, int total)? onProgress,
  bool Function()? isCancelled,
}) async {
  final client = http.Client();
  try {
    final response = await client.send(http.Request('GET', module.uri));
    if (response.statusCode != 200) {
      throw http.ClientException(
          'HTTP ${response.statusCode} for ${module.fileName}');
    }
    if (response.contentLength != null &&
        response.contentLength != module.sizeBytes) {
      throw http.ClientException(
          '${module.fileName}: expected ${module.sizeBytes} bytes, '
          'CDN offers ${response.contentLength}. The CDN files were updated '
          'without a version bump — update cdn_catalog.dart.');
    }
    final total = module.sizeBytes;

    final digestSink = _DigestSink();
    final hasher = sha256.startChunkedConversion(digestSink);
    var received = 0;
    await for (final chunk in response.stream) {
      if (isCancelled?.call() ?? false) throw const CdnDownloadCancelledException();
      hasher.add(chunk);
      onChunk(chunk);
      received += chunk.length;
      onProgress?.call(received, total);
    }
    hasher.close();
    if (received != module.sizeBytes) {
      throw http.ClientException('${module.fileName}: connection ended at '
          '$received of ${module.sizeBytes} bytes');
    }
    final digest = digestSink.digest.toString();
    if (digest != module.sha256) {
      throw http.ClientException(
          '${module.fileName}: checksum mismatch (got $digest)');
    }
  } finally {
    client.close();
  }
}

class CdnDownloadCancelledException implements Exception {
  const CdnDownloadCancelledException();
  @override
  String toString() => 'Download cancelled';
}

/// In-memory variant used on web (OPFS seeding, fontpack fetch).
Future<Uint8List> fetchCdnModuleBytes(
  CdnModule module, {
  void Function(int received, int total)? onProgress,
}) async {
  final chunks = <List<int>>[];
  await streamCdnModule(
    module,
    onChunk: chunks.add,
    onProgress: onProgress,
  );
  final bytes = Uint8List(module.sizeBytes);
  var offset = 0;
  for (final c in chunks) {
    bytes.setRange(offset, offset + c.length, c);
    offset += c.length;
  }
  return bytes;
}

class _DigestSink implements Sink<Digest> {
  Digest? _digest;
  @override
  void add(Digest data) => _digest = data;
  @override
  void close() {}
  Digest get digest => _digest!;
}

/// Human-friendly size: '17.4 MB', '1.8 MB', '66 MB'.
String formatModuleSize(int bytes) {
  final mb = bytes / (1024 * 1024);
  if (mb >= 100) return '${mb.round()} MB';
  if (mb >= 10) return '${mb.toStringAsFixed(1)} MB';
  return '${mb.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '')} MB';
}
