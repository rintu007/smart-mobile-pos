import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// `/pos/scan` — Sprint 21 (backlog.md item 5), FR-034/NFR-002. A thin camera
/// view only: detects one barcode and pops with its raw value. Product
/// lookup, cart-add, and the not-found message all live in the till screen
/// that pushed this route — same "picker returns a value, the caller decides
/// what it means" shape `showPrinterPickerDialog` already established.
class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  var _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled || capture.barcodes.isEmpty) return;
    final value = capture.barcodes.first.rawValue;
    if (value == null) return;
    _handled = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan barcode')),
      body: MobileScanner(key: const Key('barcode_scanner_view'), onDetect: _onDetect),
    );
  }
}
