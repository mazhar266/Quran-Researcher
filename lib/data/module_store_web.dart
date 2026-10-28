import 'cdn_catalog.dart';

/// Web stub for the native module store. On web nothing is downloaded to a
/// filesystem: module databases seed OPFS on first use (open_db_web.dart) and
/// the fontpack is fetched into memory (page_fonts_web.dart). The download
/// notifier only drives provider invalidation there, so these are unused.
Future<Map<String, int>> scanInstalledModules() async => const {};

Future<void> downloadModuleToFile(
  CdnModule module, {
  void Function(int received, int total)? onProgress,
  bool Function()? isCancelled,
}) async {
  throw UnsupportedError('No filesystem downloads on web');
}

Future<void> deleteModuleFiles(CdnModule module) async {
  throw UnsupportedError('No filesystem downloads on web');
}
