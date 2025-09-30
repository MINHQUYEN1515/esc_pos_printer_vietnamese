import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show ByteData, Uint8List;

import 'package:app/invoice.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'package:image/image.dart' as img;

class PrintService {
  NetworkPrinter? _printer;
  CapabilityProfile? _profile;
  // Selected targets (managed by selection helpers below)
  String? _selectedLanIp;
  int _selectedLanPort = 9100;
  String? _selectedBluetoothId; // platform-specific address/identifier
  int? _selectedUsbVendorId;
  int? _selectedUsbProductId;
  Future<void> Function(List<int>)? _sendBytes; // for Bluetooth/USB raw path

  Future<String?> connect({
    required String ip,
    int port = 9100,
    PaperSize paperSize = PaperSize.mm80,
    String profileName = 'default',
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      if (_printer != null) {
        return null;
      }
      _profile = await CapabilityProfile.load(name: profileName);
      final printer = NetworkPrinter(paperSize, _profile!);
      final result = await printer.connect(ip, port: port, timeout: timeout);
      if (result == PosPrintResult.success) {
        _printer = printer;
        return null;
      }
      return result.msg;
    } catch (e) {
      print(e);
      return e.toString();
    }
  }

  void disconnect() {
    _printer?.disconnect();
    _printer = null;
  }

  bool get isConnected => _printer != null;

  // Expose current selection
  String? get selectedLanIp => _selectedLanIp;
  int get selectedLanPort => _selectedLanPort;
  String? get selectedBluetoothId => _selectedBluetoothId;
  int? get selectedUsbVendorId => _selectedUsbVendorId;
  int? get selectedUsbProductId => _selectedUsbProductId;

  // --- Selection & profile helpers ---
  Future<CapabilityProfile> chooseBluetoothAndLoadProfile({
    required String bluetoothId,
    String profileName = 'default',
  }) async {
    _selectedBluetoothId = bluetoothId;
    _profile = await CapabilityProfile.load(name: profileName);
    return _profile!;
  }

  Future<CapabilityProfile> chooseLanAndLoadProfile({
    required String ip,
    int port = 9100,
    String profileName = 'default',
  }) async {
    _selectedLanIp = ip;
    _selectedLanPort = port;
    _profile = await CapabilityProfile.load(name: profileName);
    return _profile!;
  }

  Future<CapabilityProfile> chooseUsbAndLoadProfile({
    int? vendorId,
    int? productId,
    String profileName = 'default',
  }) async {
    _selectedUsbVendorId = vendorId;
    _selectedUsbProductId = productId;
    _profile = await CapabilityProfile.load(name: profileName);
    return _profile!;
  }

  // --- Connect via USB using provided sender ---
  Future<String?> connectUsb({
    required Future<void> Function(List<int>) sender,
    PaperSize paperSize = PaperSize.mm80,
    String profileName = 'default',
  }) async {
    _profile ??= await CapabilityProfile.load(name: profileName);
    _sendBytes = sender;
    return null;
  }

  // --- Print over raw sender (Bluetooth/USB) ---
  Future<PosPrintResult> printReceiptRaw({
    required String storeName,
    String? storeAddress,
    String? storePhone,
    String? invoiceNo,
    DateTime? createdAt,
    required List<ReceiptItem> items,
    double? subtotal,
    double? tax,
    required double total,
    String? footerText,
    PaperSize paperSize = PaperSize.mm80,
  }) async {
    final sender = _sendBytes;
    if (sender == null) {
      return PosPrintResult.timeout;
    }
    final profile = _profile ?? await CapabilityProfile.load(name: 'default');
    final generator = Generator(paperSize, profile);
    final bytes = <int>[];

    bytes.addAll(generator.text(storeName,
        styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2)));
    if (storeAddress != null && storeAddress.isNotEmpty) {
      bytes.addAll(generator.text(storeAddress,
          styles: const PosStyles(align: PosAlign.center)));
    }
    if (storePhone != null && storePhone.isNotEmpty) {
      bytes.addAll(generator.text('Tel: $storePhone',
          styles: const PosStyles(align: PosAlign.center)));
    }
    bytes.addAll(generator.hr());

    final dateStr = (createdAt ?? DateTime.now()).toString();
    if (invoiceNo != null && invoiceNo.isNotEmpty) {
      bytes.addAll(generator.row([
        PosColumn(text: 'Invoice', width: 4),
        PosColumn(
            text: '#$invoiceNo',
            width: 8,
            styles: const PosStyles(align: PosAlign.right)),
      ]));
    }
    bytes.addAll(generator.row([
      PosColumn(text: 'Date', width: 4),
      PosColumn(
          text: dateStr,
          width: 8,
          styles: const PosStyles(align: PosAlign.right)),
    ]));
    bytes.addAll(generator.hr());

    bytes.addAll(generator.row([
      PosColumn(text: 'Item', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
          text: 'Qty',
          width: 2,
          styles: const PosStyles(align: PosAlign.right, bold: true)),
      PosColumn(
          text: 'Price',
          width: 4,
          styles: const PosStyles(align: PosAlign.right, bold: true)),
    ]));

    for (final item in items) {
      final qtyStr = _formatNumber(item.quantity);
      final priceStr = _formatCurrency(item.totalPrice);
      bytes.addAll(generator.row([
        PosColumn(text: item.name, width: 6),
        PosColumn(
            text: qtyStr,
            width: 2,
            styles: const PosStyles(align: PosAlign.right)),
        PosColumn(
            text: priceStr,
            width: 4,
            styles: const PosStyles(align: PosAlign.right)),
      ]));
      if (item.note != null && item.note!.isNotEmpty) {
        bytes.addAll(generator.text('- ${item.note!}',
            styles: const PosStyles(align: PosAlign.left)));
      }
    }

