import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'device_storage_probe.dart';

final deviceStorageProbeProvider = Provider<DeviceStorageProbe>((ref) => const DiskSpace2Probe());

/// `autoDispose`, matching `canViewReportsProvider`'s own shape exactly — a probe with no natural
/// per-screen network call of its own to piggyback a re-check on, re-checked whenever a widget
/// starts watching it again after every previous watcher has gone away.
final isStorageCriticallyLowProvider = FutureProvider.autoDispose<bool>((ref) {
  return isStorageCriticallyLow(ref.watch(deviceStorageProbeProvider));
});
