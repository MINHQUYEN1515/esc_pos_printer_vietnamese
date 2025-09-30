import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:image/image.dart' as img;
import 'label_widget.dart';

class LabelPrintService {
  static const int _labelWidth = 400; // 50mm @ 203dpi
  static const int _labelHeight = 240; // 30mm @ 203dpi

  /// In label widget bằng cách convert sang ảnh rồi gửi TSPL command
  static Future<void> printLabelWidget({
    required String title,
    required String content,
    String? additionalInfo,
    required String printerIp,
    int port = 9100,
  }) async {
    try {
      print('Bắt đầu in label widget...');

      // Tạo LabelWidget
      final labelWidget = LabelWidget(
        title: title,
        content: content,
        additionalInfo: additionalInfo,
      );

      // Convert widget sang ảnh
      final imageBytes = await _widgetToImageBytes(labelWidget);
      if (imageBytes == null) {
        throw Exception('Không thể convert widget sang ảnh');
      }

      // In ảnh bằng TSPL command
      await _printImageWithTSPL(
        imageBytes: imageBytes,
        printerIp: printerIp,
        port: port,
      );

      print('In label widget thành công!');
    } catch (e) {
      print('Lỗi in label widget: $e');
      rethrow;
    }
  }

  /// Convert LabelWidget sang ảnh bytes
  static Future<Uint8List?> _widgetToImageBytes(Widget widget) async {
    try {
      final GlobalKey repaintBoundaryKey = GlobalKey();

      // Wrap widget với RepaintBoundary và kích thước cố định
      final wrappedWidget = RepaintBoundary(
        key: repaintBoundaryKey,
        child: Material(
          color: Colors.white,
          child: SizedBox(
            width: _labelWidth.toDouble(),
            height: _labelHeight.toDouble(),
            child: widget,
          ),
        ),
      );

      // Tạo overlay để render widget ẩn
      late OverlayEntry overlayEntry;
      overlayEntry = OverlayEntry(
        builder: (context) => Material(
          color: Colors.transparent,
          child: Transform.translate(
            offset: const Offset(-10000, -10000), // Di chuyển ra ngoài màn hình
            child: wrappedWidget,
          ),
        ),
      );

      // Cần context để insert overlay
      final context = _getCurrentContext();
      if (context == null) {
        print('Không có context để render widget');
        return null;
      }

      Overlay.of(context).insert(overlayEntry);

      try {
        // Chờ widget render
        await Future.delayed(const Duration(milliseconds: 100));
        await SchedulerBinding.instance.endOfFrame;

        final RenderRepaintBoundary? boundary =
            repaintBoundaryKey.currentContext?.findRenderObject()
                as RenderRepaintBoundary?;

        if (boundary == null) {
          print('Không thể tìm thấy RenderRepaintBoundary');
          return null;
        }

        // Capture với pixel ratio 2.0 để có chất lượng tốt
        final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
        final ByteData? byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);

        if (byteData == null) {
          print('Không thể convert image thành byte data');
          return null;
        }

        return byteData.buffer.asUint8List();
      } finally {
        overlayEntry.remove();
      }
    } catch (e) {
      print('Lỗi convert widget sang ảnh: $e');
      return null;
    }
  }

  /// In ảnh bằng TSPL command
  static Future<void> _printImageWithTSPL({
    required Uint8List imageBytes,
    required String printerIp,
    int port = 9100,
  }) async {
    try {
      // Decode ảnh
      final src = img.decodeImage(imageBytes);
      if (src == null) throw Exception('Không đọc được ảnh');

      // Resize về kích thước label nếu cần
      img.Image working = src;
      if (src.width != _labelWidth || src.height != _labelHeight) {
        working = img.copyResize(
          src,
          width: _labelWidth,
          height: _labelHeight,
          interpolation: img.Interpolation.linear,
        );
      }

      // Chuyển sang grayscale và threshold để in rõ
      working = img.grayscale(working);
      working = _threshold(working, level: 140);

      // Convert sang bitmap data cho TSPL
      final bitmapData = _convertToBitmapData(working);

      // Tạo TSPL command
      final tsplCommand =
          _generateTSPLCommand(bitmapData, working.width, working.height);

      // Gửi tới máy in
      await _sendToPrinter(tsplCommand, printerIp, port);

      print('Gửi label tới máy in thành công');
    } catch (e) {
      print('Lỗi in ảnh TSPL: $e');
      rethrow;
    }
  }

  /// Convert ảnh sang bitmap data cho TSPL
  static List<int> _convertToBitmapData(img.Image image) {
    final width = image.width;
    final height = image.height;

    // Bội số của 8 cho TSPL
    final paddedWidth = ((width + 7) ~/ 8) * 8;
    final bytesPerRow = paddedWidth ~/ 8;

    final List<int> bitmap = [];

    for (int row = 0; row < height; row++) {
      for (int byteCol = 0; byteCol < bytesPerRow; byteCol++) {
        int b = 0;
        for (int bit = 0; bit < 8; bit++) {
          final px = byteCol * 8 + bit;
          int luminance = 255; // default = white
          if (px < width) {
            final pixel = image.getPixel(px, row);
            final r = img.getRed(pixel);
            final g = img.getGreen(pixel);
            final b = img.getBlue(pixel);
            luminance = (0.299 * r + 0.587 * g + 0.114 * b).round();
          }
          // TSPL: 1 = black, 0 = white (bit order: MSB -> left)
          if (luminance < 128) {
            b |= (1 << (7 - bit));
          }
        }
        bitmap.add(b);
      }
    }

    return bitmap;
  }

  /// Tạo TSPL command
  static String _generateTSPLCommand(
      List<int> bitmapData, int width, int height) {
    final bytesPerRow = ((width + 7) ~/ 8);

    String tsplCommand = '''
SIZE 50 mm, 30 mm
GAP 2 mm, 0 mm
DENSITY 8
DIRECTION 1
CLS
BITMAP 0,0,$bytesPerRow,$height,0,''';

    // Thêm bitmap data (binary)
    final headerBytes = tsplCommand.codeUnits;
    final allBytes = [...headerBytes, ...bitmapData];

    // Thêm PRINT command
    allBytes.addAll('\nPRINT 1,1\n'.codeUnits);

    return String.fromCharCodes(allBytes);
  }

  /// Gửi data tới máy in
  static Future<void> _sendToPrinter(
      String command, String printerIp, int port) async {
    final socket = await Socket.connect(printerIp, port,
        timeout: const Duration(seconds: 5));
    try {
      socket.add(command.codeUnits);
      await socket.flush();
      await Future.delayed(
          const Duration(milliseconds: 500)); // Chờ máy in xử lý
    } finally {
      socket.close();
    }
  }

  /// Threshold function
  static img.Image _threshold(img.Image src, {int level = 128}) {
    final out = img.Image.from(src);
    for (int y = 0; y < out.height; y++) {
      for (int x = 0; x < out.width; x++) {
        final pixel = out.getPixel(x, y);
        final luma = img.getLuminance(pixel);
        if (luma > level) {
          out.setPixelRgba(x, y, 255, 255, 255); // trắng
        } else {
          out.setPixelRgba(x, y, 0, 0, 0); // đen
        }
      }
    }
    return out;
  }

  /// Lấy context hiện tại (cần implement cách lấy context)
  static BuildContext? _getCurrentContext() {
    // Cần implement cách lấy context hiện tại
    // Có thể dùng GlobalKey hoặc Navigator để lấy context
    return null;
  }

  /// In label với context được truyền vào
  static Future<void> printLabelWidgetWithContext({
    required String title,
    required String content,
    String? additionalInfo,
    required String printerIp,
    required BuildContext context,
    int port = 9100,
  }) async {
    try {
      print('Bắt đầu in label widget với context...');

      // Tạo LabelWidget
      final labelWidget = LabelWidget(
        title: title,
        content: content,
        additionalInfo: additionalInfo,
      );

      // Convert widget sang ảnh với context
      final imageBytes =
          await _widgetToImageBytesWithContext(labelWidget, context);
      if (imageBytes == null) {
        throw Exception('Không thể convert widget sang ảnh');
      }

      // In ảnh bằng TSPL command
      await _printImageWithTSPL(
        imageBytes: imageBytes,
        printerIp: printerIp,
        port: port,
      );

      print('In label widget thành công!');
    } catch (e) {
      print('Lỗi in label widget: $e');
      rethrow;
    }
  }

  /// Convert widget sang ảnh với context được truyền vào
  static Future<Uint8List?> _widgetToImageBytesWithContext(
      Widget widget, BuildContext context) async {
    try {
      final GlobalKey repaintBoundaryKey = GlobalKey();

      // Wrap widget với RepaintBoundary và kích thước cố định
      final wrappedWidget = RepaintBoundary(
        key: repaintBoundaryKey,
        child: Material(
          color: Colors.white,
          child: SizedBox(
            width: _labelWidth.toDouble(),
            height: _labelHeight.toDouble(),
            child: widget,
          ),
        ),
      );

      // Tạo overlay để render widget ẩn
      late OverlayEntry overlayEntry;
      overlayEntry = OverlayEntry(
        builder: (context) => Material(
          color: Colors.transparent,
          child: Transform.translate(
            offset: const Offset(-10000, -10000), // Di chuyển ra ngoài màn hình
            child: wrappedWidget,
          ),
        ),
      );

      Overlay.of(context).insert(overlayEntry);

      try {
        // Chờ widget render
        await Future.delayed(const Duration(milliseconds: 100));
        await SchedulerBinding.instance.endOfFrame;

        final RenderRepaintBoundary? boundary =
            repaintBoundaryKey.currentContext?.findRenderObject()
                as RenderRepaintBoundary?;

        if (boundary == null) {
          print('Không thể tìm thấy RenderRepaintBoundary');
          return null;
        }

        // Capture với pixel ratio 2.0 để có chất lượng tốt
        final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
        final ByteData? byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);

        if (byteData == null) {
          print('Không thể convert image thành byte data');
          return null;
        }

        return byteData.buffer.asUint8List();
      } finally {
        overlayEntry.remove();
      }
    } catch (e) {
      print('Lỗi convert widget sang ảnh: $e');
      return null;
    }
  }
}
