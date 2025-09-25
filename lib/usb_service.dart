import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_usb_printer/flutter_usb_printer.dart';

class UsbService {
  final FlutterUsbPrinter _printer = FlutterUsbPrinter();

  Future<List<Map<String, dynamic>>> getDeviceList() async {
    try {
      final results = await FlutterUsbPrinter.getUSBDeviceList();
      return List<Map<String, dynamic>>.from(results);
    } catch (e) {
      print("Error getting device list: $e");
      return [];
    }
  }

  Future<bool> connect({required int vendorId, required int productId}) async {
    try {
      final ok = await _printer.connect(vendorId, productId);
      return ok ?? false;
    } catch (e) {
      print('USB connect error: $e');
      return false;
    }
  }

  Future<bool> write(List<int> bytes) async {
    try {
      final ok = await _printer.write(Uint8List.fromList(bytes));
      return ok ?? false;
    } catch (e) {
      print('USB write error: $e');
      return false;
    }
  }

  // Note: some versions of flutter_usb_printer don't expose a disconnect API.
  // Keep a placeholder for future compatibility; currently no-op.
  Future<void> disconnect() async {}
}
