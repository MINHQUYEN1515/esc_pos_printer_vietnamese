import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show Uint8List;

import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
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

      // Reset và đảm bảo trạng thái máy in sạch
      _printer!.reset();

      // Tính max width theo khổ giấy máy in và đảm bảo bội số của 8
      final int paperMaxWidth =
          (_printer!.paperSize == PaperSize.mm58) ? 384 : 576;
      print('Paper size: ${_printer!.paperSize}, Max width: $paperMaxWidth');

      // Resize trước cho đúng khổ in, rồi chuyển grayscale + threshold để chữ rõ
      final resized = resizeToPaper(decodedImage, maxWidth: paperMaxWidth);
      final gray = img.grayscale(resized);
      final enhanced = img.adjustColor(gray, contrast: 1.25, brightness: 1.05);
      var bw = enhanced;

      print('Resized to: ${bw.width}x${bw.height} (enhanced gray)');

      _printer!.imageRaster(
        bw,
        align: align,
        highDensityHorizontal: highDensityHorizontal,
        highDensityVertical: highDensityVertical,
        imageFn: imageFn,
      );

      // Cho máy xử lý buffer, sau đó feed và cắt giấy
      await Future.delayed(const Duration(milliseconds: 120));
      _printer!.feed(5);
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
