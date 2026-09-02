import 'dart:typed_data';

/// The KFGQPC V4 page fonts are COLR/CPAL colour fonts: every glyph carries a
/// baked-in palette (black text, coloured ayah markers), so `TextStyle.color`
/// is ignored and the text stays black — unreadable on a dark background.
///
/// Removing the COLR and CPAL tables makes the renderer fall back to each
/// glyph's plain `glyf` outline, which *does* take the requested colour. This
/// rewrites the sfnt table directory in place of shipping a second font pack.
ByteData stripColourTables(ByteData font) {
  final src = font.buffer.asUint8List(font.offsetInBytes, font.lengthInBytes);
  final data = ByteData.sublistView(src);
  final numTables = data.getUint16(4);

  final kept = <({String tag, int checksum, int offset, int length})>[];
  for (var i = 0; i < numTables; i++) {
    final rec = 12 + 16 * i;
    final tag = String.fromCharCodes(src.sublist(rec, rec + 4));
    if (tag == 'COLR' || tag == 'CPAL') continue;
    kept.add((
      tag: tag,
      checksum: data.getUint32(rec + 4),
      offset: data.getUint32(rec + 8),
      length: data.getUint32(rec + 12),
    ));
  }
  if (kept.length == numTables) return font; // not a colour font
  kept.sort((a, b) => a.tag.compareTo(b.tag));

  final n = kept.length;
  var pow2 = 1;
  while (pow2 * 2 <= n) {
    pow2 *= 2;
  }
  final searchRange = pow2 * 16;
  final entrySelector = pow2.bitLength - 1;

  // Directory then 4-byte-aligned table data.
  var total = 12 + 16 * n;
  for (final t in kept) {
    total = (total + 3) & ~3;
    total += t.length;
  }
  final out = Uint8List(total);
  final view = ByteData.sublistView(out);
  view.setUint32(0, 0x00010000);
  view.setUint16(4, n);
  view.setUint16(6, searchRange);
  view.setUint16(8, entrySelector);
  view.setUint16(10, n * 16 - searchRange);

  var pos = 12 + 16 * n;
  for (var i = 0; i < n; i++) {
    final t = kept[i];
    pos = (pos + 3) & ~3;
    out.setRange(pos, pos + t.length, src, t.offset);
    final rec = 12 + 16 * i;
    out.setRange(rec, rec + 4, t.tag.codeUnits);
    view.setUint32(rec + 4, t.checksum);
    view.setUint32(rec + 8, pos);
    view.setUint32(rec + 12, t.length);
    pos += t.length;
  }
  return ByteData.sublistView(out);
}
