/// Catalog of the on-demand content modules served from the Hikmah CDN.
///
/// Only [bundled] modules ship inside the app (core text, reciter timings);
/// everything else (ten tafsir books, the Arramooz dictionary, the mushaf
/// page-font pack) is downloaded on the user's request and verified against
/// [sizeBytes] and [sha256] before it is used.
///
/// When etl/build.py regenerates the databases: re-upload `assets/` to the
/// CDN under a NEW versioned path (keep old paths alive for released apps),
/// then update [_base] and the size/digest entries below.
library;

const String _base =
    'https://hikmah-cdn.s3.ap-south-1.amazonaws.com/apps/quran-researcher/assets/';

class CdnModule {
  /// Stable id used by the download manager and UI, e.g. 'tafsir:bn-tafsir-…',
  /// 'dict', 'fontpack'.
  final String id;

  /// File name inside `assets/` on the CDN — and, for databases, the name the
  /// module is opened under in app storage (`openModuleDb(name)`).
  final String fileName;

  /// Path relative to the CDN base, e.g. 'db/core.db', 'fontpack_v4.zip'.
  final String path;

  final int sizeBytes;
  final String sha256;

  /// True for the modules that ship inside the app binary and are never
  /// downloaded (core.db, the two audio-timing DBs).
  final bool bundled;

  const CdnModule({
    required this.id,
    required this.fileName,
    required this.path,
    required this.sizeBytes,
    required this.sha256,
    this.bundled = false,
  });

  Uri get uri => Uri.parse('$_base$path');
}

/// Throws when a non-bundled module is opened before it has been downloaded.
/// The UI catches this and offers the download flow.
class ModuleNotDownloadedException implements Exception {
  final String fileName;
  const ModuleNotDownloadedException(this.fileName);

  @override
  String toString() => 'ModuleNotDownloaded: $fileName';
}

const coreDb = CdnModule(
  id: 'core',
  fileName: 'core.db',
  path: 'db/core.db',
  sizeBytes: 73334784,
  sha256: '5c347669fc54b73cb704ec477c62111ce4fcf4d06c33592c0f8fb9ec49720629',
  bundled: true,
);

const audioDb953 = CdnModule(
  id: 'audio:953',
  fileName: 'audio_953.db',
  path: 'db/audio_953.db',
  sizeBytes: 2109440,
  sha256: 'c314197ae367e582549ee54dcb97874d6dd91b5a38d573723f19279aff863ce2',
  bundled: true,
);

const audioDb957 = CdnModule(
  id: 'audio:957',
  fileName: 'audio_957.db',
  path: 'db/audio_957.db',
  sizeBytes: 2113536,
  sha256: '383e1eff11ab048dc91265d785b68d69ec772c046f7ee07cfd1ce72fe34ab647',
  bundled: true,
);

const dictAr = CdnModule(
  id: 'dict',
  fileName: 'dict_ar.db',
  path: 'db/dict_ar.db',
  sizeBytes: 12001280,
  sha256: '1089554fd617bfc337b99add75370cfd2d5d75d8c520b69a9423f8d88c178ca4',
);

const fontpackV4 = CdnModule(
  id: 'fontpack',
  fileName: 'fontpack_v4.zip',
  path: 'fontpack_v4.zip',
  sizeBytes: 68739219,
  sha256: '25d6237454928edc10928ff216b953fb99401f904f5dc246a6143012e23e0ced',
);

