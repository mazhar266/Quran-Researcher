import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cdn_catalog.dart';
import 'cdn_fetch.dart' show CdnDownloadCancelledException;
import 'db.dart';
import '../mushaf/mushaf_providers.dart';
import 'module_store_native.dart'
    if (dart.library.js_interop) 'module_store_web.dart';

sealed class ModuleInstallStatus {
  const ModuleInstallStatus();
}

class ModuleNotInstalled extends ModuleInstallStatus {
  const ModuleNotInstalled();
}

class ModuleDownloading extends ModuleInstallStatus {
  /// Bytes received so far; null when the total isn't being tracked (web
  /// seeding has no progress events).
  final int? received;
  final int total;
  const ModuleDownloading({this.received, required this.total});

  double? get fraction =>
      received == null ? null : (received! / total).clamp(0.0, 1.0);
}

class ModuleInstalled extends ModuleInstallStatus {
  const ModuleInstalled();
}

class ModuleFailed extends ModuleInstallStatus {
  final String message;
  const ModuleFailed(this.message);
}

/// Per-module install state plus the download/cancel/delete actions.
///
/// On native platforms a download streams the module to app storage, verifies
/// it, and then invalidates the providers that serve its content — an open
/// tafsir sheet or mushaf page simply refreshes into content. On web the
/// download action only invalidates: the module then seeds itself from the
/// CDN inside the open path (OPFS for databases, memory for the fontpack).
class ModuleDownloadsNotifier extends Notifier<Map<String, ModuleInstallStatus>> {
  final _cancelled = <String>{};
  final _inFlight = <String, Future<void>>{};

  @override
  Map<String, ModuleInstallStatus> build() {
    final initial = {
      for (final id in downloadableModules.keys)
        id: const ModuleNotInstalled(),
    };
    if (!kIsWeb) {
      Future.microtask(_refreshInstalled);
    }
    return initial;
  }

  Future<void> _refreshInstalled() async {
    final sizes = await scanInstalledModules();
    state = {
      for (final entry in downloadableModules.entries)
        entry.key: sizes.containsKey(entry.value.fileName)
            ? const ModuleInstalled()
            : (state[entry.key] is ModuleDownloading
                ? state[entry.key]!
                : const ModuleNotInstalled()),
    };
  }

  void _set(String id, ModuleInstallStatus status) {
    state = {...state, id: status};
  }

  Future<void> download(String id) async {
    final module = downloadableModules[id];
    if (module == null || _inFlight.containsKey(id)) return;
    _cancelled.remove(id);
    _set(id, ModuleDownloading(received: 0, total: module.sizeBytes));

    final future = kIsWeb
        ? _downloadWeb(module)
        : _downloadNative(module, id).onError((e, _) => _set(
            id,
            e is CdnDownloadCancelledException
                ? const ModuleNotInstalled()
                : ModuleFailed('$e')));
    _inFlight[id] = future;
    try {
      await future;
    } finally {
      _inFlight.remove(id);
    }
  }

  Future<void> _downloadNative(CdnModule module, String id) async {
    var lastEmit = DateTime.fromMillisecondsSinceEpoch(0);
    await downloadModuleToFile(
      module,
      onProgress: (received, total) {
        final now = DateTime.now();
        // Throttle UI updates; chunk arrives every few KB.
        if (now.difference(lastEmit) >= const Duration(milliseconds: 80) ||
            received == total) {
          lastEmit = now;
          _set(id, ModuleDownloading(received: received, total: total));
        }
      },
      isCancelled: () => _cancelled.contains(id),
    );
    _set(id, const ModuleInstalled());
    _invalidateConsumers(module);
  }

  /// Web: mark as downloading without a byte count, then trigger the open
  /// path — the seeded fetch happens inside the invalidated provider.
  Future<void> _downloadWeb(CdnModule module) async {
    _set(module.id, ModuleDownloading(received: null, total: module.sizeBytes));
    _invalidateConsumers(module);
  }

  void cancel(String id) {
    if (_inFlight.containsKey(id)) {
      _cancelled.add(id);
    } else if (kIsWeb) {
      _set(id, const ModuleNotInstalled());
    }
  }

  /// Removes a downloaded module and frees its disk space. Any provider still
  /// serving it is invalidated first so the database handle closes before the
  /// file is deleted (Windows locks open files).
  Future<void> delete(String id) async {
    final module = downloadableModules[id];
    if (module == null || kIsWeb) return;
    _invalidateConsumers(module);
    for (var attempt = 0; attempt < 4; attempt++) {
      await Future<void>.delayed(
          Duration(milliseconds: attempt == 0 ? 250 : 500));
      try {
        await deleteModuleFiles(module);
        break;
      } on Exception {
        if (attempt == 3) rethrow;
      }
    }
    await _refreshInstalled();
  }

  void _invalidateConsumers(CdnModule module) {
    if (module.id == fontpackV4.id) {
      resetMushafFonts();
      ref.invalidate(pageFontProvider);
    } else {
      ref.invalidate(moduleDbProvider(module.fileName));
    }
  }
}

final moduleStatusProvider = NotifierProvider<ModuleDownloadsNotifier,
    Map<String, ModuleInstallStatus>>(ModuleDownloadsNotifier.new);
