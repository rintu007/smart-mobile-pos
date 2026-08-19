import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/storage/device_storage_probe.dart';

class _FakeDeviceStorageProbe implements DeviceStorageProbe {
  _FakeDeviceStorageProbe(this._freeMb);

  final double? _freeMb;

  @override
  Future<double?> freeSpaceMb() async => _freeMb;
}

void main() {
  test('reports critically low when free space is below the threshold', () async {
    final result = await isStorageCriticallyLow(_FakeDeviceStorageProbe(50));
    expect(result, isTrue);
  });

  test('does not report critically low when free space is comfortably above the threshold', () async {
    final result = await isStorageCriticallyLow(_FakeDeviceStorageProbe(2000));
    expect(result, isFalse);
  });

  test('a reading exactly at the threshold is not treated as critical', () async {
    final result = await isStorageCriticallyLow(
      _FakeDeviceStorageProbe(criticallyLowStorageThresholdMb),
    );
    expect(result, isFalse);
  });

  test('fails open — a null reading (platform call failed) is not treated as critical', () async {
    final result = await isStorageCriticallyLow(_FakeDeviceStorageProbe(null));
    expect(result, isFalse);
  });
}