    bytes.addAll(generator.hr());
    if (subtotal != null) {
      bytes.addAll(generator.row([
        PosColumn(
            text: 'Subtotal',
            width: 8,
            styles: const PosStyles(align: PosAlign.right)),
        PosColumn(
            text: _formatCurrency(subtotal),
            width: 4,
            styles: const PosStyles(align: PosAlign.right)),
      ]));
    }
    if (tax != null) {
      bytes.addAll(generator.row([
        PosColumn(
            text: 'Tax',
            width: 8,
            styles: const PosStyles(align: PosAlign.right)),
        PosColumn(
            text: _formatCurrency(tax),
            width: 4,
            styles: const PosStyles(align: PosAlign.right)),
      ]));
    }
    bytes.addAll(generator.row([
      PosColumn(
          text: 'TOTAL',
          width: 8,
          styles: const PosStyles(
              align: PosAlign.right, bold: true, height: PosTextSize.size2)),
      PosColumn(
          text: _formatCurrency(total),
          width: 4,
          styles: const PosStyles(
              align: PosAlign.right, bold: true, height: PosTextSize.size2)),
    ]));
    bytes.addAll(generator.hr(ch: '=', linesAfter: 1));

    if (footerText != null && footerText.isNotEmpty) {
      bytes.addAll(generator.text(footerText,
          styles: const PosStyles(align: PosAlign.center)));
    }
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    await sender(bytes);
    return PosPrintResult.success;
  }

  Future<PosPrintResult> printReceipt({
    required String storeName,
    String? storeAddress,
    String? storePhone,
    String? invoiceNo,
    DateTime? createdAt,
    required List<ReceiptItem> items,
    double? subtotal,
    double? tax,
    required double total,
    String? footerText,
  }) async {
    final printer = _printer;
    if (printer == null) {
      return PosPrintResult.printInProgress; // indicates not ready/connected
    }

    printer.text(storeName,
        styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2));
    if (storeAddress != null && storeAddress.isNotEmpty) {
      printer.text(storeAddress,
          styles: const PosStyles(align: PosAlign.center));
    }
    if (storePhone != null && storePhone.isNotEmpty) {
      printer.text('Tel: $storePhone',
          styles: const PosStyles(align: PosAlign.center));
    }
    printer.hr();

    final dateStr = (createdAt ?? DateTime.now()).toString();
    if (invoiceNo != null && invoiceNo.isNotEmpty) {
      printer.row([
        PosColumn(text: 'Invoice', width: 4),
        PosColumn(
            text: '#$invoiceNo',
            width: 8,
            styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    printer.row([
      PosColumn(text: 'Date', width: 4),
      PosColumn(
          text: dateStr,
          width: 8,
          styles: const PosStyles(align: PosAlign.right)),
    ]);
    printer.hr();

    printer.row([
      PosColumn(text: 'Item', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
          text: 'Qty',
          width: 2,
          styles: const PosStyles(align: PosAlign.right, bold: true)),
      PosColumn(
          text: 'Price',
          width: 4,
          styles: const PosStyles(align: PosAlign.right, bold: true)),
    ]);

    for (final item in items) {
      final qtyStr = _formatNumber(item.quantity);
      final priceStr = _formatCurrency(item.totalPrice);
      printer.row([
        PosColumn(text: item.name, width: 6),
        PosColumn(
            text: qtyStr,
            width: 2,
            styles: const PosStyles(align: PosAlign.right)),
        PosColumn(
            text: priceStr,
            width: 4,
            styles: const PosStyles(align: PosAlign.right)),
      ]);
      if (item.note != null && item.note!.isNotEmpty) {
        printer.text('- ${item.note!}',
            styles: const PosStyles(align: PosAlign.left, reverse: false));
      }
    }

    printer.hr();
    if (subtotal != null) {
      printer.row([
        PosColumn(
            text: 'Subtotal',
            width: 8,
            styles: const PosStyles(align: PosAlign.right)),
        PosColumn(
            text: _formatCurrency(subtotal),
            width: 4,
            styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    if (tax != null) {
      printer.row([
        PosColumn(
            text: 'Tax',
            width: 8,
            styles: const PosStyles(align: PosAlign.right)),
        PosColumn(
            text: _formatCurrency(tax),
            width: 4,
            styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    printer.row([
      PosColumn(
          text: 'TOTAL',
          width: 8,
          styles: const PosStyles(
              align: PosAlign.right, bold: true, height: PosTextSize.size2)),
      PosColumn(
          text: _formatCurrency(total),
          width: 4,
          styles: const PosStyles(
              align: PosAlign.right, bold: true, height: PosTextSize.size2)),
    ]);
    printer.hr(ch: '=', linesAfter: 1);

    if (footerText != null && footerText.isNotEmpty) {
      printer.text(footerText, styles: const PosStyles(align: PosAlign.center));
    }
    printer.feed(2);
    printer.cut();

    printer.disconnect();
    return PosPrintResult.success;
  }

  String _formatCurrency(num value) {
    return value.toStringAsFixed(0);
  }

  String _formatNumber(num value) {
    return value.toString();
  }

  /// Hàm in ảnh dùng esc_pos_printer
  Future<PosPrintResult> printImageRaster({
    required img.Image decodedImage,
    PosAlign align = PosAlign.left,
    bool highDensityHorizontal = true,
    bool highDensityVertical = true,
    PosImageFn imageFn = PosImageFn.bitImageRaster,
  }) async {
    try {
      if (_printer == null) return PosPrintResult.timeout;
      await Future.delayed(const Duration(milliseconds: 60));

      // Reset và đảm bảo trạng thái máy in sạch
      _printer!.reset();

      // Tính max width theo khổ giấy máy in và đảm bảo bội số của 8
      final int paperMaxWidth =
          (_printer!.paperSize == PaperSize.mm58) ? 384 : 576;
      print('Paper size: ${_printer!.paperSize}, Max width: $paperMaxWidth');

      // // // Tối ưu hóa ảnh để in sắc nét và crop khoảng trống thừa
      // final enhanced = enhanceImageForPrinting(decodedImage);

      // // Resize để vừa khổ giấy
      // final resized = resizeToPaper(enhanced, maxWidth: paperMaxWidth);

      // print(
      //     'Enhanced and resized to: ${resized.width}x${resized.height} (sharp & cropped)');

      // Nếu ảnh quá cao, chia nhỏ theo từng dải để tránh tràn bộ đệm
      // const int maxChunkHeight = 4000; // điều chỉnh nếu cần theo máy in
      // if (resized.height > maxChunkHeight) {
      //   int offset = 0;
      //   while (offset < resized.height) {
      //     final int chunkHeight = (offset + maxChunkHeight <= resized.height)
      //         ? maxChunkHeight
      //         : (resized.height - offset);
      //     final img.Image slice = img.copyCrop(
      //       resized,
      //       0,
      //       offset,
      //       resized.width,
      //       chunkHeight,
      //     );
      //     _printer!.imageRaster(
      //       slice,
      //       align: align,
      //       highDensityHorizontal: highDensityHorizontal,
      //       highDensityVertical: highDensityVertical,
      //       imageFn: imageFn,
      //     );
      //     // Feed một chút giữa các dải để tránh dính liền
      //     _printer!.feed(1);
      //     offset += chunkHeight;
      //   }
      // } else {
      //   _printer!.imageRaster(
      //     resized, // Sử dụng ảnh đã được resize thay vì ảnh gốc
      //     align: align,
      //     highDensityHorizontal: highDensityHorizontal,
      //     highDensityVertical: highDensityVertical,
      //     imageFn: imageFn,
      //   );
      // }
      _printer!.imageRaster(
        decodedImage,
        align: align,
        highDensityHorizontal: highDensityHorizontal,
        highDensityVertical: highDensityVertical,
        imageFn: imageFn,
      );

      // Cho máy xử lý buffer, sau đó feed và cắt giấy
      await Future.delayed(const Duration(milliseconds: 120));
      _printer!.feed(2);
      _printer!.cut(mode: PosCutMode.full);

      return PosPrintResult.success;
    } catch (e) {
      print("Lỗi in ảnh: $e");
      return PosPrintResult.timeout;
    }
  }

  int adjustWidth(int width) {
    return (width ~/ 8) * 8; // floor xuống bội số 8
  }

  /// Crop ảnh để xóa khoảng trống thừa với độ nhạy cao hơn
  img.Image cropWhitespace(img.Image image, {int threshold = 250}) {
    int top = 0, bottom = image.height, left = 0, right = image.width;

    // Tìm top boundary - kiểm tra kỹ hơn
    for (int y = 0; y < image.height; y++) {
      int nonWhitePixels = 0;
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = img.getRed(pixel);
        final g = img.getGreen(pixel);
        final b = img.getBlue(pixel);
        final luminance = (0.299 * r + 0.587 * g + 0.114 * b);
        if (luminance < threshold) {
          nonWhitePixels++;
        }
      }
      // Chỉ coi là có nội dung nếu có ít nhất 10 pixel không phải màu trắng
      if (nonWhitePixels > 10) {
        top = y;
        break;
      }
    }

    // Tìm bottom boundary - kiểm tra kỹ hơn
    for (int y = image.height - 1; y >= top; y--) {
      int nonWhitePixels = 0;
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = img.getRed(pixel);
        final g = img.getGreen(pixel);
        final b = img.getBlue(pixel);
        final luminance = (0.299 * r + 0.587 * g + 0.114 * b);
        if (luminance < threshold) {
          nonWhitePixels++;
        }
      }
      // Chỉ coi là có nội dung nếu có ít nhất 10 pixel không phải màu trắng
      if (nonWhitePixels > 10) {
        bottom = y + 1;
        break;
      }
    }

    // Tìm left boundary
    for (int x = 0; x < image.width; x++) {
      int nonWhitePixels = 0;
      for (int y = top; y < bottom; y++) {
        final pixel = image.getPixel(x, y);
        final r = img.getRed(pixel);
        final g = img.getGreen(pixel);
        final b = img.getBlue(pixel);
        final luminance = (0.299 * r + 0.587 * g + 0.114 * b);
        if (luminance < threshold) {
          nonWhitePixels++;
        }
      }
      if (nonWhitePixels > 5) {
        left = x;
        break;
      }
    }

    // Tìm right boundary
    for (int x = image.width - 1; x >= left; x--) {
      int nonWhitePixels = 0;
      for (int y = top; y < bottom; y++) {
        final pixel = image.getPixel(x, y);
        final r = img.getRed(pixel);
        final g = img.getGreen(pixel);
        final b = img.getBlue(pixel);
        final luminance = (0.299 * r + 0.587 * g + 0.114 * b);
        if (luminance < threshold) {
          nonWhitePixels++;
        }
      }
      if (nonWhitePixels > 5) {
        right = x + 1;
        break;
      }
    }

    // Giảm padding để crop chặt hơn
    const int padding = 2;
    top = (top - padding).clamp(0, image.height);
    bottom = (bottom + padding).clamp(0, image.height);
    left = (left - padding).clamp(0, image.width);
    right = (right + padding).clamp(0, image.width);

    print(
        'Crop boundaries: top=$top, bottom=$bottom, left=$left, right=$right');
    print('Original size: ${image.width}x${image.height}');
    print('Cropped size: ${right - left}x${bottom - top}');

    // Crop ảnh
    return img.copyCrop(image, left, top, right - left, bottom - top);
  }

  /// Crop theo chiều dọc để giảm khoảng trắng trên/dưới
  img.Image cropVerticalWhitespace(img.Image image, {int threshold = 250}) {
    int top = 0, bottom = image.height;

    // Tìm top boundary - kiểm tra từng dòng
    for (int y = 0; y < image.height; y++) {
      int nonWhitePixels = 0;
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = img.getRed(pixel);
        final g = img.getGreen(pixel);
        final b = img.getBlue(pixel);
        final luminance = (0.299 * r + 0.587 * g + 0.114 * b);
        if (luminance < threshold) {
          nonWhitePixels++;
        }
      }
      // Chỉ coi là có nội dung nếu có ít nhất 15 pixel không phải màu trắng
      if (nonWhitePixels > 15) {
        top = y;
        break;
      }
    }

    // Tìm bottom boundary - kiểm tra từng dòng
    for (int y = image.height - 1; y >= top; y--) {
      int nonWhitePixels = 0;
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = img.getRed(pixel);
        final g = img.getGreen(pixel);
        final b = img.getBlue(pixel);
        final luminance = (0.299 * r + 0.587 * g + 0.114 * b);
        if (luminance < threshold) {
          nonWhitePixels++;
        }
      }
      // Chỉ coi là có nội dung nếu có ít nhất 15 pixel không phải màu trắng
      if (nonWhitePixels > 15) {
        bottom = y + 1;
        break;
      }
    }

    // Thêm padding tối thiểu
    const int padding = 1;
    top = (top - padding).clamp(0, image.height);
    bottom = (bottom + padding).clamp(0, image.height);

    print('Vertical crop: top=$top, bottom=$bottom (${bottom - top}px height)');

    // Crop theo chiều dọc
    return img.copyCrop(image, 0, top, image.width, bottom - top);
  }

  /// Hàm threshold: nếu pixel sáng hơn `level` thì thành trắng, ngược lại đen
  img.Image threshold(img.Image src, {int level = 128}) {
    final out = img.Image.from(src); // copy ảnh gốc
    for (int y = 0; y < out.height; y++) {
      for (int x = 0; x < out.width; x++) {
        final pixel = out.getPixel(x, y);
        final luma = img.getLuminance(pixel); // giá trị sáng 0–255
        if (luma > level) {
          out.setPixelRgba(x, y, 255, 255, 255); // trắng
        } else {
          out.setPixelRgba(x, y, 0, 0, 0); // đen
        }
      }
    }
    return out;
  }

  /// Tối ưu hóa ảnh để in sắc nét và rõ ràng
  img.Image enhanceImageForPrinting(img.Image image) {
    // 1. Crop toàn bộ khoảng trắng 4 phía (khỏi cần crop 2 lần)
    img.Image processed = cropWhitespace(image);

    // 2. Chuyển grayscale để giảm màu (in nhiệt chỉ đen trắng)
    processed = img.grayscale(processed);

    // 3. Tăng contrast & brightness để chữ đậm hơn, nền trắng hơn
    processed = img.adjustColor(
      processed,
      contrast: 1.5, // 1.5 thay vì 2.0 để tránh gắt quá
      brightness: 1.1, // vừa đủ sáng
    );

    // 4. Chuyển sang black/white cứng (threshold)
    processed = threshold(processed, level: 160);

    // 5. Làm nét nhẹ (sharpen filter)
    processed = img.convolution(
      processed,
      [0, -1, 0, -1, 5, -1, 0, -1, 0],
    );

    return processed;
  }

  /// Tối ưu hóa ảnh cho nội dung dài - giữ nguyên chiều cao
  img.Image enhanceLongContentImage(img.Image image) {
    // 1. Chỉ crop khoảng trắng trên và dưới, giữ nguyên chiều rộng
    img.Image processed = cropVerticalWhitespace(image);

    // 2. Chuyển grayscale
    processed = img.grayscale(processed);

    // 3. Tăng contrast nhẹ để chữ rõ hơn
    processed = img.adjustColor(
      processed,
      contrast: 1.3, // Nhẹ hơn để tránh mất chi tiết
      brightness: 1.05,
    );

    // 4. Threshold với level thấp hơn để giữ chi tiết
    processed = threshold(processed, level: 140);

    // 5. Làm nét nhẹ
    processed = img.convolution(
      processed,
      [0, -1, 0, -1, 5, -1, 0, -1, 0],
    );

    return processed;
  }

  Future<void> printImageTSPLFromBytes({
    required Uint8List imageData,
    required String printerIp,
    int port = 9100,
    int x = 20,
    int y = 20,
    int thresholdValue = 128,
    int maxWidthPx = 576, // tuỳ model máy in (điều chỉnh nếu cần)
  }) async {
    try {
      // decode ảnh
      final src = img.decodeImage(imageData);
      if (src == null) throw Exception('Không đọc được ảnh');

      // nếu ảnh quá rộng thì resize theo tỉ lệ
      img.Image working = src;
      if (src.width > maxWidthPx) {
        final newH = (src.height * (maxWidthPx / src.width)).round();
        working = img.copyResize(src, width: maxWidthPx, height: newH);
      }

      final width = working.width;
      final height = working.height;

      // bội số của 8
      final paddedWidth = ((width + 7) ~/ 8) * 8;
      final bytesPerRow = paddedWidth ~/ 8;

      // build bitmap bytes: 1 = black, 0 = white (bit order: MSB -> left)
      final List<int> bitmap = List<int>.empty(growable: true);

      for (int row = 0; row < height; row++) {
        for (int byteCol = 0; byteCol < bytesPerRow; byteCol++) {
          int b = 0;
          for (int bit = 0; bit < 8; bit++) {
            final px = byteCol * 8 + bit;
            int luminance = 255; // default = white
            if (px < width) {
              final pixel = working.getPixel(px, row);
              final r = img.getRed(pixel);
              final g = img.getGreen(pixel);
              final bl = img.getBlue(pixel);
              // Công thức luminance (số thực)
              luminance = (0.299 * r + 0.587 * g + 0.114 * bl).round();
            }
            final isBlack = luminance > thresholdValue;
            if (isBlack) {
              b |= (1 << (7 - bit)); // đặt bit tương ứng
            }
          }
          bitmap.add(b);
        }
      }

      // Tạo header TSPL: lưu ý phần data là nhị phân (không phải hex text)
      final header =
          'SIZE 50 mm,30 mm\nGAP 1 mm,0\nCLS\nBITMAP $x,$y,$bytesPerRow,$height,0,';
      final footer = '\nPRINT 1\n';

      // Kết nối socket và gửi: header (ascii) + binary bitmap + footer
      final socket =
          await Socket.connect(printerIp, port, timeout: Duration(seconds: 5));
      socket.add(utf8.encode(header)); // header ASCII
      socket.add(Uint8List.fromList(bitmap)); // dữ liệu nhị phân
      socket.add(utf8.encode(footer)); // lệnh in
      await socket.flush();
      await socket.close();

      print('Gửi ảnh tới máy in thành công');
    } catch (e) {
      print('Lỗi in ảnh TSPL: $e');
      rethrow;
    }
  }

  /// Hàm resize ảnh cho vừa khổ giấy (576px cho 80mm, 384px cho 58mm)
  img.Image resizeToPaper(img.Image src, {int maxWidth = 576}) {
    // Đưa ảnh về đúng khổ giấy để chữ to và rõ
    int targetWidth = adjustWidth(maxWidth);

    print('Original: ${src.width}x${src.height}, Target: ${targetWidth}x?');

    return img.copyResize(
      src,
      width: targetWidth,
      height: src.height,
      // Sử dụng cubic để chữ sắc nét hơn
      interpolation: img.Interpolation.cubic,
    );
  }

  /// Tính toán kích thước tối ưu cho widget dựa trên nội dung
  Map<String, double> calculateOptimalSize(
      Widget widget, BuildContext context) {
    // Sử dụng LayoutBuilder để đo kích thước thực tế của widget
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;

    if (renderBox != null) {
      final size = renderBox.size;
      final pixelRatio = MediaQuery.of(context).devicePixelRatio;

      // Tính toán kích thước tối ưu
      double optimalWidth = size.width * pixelRatio;
      double optimalHeight = size.height * pixelRatio;

      // Đảm bảo không vượt quá giới hạn máy in
      const int maxPrintWidth = 576; // 80mm paper
      if (optimalWidth > maxPrintWidth) {
        final scaleFactor = maxPrintWidth / optimalWidth;
        optimalWidth = maxPrintWidth.toDouble();
        optimalHeight = optimalHeight * scaleFactor;
      }

      return {
        'width': optimalWidth,
        'height': optimalHeight,
        'pixelRatio': 2.5, // Tăng pixel ratio để chất lượng tốt hơn
      };
    }

    // Fallback values
    return {
      'width': 400.0,
      'height': 600.0,
      'pixelRatio': 2.5,
    };
  }

  Future<img.Image?> captureWidget(Widget widget, BuildContext context,
      {double pixelRatio = 2.5, int paperMaxWidth = 576}) async {
    // Create a temporary widget wrapped in RepaintBoundary with fixed width
    final GlobalKey repaintBoundaryKey = GlobalKey();

    // Show the widget in an overlay temporarily with fixed width constraint
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Material(
        color: Colors.white, // Ensure white background
        child: Container(
          width: paperMaxWidth.toDouble(), // Fixed width of 576px
          constraints: BoxConstraints(
            maxWidth: paperMaxWidth.toDouble(),
            minWidth: paperMaxWidth.toDouble(),
            minHeight: 0.0, // Allow minimum height to be 0
            maxHeight: double.infinity, // Allow maximum height to be unlimited
          ),
          child: RepaintBoundary(
            key: repaintBoundaryKey,
            child: widget,
          ),
        ),
      ),
    );

    // Insert the overlay
    Overlay.of(context).insert(overlayEntry);

    try {
      // Wait longer for the widget to render with proper constraints
      // Especially important for long content
      await Future.delayed(const Duration(milliseconds: 500));

      // Get the RenderRepaintBoundary
      final RenderRepaintBoundary boundary = repaintBoundaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;

      // Capture the image with optimized pixel ratio
      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        return null;
      }

      final capturedImage = img.decodeImage(byteData.buffer.asUint8List());

      if (capturedImage != null) {
        print(
            'Captured image size: ${capturedImage.width}x${capturedImage.height}');

        // Tối ưu hóa ảnh: crop khoảng trống và tăng độ sắc nét
        final enhanced = enhanceImageForPrinting(capturedImage);

        print('Enhanced image size: ${enhanced.width}x${enhanced.height}');

        // Ensure width is exactly 576px, height remains dynamic
        if (enhanced.width != paperMaxWidth) {
          final scaleFactor = paperMaxWidth / enhanced.width;
          final newHeight = (enhanced.height * scaleFactor).round();
          return img.copyResize(
            enhanced,
            width: paperMaxWidth,
            height: newHeight,
            interpolation: img.Interpolation.cubic,
          );
        }

        return enhanced;
      }

      return capturedImage;
    } catch (e) {
      print('Error capturing widget: $e');
      return null;
    } finally {
      // Always remove the overlay entry
      overlayEntry.remove();
    }
  }

  Future<void> printImage(BuildContext context) async {
    try {
      // Sử dụng Invoice với forPrint: true để không bị giới hạn chiều cao
      final invoiceWidget = Invoice(
        receiptData: ReceiptData(
          isProvisional: false,
          isReprint: false,
          enableWifi: false,
          wifiInfo: null,
          taxCode: null,
          phone: '0937155085',
          order: OrderData(
            code: 'DH-AOYX-4423',
            branch: BranchData(
              name: 'Zami Solution FNB',
              address: null,
            ),
            table: null,
            waitingCard: null,
            createdAt: DateTime.parse('2025-09-20 08:55:00'),
            creator: UserData(fullName: 'Zami FnB'),
            client: null,
            orderType: 'DINE_IN',
            shipping: null,
            products: [
              ProductData(
                name:
                    'Ten san pham dai th iet dai dai dai dai dai dai dai dai da i dai dai dai dai',
                quantity: 1,
                price: 20000,
                attributes: [],
                note: null,
              ),
              ProductData(
                name:
                    'Ten san pham dai th iet dai dai dai dai dai dai dai dai da i dai dai dai dai',
                quantity: 1,
                price: 20000,
                attributes: [],
                note: null,
              ),
              ProductData(
                name:
                    'Ten san pham dai th iet dai dai dai dai dai dai dai dai da i dai dai dai dai',
                quantity: 1,
                price: 20000,
                attributes: [],
                note: null,
              ),
              ProductData(
                name:
                    'Ten san pham dai th iet dai dai dai dai dai dai dai dai da i dai dai dai dai',
                quantity: 1,
                price: 20000,
                attributes: [],
                note: null,
              ),
            ],
            totalMoney: 20000,
            totalDiscount: 0,
            totalShipping: null,
            tax: null,
            totalMoneyPayment: 20000,
            paymentMethod: 'CASH',
            paymentStatus: 'PAID',
            note: null,
            qrBank: 'DH-AOYX-4423',
          ),
        ),
        forPrint: true, // Quan trọng: sử dụng forPrint: true
      );

      // Sử dụng phương thức capture mới cho nội dung dài
      await printLongContentWidget(invoiceWidget, context);
    } catch (e) {
      print("Lỗi $e");
    }
  }

  /// Hàm in ảnh với preview dialog
  Future<void> printImageWithPreview(BuildContext context) async {
    try {
      // Tính toán kích thước tối ưu trước khi capture
      final optimalSize = calculateOptimalSize(ReceiptExample(), context);

      print('Optimal size: ${optimalSize['width']}x${optimalSize['height']}');

      // Capture với kích thước tối ưu
      final image = await captureWidget(
        ReceiptExample(),
        context,
        pixelRatio: optimalSize['pixelRatio']!,
        paperMaxWidth: 576,
      );

      if (image == null) {
        print('Không thể capture widget');
        return;
      }

      // // encode -> List<int>
      // final List<int> pngBytes = img.encodePng(image);

      // // convert sang Uint8List
      // final Uint8List uint8list = Uint8List.fromList(pngBytes);

      // // showDialog(
      //   context: context,
      //   builder: (_) => Dialog(
      //     insetPadding: EdgeInsets.zero,
      //     child: Image.memory(uint8list), // OK
      //   ),
      // );

      // In thực tế với kích thước tối ưu
      print('In ảnh với kích thước: ${image.width}x${image.height}');
      await printImageRaster(decodedImage: image);
    } catch (e) {
      print("Lỗi $e");
    }
  }

  /// Hàm capture widget với khả năng xử lý nội dung dài
  Future<img.Image?> captureLongContentWidget(
      Widget widget, BuildContext context,
      {double pixelRatio = 2.5, int paperMaxWidth = 576}) async {
    try {
      // Tạo một widget wrapper để đảm bảo toàn bộ nội dung được render
      final GlobalKey repaintBoundaryKey = GlobalKey();

      // Tạo một widget container với chiều cao không giới hạn
      final wrappedWidget = Container(
        width: paperMaxWidth.toDouble(),
        constraints: BoxConstraints(
          maxWidth: paperMaxWidth.toDouble(),
          minWidth: paperMaxWidth.toDouble(),
          minHeight: 0.0,
          maxHeight: double
              .infinity, // Không giới hạn chiều cao để capture toàn bộ nội dung
        ),
        child: RepaintBoundary(
          key: repaintBoundaryKey,
          child: Material(
            color: Colors.white,
            child: widget,
          ),
        ),
      );

      // Sử dụng một context mới để render widget
      late OverlayEntry overlayEntry;

      overlayEntry = OverlayEntry(
        builder: (context) => Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            child: Center(
              child: wrappedWidget,
            ),
          ),
        ),
      );

      // Insert overlay
      Overlay.of(context).insert(overlayEntry);

      try {
        // Chờ widget render hoàn toàn
        await Future.delayed(const Duration(milliseconds: 800));

        // Get the RenderRepaintBoundary
        final RenderRepaintBoundary? boundary =
            repaintBoundaryKey.currentContext?.findRenderObject()
                as RenderRepaintBoundary?;

        if (boundary == null) {
          print('Không thể tìm thấy RenderRepaintBoundary');
          return null;
        }

        // Capture với pixel ratio cao để đảm bảo chất lượng
        final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
        final ByteData? byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);

        if (byteData == null) {
          print('Không thể convert image thành byte data');
          return null;
        }

        final capturedImage = img.decodeImage(byteData.buffer.asUint8List());

        if (capturedImage != null) {
          print(
              'Captured long content image size: ${capturedImage.width}x${capturedImage.height}');

          // Tối ưu hóa ảnh cho nội dung dài
          final enhanced = enhanceLongContentImage(capturedImage);
          print(
              'Enhanced long content image size: ${enhanced.width}x${enhanced.height}');

          // Đảm bảo width đúng kích thước giấy
          if (enhanced.width != paperMaxWidth) {
            final scaleFactor = paperMaxWidth / enhanced.width;
            final newHeight = (enhanced.height * scaleFactor).round();
            return img.copyResize(
              enhanced,
              width: paperMaxWidth,
              height: newHeight,
              interpolation: img.Interpolation.cubic,
            );
          }

          return enhanced;
        }

        return null;
      } finally {
        // Luôn remove overlay
        overlayEntry.remove();
      }
    } catch (e) {
      print('Lỗi capture long content widget: $e');
      return null;
    }
  }

  /// Hàm in với kích thước tối ưu
  Future<void> printOptimizedWidget(Widget widget, BuildContext context) async {
    try {
      // Tính toán kích thước tối ưu
      final optimalSize = calculateOptimalSize(widget, context);

      print(
          'In widget với kích thước tối ưu: ${optimalSize['width']}x${optimalSize['height']}');

      // Capture với kích thước tối ưu
      final image = await captureWidget(
        widget,
        context,
        pixelRatio: optimalSize['pixelRatio']!,
        paperMaxWidth: 576,
      );

      if (image == null) {
        print('Không thể capture widget');
        return;
      }

      // In trực tiếp với kích thước đã tối ưu
      print('Bắt đầu in với kích thước: ${image.width}x${image.height}');
      await printImageRaster(decodedImage: image);

      print('In thành công với kích thước: ${image.width}x${image.height}');
    } catch (e) {
      print("Lỗi in widget: $e");
    }
  }

  Future<img.Image?> _fromUiImageRaw(ui.Image uiImage) async {
    final byteData =
        await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return null;
    return img.Image.fromBytes(
      uiImage.width,
      uiImage.height,
      byteData.buffer.asUint8List(),
      format: img.Format.rgba,
    );
  }

  /// Hàm capture widget hoàn toàn không giới hạn chiều cao - KHÔNG hiển thị lên màn hình
  Future<img.Image?> captureFullContentWidget(
      Widget widget, BuildContext context,
      {double pixelRatio = 1.5, int paperMaxWidth = 576}) async {
    try {
      final GlobalKey repaintBoundaryKey = GlobalKey();

      final wrappedWidget = RepaintBoundary(
        key: repaintBoundaryKey,
        child: Material(
          color: Colors.white,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: paperMaxWidth.toDouble(),
              minWidth: paperMaxWidth.toDouble(),
              maxHeight: double.infinity,
              minHeight: 0,
            ),
            child: IntrinsicHeight(
              child: widget,
            ),
          ),
        ),
      );

      // Sử dụng Offstage để render widget mà không hiển thị lên màn hình
      late OverlayEntry overlayEntry;
      overlayEntry = OverlayEntry(
        builder: (context) => Material(
          color: Colors.transparent,
          child: Transform.translate(
            offset: const Offset(-10000, -10000),
            child: SizedBox(
              width: paperMaxWidth.toDouble(),
              child: SingleChildScrollView(child: wrappedWidget),
            ),
          ),
        ),
      );

      Overlay.of(context).insert(overlayEntry);

      try {
        await Future.delayed(const Duration(milliseconds: 120));
        await SchedulerBinding.instance.endOfFrame;

        final boundary = repaintBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary == null) return null;

        final uiImage = await boundary.toImage(pixelRatio: pixelRatio);
        final capturedImage = await _fromUiImageRaw(uiImage);
        if (capturedImage == null) return null;

        final cropped = cropVerticalWhitespace(capturedImage);
        final processed = threshold(cropped, level: 150);

        if (processed.width != paperMaxWidth) {
          return img.copyResize(
            processed,
            width: paperMaxWidth,
            interpolation: img.Interpolation.linear,
          );
        }
        return processed;
      } finally {
        overlayEntry.remove();
      }
    } catch (e) {
      print('Lỗi capture full content widget: $e');
      return null;
    }
  }

  /// Hàm in widget với nội dung dài - đảm bảo toàn bộ nội dung được in
  Future<void> printLongContentWidget(
      Widget widget, BuildContext context) async {
    try {
      print('Bắt đầu in widget với nội dung dài...');
      print('Widget type: ${widget.runtimeType}');

      // Sử dụng phương thức capture mới cho nội dung dài
      final image = await captureFullContentWidget(
        widget,
        context,
        pixelRatio: 6.0, // Tăng pixel ratio để chất lượng tốt hơn
        paperMaxWidth: 576,
      );

      if (image == null) {
        print('Không thể capture widget với nội dung dài');
        return;
      }

      print(
          'Capture thành công với kích thước: ${image.width}x${image.height}');
      print(
          'Chiều cao giấy sẽ được điều chỉnh động theo nội dung: ${image.height}px');

      // In trực tiếp
      await printImageRaster(decodedImage: image);

      print('In thành công widget với nội dung dài!');
    } catch (e) {
      print("Lỗi in widget với nội dung dài: $e");
      rethrow;
    }
  }

  /// Hàm capture widget hoàn toàn ẩn - không hiển thị gì lên màn hình
  Future<img.Image?> captureHiddenWidget(Widget widget, BuildContext context,
      {double pixelRatio = 3.0, int paperMaxWidth = 576}) async {
    try {
      final GlobalKey repaintBoundaryKey = GlobalKey();

      // Tạo widget wrapper với kích thước cố định
      final wrappedWidget = RepaintBoundary(
        key: repaintBoundaryKey,
        child: Material(
          color: Colors.white,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: paperMaxWidth.toDouble(),
              minWidth: paperMaxWidth.toDouble(),
              maxHeight: double.infinity,
              minHeight: 0,
            ),
            child: IntrinsicHeight(
              child: widget,
            ),
          ),
        ),
      );

      // Sử dụng một container ẩn hoàn toàn
      late OverlayEntry overlayEntry;
      overlayEntry = OverlayEntry(
        builder: (context) => Material(
          color: Colors.transparent,
          child: Container(
            width: 0,
            height: 0,
            child: OverflowBox(
              maxWidth: paperMaxWidth.toDouble(),
              maxHeight: double.infinity,
              child: wrappedWidget,
            ),
          ),
        ),
      );

      Overlay.of(context).insert(overlayEntry);

      try {
        // Chờ widget render
        await Future.delayed(const Duration(milliseconds: 300));

        final RenderRepaintBoundary? boundary =
            repaintBoundaryKey.currentContext?.findRenderObject()
                as RenderRepaintBoundary?;

        if (boundary == null) {
          print('Không thể tìm thấy RenderRepaintBoundary');
          return null;
        }

        // Capture với pixel ratio cao
        final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
        final ByteData? byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);

        if (byteData == null) {
          print('Không thể convert image thành byte data');
          return null;
        }

        final capturedImage = img.decodeImage(byteData.buffer.asUint8List());

        if (capturedImage != null) {
          print(
              'Captured HIDDEN widget image size: ${capturedImage.width}x${capturedImage.height}');

          // Xử lý ảnh
          final enhanced = cropVerticalWhitespace(capturedImage);
          final grayscale = img.grayscale(enhanced);
          final processed = threshold(grayscale, level: 140);

          print(
              'Processed HIDDEN widget image size: ${processed.width}x${processed.height}');

          // Đảm bảo width đúng kích thước giấy
          if (processed.width != paperMaxWidth) {
            return img.copyResize(
              processed,
              width: paperMaxWidth,
              interpolation: img.Interpolation.cubic,
            );
          }

          return processed;
        }

        return null;
      } finally {
        overlayEntry.remove();
      }
    } catch (e) {
      print('Lỗi capture hidden widget: $e');
      return null;
    }
  }

  /// Hàm in Invoice với đảm bảo không mất nội dung
  Future<void> printInvoice(
      ReceiptData receiptData, BuildContext context) async {
    try {
      print('Bắt đầu in Invoice với đảm bảo không mất nội dung...');

      // Tạo Invoice widget với forPrint: true để tối ưu cho in ấn
      await precacheImage(const AssetImage('assets/images/image.png'), context);
      final invoiceWidget = Invoice(
        receiptData: receiptData,
        forPrint: true,
      );

      // In widget với nội dung dài
      // await printLongContentWidget(invoiceWidget, context);
      // showDialog(
      //   context: context,
      //   builder: (_) => Dialog(
      //     insetPadding: EdgeInsets.zero,
      //     child: invoiceWidget, // OK
      //   ),
      // );

      print('In Invoice thành công!');
    } catch (e) {
      print("Lỗi in Invoice: $e");
    }
  }

  /// Hàm in Invoice ẩn - không hiển thị widget lên màn hình
  Future<void> printInvoiceHidden(
      ReceiptData receiptData, BuildContext context) async {
    try {
      print('Bắt đầu in Invoice ẩn (không hiển thị lên màn hình)...');

      // Tạo Invoice widget với forPrint: true để tối ưu cho in ấn
      final invoiceWidget = Invoice(
        receiptData: receiptData,
        forPrint: true,
      );

      // Capture widget ẩn
      final image = await captureHiddenWidget(
        invoiceWidget,
        context,
        pixelRatio: 3.0,
        paperMaxWidth: 576,
      );

      if (image == null) {
        print('Không thể capture widget ẩn');
        return;
      }

      print(
          'Capture widget ẩn thành công với kích thước: ${image.width}x${image.height}');

      // In trực tiếp
      await printImageRaster(decodedImage: image);

      print('In Invoice ẩn thành công!');
    } catch (e) {
      print("Lỗi in Invoice ẩn: $e");
    }
  }
}

class ReceiptItem {
  final String name;
  final num quantity;
  final num totalPrice;
  final String? note;

  const ReceiptItem({
    required this.name,
    required this.quantity,
    required this.totalPrice,
    this.note,
  });
}