const tafsirModules = [
  CdnModule(
    id: 'tafsir:en-tafisr-ibn-kathir',
    fileName: 'tafsir_en-tafisr-ibn-kathir.db',
    path: 'db/tafsir_en-tafisr-ibn-kathir.db',
    sizeBytes: 17866752,
    sha256: 'c4f3f52084ce019e21b137680614c632ac2adca5449c653ee8d58b90ba427c29',
  ),
  CdnModule(
    id: 'tafsir:en-tafsir-maarif-ul-quran',
    fileName: 'tafsir_en-tafsir-maarif-ul-quran.db',
    path: 'db/tafsir_en-tafsir-maarif-ul-quran.db',
    sizeBytes: 16609280,
    sha256: '328002fcaa431a13f8765c989e045ba89b54544b564b2e6a385118ac0d1d3a29',
  ),
  CdnModule(
    id: 'tafsir:tafsir-al-jalalayn',
    fileName: 'tafsir_tafsir-al-jalalayn.db',
    path: 'db/tafsir_tafsir-al-jalalayn.db',
    sizeBytes: 3317760,
    sha256: '740bd2256658af11b1eac264d02e2700975ef323dbb43f3265cf1200768cad9e',
  ),
  CdnModule(
    id: 'tafsir:tazkirul-quran-en',
    fileName: 'tafsir_tazkirul-quran-en.db',
    path: 'db/tafsir_tazkirul-quran-en.db',
    sizeBytes: 5316608,
    sha256: '58c6b19bb5482936aeead5d2cf77a8b8fde2429dd9e90294855135ec2944f399',
  ),
  CdnModule(
    id: 'tafsir:abridged-explanation-of-the-quran',
    fileName: 'tafsir_abridged-explanation-of-the-quran.db',
    path: 'db/tafsir_abridged-explanation-of-the-quran.db',
    sizeBytes: 2150400,
    sha256: '96eb2fba5acb36ad88908c9bd9166ec654efef1e1c68e54219f861ac88e65f9c',
  ),
  CdnModule(
    id: 'tafsir:bn-tafseer-ibn-e-kaseer',
    fileName: 'tafsir_bn-tafseer-ibn-e-kaseer.db',
    path: 'db/tafsir_bn-tafseer-ibn-e-kaseer.db',
    sizeBytes: 28069888,
    sha256: 'e329d7b703d233731ca88c5a73ccb2fdc4b78de58864b175c0e06a42345ad839',
  ),
  CdnModule(
    id: 'tafsir:bn-tafsir-abu-bakr-zakaria',
    fileName: 'tafsir_bn-tafsir-abu-bakr-zakaria.db',
    path: 'db/tafsir_bn-tafsir-abu-bakr-zakaria.db',
    sizeBytes: 20258816,
    sha256: '5f413ce39477e744ae179e3db5d1ac4f1c98bbd6f222559e6617287bab908a22',
  ),
  CdnModule(
    id: 'tafsir:bn-tafsir-ahsanul-bayaan',
    fileName: 'tafsir_bn-tafsir-ahsanul-bayaan.db',
    path: 'db/tafsir_bn-tafsir-ahsanul-bayaan.db',
    sizeBytes: 17375232,
    sha256: '3f4e554b4db4a6ec0027be52eedfdf30d3634d08240aed125e5e7f91b7b46e07',
  ),
  CdnModule(
    id: 'tafsir:tafisr-fathul-majid-bn',
    fileName: 'tafsir_tafisr-fathul-majid-bn.db',
    path: 'db/tafsir_tafisr-fathul-majid-bn.db',
    sizeBytes: 1830912,
    sha256: 'e4367db4a58869833f26b8038a1a630fcbc69c1567d0ed00e7a5cfbbd7011d51',
  ),
  CdnModule(
    id: 'tafsir:bengali-mokhtasar',
    fileName: 'tafsir_bengali-mokhtasar.db',
    path: 'db/tafsir_bengali-mokhtasar.db',
    sizeBytes: 9220096,
    sha256: '466833f6afa68cc9576fd55ffc598d424b3da07c7edf0b375e7773f1b1069ed9',
  ),
];

/// Every downloadable module (tafsirs, dictionary, fontpack), keyed by id.
final Map<String, CdnModule> downloadableModules = {
  for (final m in [...tafsirModules, dictAr, fontpackV4]) m.id: m,
};

CdnModule tafsirModule(String slug) => downloadableModules['tafsir:$slug']!;
