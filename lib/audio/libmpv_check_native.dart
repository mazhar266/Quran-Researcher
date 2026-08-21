import 'dart:ffi' show DynamicLibrary;

/// True when the system libmpv can actually be dlopen'd — the same lookup
/// media_kit will do. Checked before registering the media_kit backend so a
/// missing library disables audio cleanly instead of half-initializing it.
bool libmpvAvailable() {
  for (final name in ['libmpv.so', 'libmpv.so.2', 'libmpv.so.1']) {
    try {
      DynamicLibrary.open(name);
      return true;
    } catch (_) {
      // keep trying the other sonames
    }
  }
  return false;
}
