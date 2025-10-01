import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_usb_printer/flutter_usb_printer.dart';
import 'package:image/image.dart' as img;
import 'label_widget.dart';

class LabelPrintService {
  static const int _labelWidth = 400; // 50mm @ 203dpi
  static const int _labelHeight = 240; // 30mm @ 203dpi

  /// Trạng thái kết nối máy in
  static bool isConnected = false;
  static Socket? _socket;

  /// In label widget bằng cách convert sang ảnh rồi gửi TSPL command
  static Future<void> printLabel({
    required String title,
    required String content,
    String? additionalInfo,
    required String printerIp,
    required BuildContext context,
    int port = 9100,
    bool saveDebugImage = false, // Thêm option để save ảnh debug
  }) async {
    try {
      print('Bắt đầu in label...');

      // Tạo widget
      final labelWidget = LabelWidget(
        title: title,
        content: content,
        additionalInfo: additionalInfo,
      );

      // Convert widget sang ảnh
      final imageBytes = await _convertWidgetToImage(labelWidget, context);
      if (imageBytes == null) {
        throw Exception('Không thể convert widget sang ảnh');
      }

      // Kết nối và in
      await _connectAndPrint(imageBytes, printerIp, port);

      print('In label thành công!');
    } catch (e) {
      print('Lỗi in label: $e');
      rethrow;
    }
  }

  /// Convert widget sang ảnh bytes với chất lượng cao
  static Future<Uint8List?> _convertWidgetToImage(
    Widget widget,
    BuildContext context,
  ) async {
    try {
      final GlobalKey repaintBoundaryKey = GlobalKey();

      // Tạo widget với kích thước cố định và chất lượng cao
      final sizedWidget = SizedBox(
        width: _labelWidth.toDouble(),
        height: _labelHeight.toDouble(),
        child: RepaintBoundary(
          key: repaintBoundaryKey,
          child: Material(
            color: Colors.white,
            child: MediaQuery(
              // Tăng pixel ratio để có ảnh sắc nét hơn
              data: MediaQuery.of(context).copyWith(
                devicePixelRatio: 3.0, // Tăng từ 2.0 lên 3.0
              ),
              child: widget,
            ),
          ),
        ),
      );

      // Render widget trong overlay ẩn với kích thước lớn hơn
      late OverlayEntry overlayEntry;
      overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          left: -10000, // Đặt ngoài màn hình
          top: -10000,
          child: Transform.scale(
            scale: 1.0, // Giữ nguyên scale
            child: sizedWidget,
          ),
        ),
      );

      Overlay.of(context).insert(overlayEntry);

      try {
        // Chờ render xong với thời gian lâu hơn
        await Future.delayed(const Duration(milliseconds: 300));
        await SchedulerBinding.instance.endOfFrame;
        await SchedulerBinding
            .instance.endOfFrame; // Double frame để đảm bảo render hoàn toàn

        // Capture ảnh với pixel ratio cao
        final RenderRepaintBoundary? boundary =
            repaintBoundaryKey.currentContext?.findRenderObject()
                as RenderRepaintBoundary?;

        if (boundary == null) {
          print('Không tìm thấy RenderRepaintBoundary');
          return null;
        }

        // Sử dụng pixel ratio cao hơn để có ảnh sắc nét
        final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
        final ByteData? byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);

