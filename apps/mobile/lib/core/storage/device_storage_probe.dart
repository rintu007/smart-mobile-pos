import 'package:disk_space_2/disk_space_2.dart';

/// Sprint 54 (docs/13-offline-sync/failure-scenarios.md §3, tier 3) — the narrow slice of
/// `disk_space_2`'s API this file actually needs, letting tests substitute a real fake instead of
/// mocking a platform channel, this codebase's established "fake, not a mock" testing convention
/// (e.g. Sprint 39's `_FakeEscPosReceiptEncoder`, Sprint 47's `SecureKeyValueStore`).
abstract class DeviceStorageProbe {
  /// Free space on the device's own data partition, in megabytes. `null` only if the platform
  /// call itself failed — never treated as "definitely critical," see [isStorageCriticallyLow].
  Future<double?> freeSpaceMb();
}

class DiskSpace2Probe implements DeviceStorageProbe {
  const DiskSpace2Probe();

  @override
  Future<double?> freeSpaceMb() => DiskSpace.getFreeDiskSpace;
}

/// This app writes only small text/JSON rows locally (no images, no video — confirmed no such
/// feature exists anywhere in the schema, failure-scenarios.md §3's own Sprint 53 correction) —
/// 100 MB is a deliberately conservative, round threshold: enough headroom that reaching it is a
/// real signal, not a false alarm from ordinary day-to-day use. A dated, correctable decision, not
/// a measured budget.
const criticallyLowStorageThresholdMb = 100.0;

/// Fails open, on purpose: a platform-call failure returns `false` (not critical) rather than
/// `true`. A false positive here means a persistent, undismissable warning shown to every Cashier
/// on a device where the probe merely glitched — worse, in this codebase's judgment, than the
/// rare case where a genuinely low-storage device goes unwarned for one extra check. `disk_space_2`
/// wraps a well-established platform API (`StatFs`-equivalent) with a low real-world failure rate,
/// and tier 1's bounded local cache (Sprint 53) plus tier 2's "never prune the queue" guarantee
/// already substantially reduce this app's own exposure to storage exhaustion regardless.
Future<bool> isStorageCriticallyLow(DeviceStorageProbe probe) async {
  final freeMb = await probe.freeSpaceMb();
  if (freeMb == null) return false;
  return freeMb < criticallyLowStorageThresholdMb;
}
