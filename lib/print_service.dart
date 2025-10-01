import 'dart:async';
import 'dart:typed_data' show ByteData, Uint8List;
import 'dart:typed_data' show ByteData, Uint8List;

import 'package:app/invoice.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_usb_printer/flutter_usb_printer.dart';

import 'package:image/image.dart' as img;

class PrintService {
  NetworkPrinter? _printer;
  CapabilityProfile? _profile;

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
      await Future.delayed(const Duration(milliseconds: 120));

      // Reset và đảm bảo trạng thái máy in sạch
      _printer!.reset();

      // Tính max width theo khổ giấy máy in và đảm bảo bội số của 8
      final int paperMaxWidth =
          (_printer!.paperSize == PaperSize.mm58) ? 384 : 576;
      print('Paper size: ${_printer!.paperSize}, Max width: $paperMaxWidth');
      // IN USB
      //********************************************************* */
      // Chuyển thành ESC/POS bytes (GS v 0)
      final generator = Generator(_printer!.paperSize, _profile!);
      // Convert ảnh thành ESC/POS bytes
      final List<int> imageBytes = generator.imageRaster(decodedImage);

      // Gửi tới máy in qua USB
      await FlutterUsbPrinter().write(Uint8List.fromList(imageBytes));
      //********************************************************* */

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

  /// Hàm capture widget hoàn toàn không giới hạn chiều cao - KHÔNG hiển thị lên màn hình
  Future<img.Image?> captureFullContentWidget(
      Widget widget, BuildContext context,
      {double pixelRatio = 3.0, int paperMaxWidth = 576}) async {
    try {
      final GlobalKey repaintBoundaryKey = GlobalKey();

      // Tạo widget wrapper hoàn toàn không giới hạn chiều cao
      final wrappedWidget = RepaintBoundary(
        key: repaintBoundaryKey,
        child: Material(
          color: Colors.white,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: paperMaxWidth.toDouble(),
              minWidth: paperMaxWidth.toDouble(),
              // Không giới hạn chiều cao - để widget tự điều chỉnh
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
            offset:
                Offset(-10000, -10000), // Di chuyển ra ngoài màn hình cả X và Y
            child: Container(
              width: paperMaxWidth.toDouble(),
              height: double.infinity,
              child: SingleChildScrollView(
                child: wrappedWidget,
              ),
            ),
          ),
        ),
      );

      Overlay.of(context).insert(overlayEntry);

      try {
        // Chờ widget render hoàn toàn - tăng thời gian chờ để đảm bảo render đầy đủ
        await Future.delayed(const Duration(milliseconds: 500));

        final RenderRepaintBoundary? boundary =
            repaintBoundaryKey.currentContext?.findRenderObject()
                as RenderRepaintBoundary?;

        if (boundary == null) {
          print('Không thể tìm thấy RenderRepaintBoundary');
          return null;
        }

        // Kiểm tra kích thước thực tế của widget trước khi capture
        final RenderBox? renderBox = boundary as RenderBox?;
        if (renderBox != null) {
          print(
              'Widget actual size: ${renderBox.size.width}x${renderBox.size.height}');
        }

        // Capture với pixel ratio cao
        final ui.Image image =
            await boundary.toImage(pixelRatio: pixelRatio); //
        final ByteData? byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);

        if (byteData == null) {
          print('Không thể convert image thành byte data');
          return null;
        }

        final capturedImage = img.decodeImage(byteData.buffer.asUint8List());

        if (capturedImage != null) {
          print(
              'Captured FULL content image size: ${capturedImage.width}x${capturedImage.height}');

          // Chỉ crop khoảng trắng trên/dưới, giữ nguyên chiều cao
          final enhanced = cropVerticalWhitespace(capturedImage);
          final grayscale = img.grayscale(enhanced);
          final processed = threshold(grayscale, level: 140);

          print(
              'Processed FULL content image size: ${processed.width}x${processed.height}');

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
        pixelRatio: 3.0, // Tăng pixel ratio để chất lượng tốt hơn
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

  /// Hàm in Invoice với đảm bảo không mất nội dung
  Future<void> printInvoice(
      ReceiptData receiptData, BuildContext context) async {
    try {
      print('Bắt đầu in Invoice với đảm bảo không mất nội dung...');

      // Tạo Invoice widget với forPrint: true để tối ưu cho in ấn
      final invoiceWidget = Invoice(
        receiptData: receiptData,
        forPrint: true,
      );

      // In widget với nội dung dài
      await printLongContentWidget(invoiceWidget, context);

      print('In Invoice thành công!');
    } catch (e) {
      print("Lỗi in Invoice: $e");
    }
  }

  /// Convert ảnh sang ESC/POS raster (GS v 0)
  /// [imageBytes] : Uint8List ảnh gốc (png, jpg...)
  /// [maxWidth]   : chiều rộng dot của máy in (vd: 384 cho 58mm, 576 cho 80mm)
  /// [threshold]  : ngưỡng trắng/đen (0-255)
  Future<Uint8List> imageToEscPosRaster(Uint8List imageBytes, int maxWidth,
      {int threshold = 128}) async {
    // Decode ảnh
    img.Image? src = img.decodeImage(imageBytes);
    if (src == null) throw Exception("Không decode được ảnh");

    // Resize theo chiều rộng máy in, giữ tỉ lệ
    final int newHeight = (src.height * maxWidth / src.width).round();
    img.Image resized = img.copyResize(src, width: maxWidth, height: newHeight);

    final int width = resized.width;
    final int height = resized.height;
    final int widthBytes = (width + 7) ~/ 8;

    List<int> bytes = [];

    // ESC/POS command: GS v 0 m xL xH yL yH
    bytes.addAll([0x1D, 0x76, 0x30, 0x00]);
    bytes.add(widthBytes & 0xFF); // xL
    bytes.add((widthBytes >> 8) & 0xFF); // xH
    bytes.add(height & 0xFF); // yL
    bytes.add((height >> 8) & 0xFF); // yH

    // Dữ liệu bitmap
    for (int y = 0; y < height; y++) {
      for (int xByte = 0; xByte < widthBytes; xByte++) {
        int byteVal = 0;
        for (int bit = 0; bit < 8; bit++) {
          int x = xByte * 8 + bit;
          if (x < width) {
            int pixel = resized.getPixel(x, y);
            int r = img.getRed(pixel);
            int g = img.getGreen(pixel);
            int b = img.getBlue(pixel);
            int gray = (0.3 * r + 0.59 * g + 0.11 * b).round();
            if (gray < threshold) {
              byteVal |= (1 << (7 - bit));
            }
          }
        }
        bytes.add(byteVal);
      }
    }

    return Uint8List.fromList(bytes);
  }
}