        return byteData?.buffer.asUint8List();
      } finally {
        overlayEntry.remove();
      }
    } catch (e) {
      print('Lỗi convert widget sang ảnh: $e');
      return null;
    }
  }

  /// Kết nối và in ảnh
  static Future<void> _connectAndPrint(
    Uint8List imageBytes,
    String printerIp,
    int port,
  ) async {
    Socket? socket;
    bool shouldCloseSocket = false;

    try {
      // Sử dụng kết nối hiện có hoặc tạo mới
      if (_socket != null && isConnected) {
        socket = _socket;
        print('Sử dụng kết nối hiện có');
      } else {
        socket = await Socket.connect(
          printerIp,
          port,
          timeout: const Duration(seconds: 5),
        );
        shouldCloseSocket = true;
        print('Tạo kết nối mới');
      }

      // Xử lý ảnh
      final tsplBytes = await _processImageForPrint(imageBytes);

      //*************************IN USB  */
      // await FlutterUsbPrinter().write(imageBytes);
      //*************************IN USB  */
      // Gửi dữ liệu
      socket?.add(tsplBytes);
      await socket?.flush();

      // Chờ máy in xử lý
      await Future.delayed(const Duration(milliseconds: 500));

      print('Gửi dữ liệu in thành công');
    } catch (e) {
      print('Lỗi kết nối/in: $e');
      rethrow;
    } finally {
      // Chỉ đóng socket nếu chúng ta tạo mới
      if (shouldCloseSocket) {
        await socket?.close();
        _socket = null;
        isConnected = false;
      }
    }
  }

  /// Xử lý ảnh để in với chất lượng cao
  static Future<Uint8List> _processImageForPrint(Uint8List imageBytes) async {
    // Decode ảnh
    final src = img.decodeImage(imageBytes);
    if (src == null) throw Exception('Không đọc được ảnh');

    // Resize về kích thước label với interpolation tốt hơn
    img.Image working = src;
    if (src.width != _labelWidth || src.height != _labelHeight) {
      working = img.copyResize(
        src,
        width: _labelWidth,
        height: _labelHeight,
        interpolation: img.Interpolation.cubic, // Sử dụng cubic thay vì linear
      );
    }

    // Cải thiện độ tương phản trước khi chuyển grayscale
    working = _enhanceContrast(working);

    // Chuyển sang grayscale
    working = img.grayscale(working);

    // Áp dụng threshold thông minh hơn
    working = _applySmartThreshold(working);

    // Convert sang bitmap data
    final bitmapData = _convertToBitmapData(working);

    // Tạo TSPL command
    return _generateTSPLCommand(bitmapData, working.width, working.height);
  }

  /// Cải thiện độ tương phản ảnh
  static img.Image _enhanceContrast(img.Image image) {
    final out = img.Image.from(image);

    // Tính toán histogram để cải thiện contrast
    final histogram = List<int>.filled(256, 0);
    for (int y = 0; y < out.height; y++) {
      for (int x = 0; x < out.width; x++) {
        final pixel = out.getPixel(x, y);
        final luma = img.getLuminance(pixel);
        histogram[luma]++;
      }
    }

    // Tìm min và max values
    int minVal = 0;
    int maxVal = 255;
    for (int i = 0; i < 256; i++) {
      if (histogram[i] > 0) {
        minVal = i;
        break;
      }
    }
    for (int i = 255; i >= 0; i--) {
      if (histogram[i] > 0) {
        maxVal = i;
        break;
      }
    }

    // Áp dụng contrast stretching
    final contrastFactor = 255.0 / (maxVal - minVal + 1);

    for (int y = 0; y < out.height; y++) {
      for (int x = 0; x < out.width; x++) {
        final pixel = out.getPixel(x, y);
        final r = img.getRed(pixel);
        final g = img.getGreen(pixel);
        final b = img.getBlue(pixel);

        final newR = ((r - minVal) * contrastFactor).clamp(0, 255).round();
        final newG = ((g - minVal) * contrastFactor).clamp(0, 255).round();
        final newB = ((b - minVal) * contrastFactor).clamp(0, 255).round();

        out.setPixelRgba(x, y, newR, newG, newB, img.getAlpha(pixel));
      }
    }

    return out;
  }

  /// Apply threshold thông minh để tối ưu ảnh in
  static img.Image _applySmartThreshold(img.Image image) {
    final out = img.Image.from(image);

    // Tính toán Otsu threshold
    final otsuThreshold = _computeOtsuThreshold(out);

    // Sử dụng threshold thông minh hơn
    final smartThreshold =
        (otsuThreshold * 0.7 + 128 * 0.3).round().clamp(100, 180);

    for (int y = 0; y < out.height; y++) {
      for (int x = 0; x < out.width; x++) {
        final pixel = out.getPixel(x, y);
        final luma = img.getLuminance(pixel);

        if (luma > smartThreshold) {
          out.setPixelRgba(x, y, 0, 0, 0); // Đen
        } else {
          out.setPixelRgba(x, y, 255, 255, 255); // Trắng
        }
      }
    }
    return out;
  }

  /// Convert ảnh sang bitmap data cho TSPL
  static List<int> _convertToBitmapData(img.Image image) {
    final width = image.width;
    final height = image.height;
    final paddedWidth = ((width + 7) ~/ 8) * 8;
    final bytesPerRow = paddedWidth ~/ 8;

    final List<int> bitmap = [];

    for (int row = 0; row < height; row++) {
      for (int byteCol = 0; byteCol < bytesPerRow; byteCol++) {
        int byteAccumulator = 0;
        for (int bit = 0; bit < 8; bit++) {
          final px = byteCol * 8 + bit;
          int luminance = 255; // Mặc định trắng

          if (px < width) {
            final pixel = image.getPixel(px, row);
            final red = img.getRed(pixel);
            final green = img.getGreen(pixel);
            final blue = img.getBlue(pixel);
            luminance = (0.299 * red + 0.587 * green + 0.114 * blue).round();
          }

          // TSPL: 1 = đen, 0 = trắng
          if (luminance < 128) {
            byteAccumulator |= (1 << (7 - bit));
          }
        }
        bitmap.add(byteAccumulator);
      }
    }

    return bitmap;
  }

  /// Tạo TSPL command
  static Uint8List _generateTSPLCommand(
    List<int> bitmapData,
    int width,
    int height,
  ) {
    final bytesPerRow = ((width + 7) ~/ 8);

    // TSPL header
    final header = StringBuffer()
      ..write('SIZE 50 mm, 30 mm\r\n')
      ..write('GAP 2 mm, 0 mm\r\n')
      ..write('DENSITY 6\r\n')
      ..write('DIRECTION 1\r\n')
      ..write('CLS\r\n')
      ..write('BITMAP 0,0,$bytesPerRow,$height,0,');

    final List<int> allBytes = []
      ..addAll(header.toString().codeUnits)
      ..addAll(bitmapData)
      ..addAll('\r\nPRINT 1,1\r\n'.codeUnits);

    return Uint8List.fromList(allBytes);
  }

  /// Kết nối tới máy in
  static Future<bool> connect({
    required String printerIp,
    int port = 9100,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      // Đóng kết nối cũ nếu có
      await disconnect();

      // Tạo kết nối mới
      _socket = await Socket.connect(
        printerIp,
        port,
        timeout: timeout,
      );

      isConnected = true;

      // Lắng nghe khi socket đóng
      _socket!.done.whenComplete(() {
        isConnected = false;
        _socket = null;
      });

      print('Kết nối máy in thành công: $printerIp:$port');
      return true;
    } catch (e) {
      print('Lỗi kết nối máy in: $e');
      isConnected = false;
      _socket = null;
      return false;
    }
  }

  /// Tính ngưỡng Otsu để tối ưu threshold
  static int _computeOtsuThreshold(img.Image gray) {
    // Tạo histogram 256 mức xám
    final histogram = List<int>.filled(256, 0);
    for (int y = 0; y < gray.height; y++) {
      for (int x = 0; x < gray.width; x++) {
        final pixel = gray.getPixel(x, y);
        final l = img.getLuminance(pixel);
        histogram[l]++;
      }
    }

    final total = gray.width * gray.height;
    double sum = 0;
    for (int t = 0; t < 256; t++) sum += t * histogram[t];

    double sumB = 0;
    int wB = 0;
    int wF = 0;
    double varMax = -1;
    int threshold = 128;

    for (int t = 0; t < 256; t++) {
      wB += histogram[t];
      if (wB == 0) continue;
      wF = total - wB;
      if (wF == 0) break;

      sumB += t * histogram[t];
      final mB = sumB / wB; // mean background
      final mF = (sum - sumB) / wF; // mean foreground

      final between = wB * wF * (mB - mF) * (mB - mF);
      if (between > varMax) {
        varMax = between;
        threshold = t;
      }
    }

    return threshold;
  }

  /// Đóng kết nối
  static Future<void> disconnect() async {
    try {
      await _socket?.close();
    } finally {
      _socket = null;
      isConnected = false;
    }
  }
}
