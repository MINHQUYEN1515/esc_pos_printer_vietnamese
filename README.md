# Demo In Hóa Đơn/Tem (ESC/POS & TSPL) – Flutter

Ứng dụng Flutter minh họa kết nối và in với máy in nhiệt qua LAN (ESC/POS), USB, và in tem kiểu TSPL (XPrinter, v.v.). Giao diện demo cho phép:

- Kết nối máy in LAN (IP, cổng 9100) và in hóa đơn từ widget xem trước.
- Quét, kết nối máy in USB (plugin flutter_usb_printer) và gửi bytes in ESC/POS.
- Kết xuất widget tem thành ảnh và gửi lệnh TSPL dạng BITMAP qua socket TCP.

## Tính năng chính

- In ESC/POS qua LAN: sử dụng `esc_pos_printer` và `esc_pos_utils`.
- In ESC/POS qua USB: sử dụng `flutter_usb_printer` (gửi bytes thô).
- In tem TSPL (XPrinter…): chuyển widget -> PNG -> BITMAP TSPL và gửi qua TCP.
- Xem trước hóa đơn/tem bằng `RepaintBoundary` để đảm bảo ảnh sắc nét khi in.

## Cấu trúc thư mục liên quan

- `lib/main.dart`: UI demo, xem trước, thao tác kết nối/in.
- `lib/print_service.dart`: Logic kết nối LAN, dựng bytes ESC/POS, in ảnh raster, gửi TSPL.
- `lib/usb_service.dart`: Tiện ích dò thiết bị và gửi dữ liệu qua USB.

## Phụ thuộc chính (pubspec)

- `esc_pos_printer`, `esc_pos_utils`: In ESC/POS qua mạng.
- `flutter_usb_printer`: Kết nối/ghi dữ liệu tới máy in USB.
- `image`: Xử lý ảnh (grayscale, resize, adjust…).
- `intl`: Định dạng tiền tệ/ngày giờ.
- `qr_flutter`: Render mã QR trên hóa đơn/tem.

## Yêu cầu môi trường

- Flutter SDK (>= 3.0.6 < 4.0.0) theo `pubspec.yaml`.
- Thiết bị Android có hỗ trợ USB-Host nếu in USB.
- Máy in nhiệt hỗ trợ ESC/POS (LAN/USB) hoặc TSPL (nhãn, tem) qua TCP port 9100.

## Cài đặt & chạy

```bash
flutter pub get
flutter run
```

Ứng dụng có sẵn màn hình demo “Printer Demo” với các khu vực LAN, USB, In Tem và trạng thái.

## Hướng dẫn sử dụng nhanh

- Kết nối LAN:
  - Nhập IP máy in (ví dụ: 192.168.1.100), nhấn “Kết nối LAN”.
  - Nhấn “In thử LAN”, xem preview hóa đơn và bấm “IN”.

- Kết nối USB:
  - Nhấn “Kết nối USB” để dò thiết bị đầu tiên và ghép nối.
  - Nhấn “In thử USB” để gửi dữ liệu mẫu (cần plugin hỗ trợ ghi bytes).

- In tem (TSPL – XPrinter):
  - Nhập IP máy in (LAN), bấm “In tem”. Ứng dụng sẽ render widget tem -> ảnh -> gửi lệnh TSPL `BITMAP` qua TCP.

## Lưu ý cấu hình nền tảng

### Android

- Quyền mạng: đảm bảo có `INTERNET` (mặc định Flutter đã thêm).
- In USB yêu cầu thiết bị hỗ trợ USB host; một số máy cần cấp quyền khi cắm lần đầu.
- Cổng mặc định: 9100 cho ESC/POS/TSPL qua LAN (có thể thay đổi trong cài đặt máy in).

### iOS/macOS/Windows/Linux

- Demo tập trung Android/LAN. Với USB trên iOS không được plugin hỗ trợ như Android.
- In qua LAN (TCP 9100) thường hoạt động tương tự giữa các nền tảng desktop/mobile nếu cùng mạng.

## Tùy biến nội dung in

- Hóa đơn: được dựng từ widget `_buildInvoiceWidget` trong `main.dart`. Bạn có thể thay đổi logo, tiêu đề, danh sách hàng, QR… Sau đó nút IN sẽ chụp ảnh widget và gửi in raster.
- Tem/nhãn: widget ở `_buildLabelWidget`. Khi “In tem”, code trong `print_service.dart` sẽ:
  1) Decode ảnh PNG từ widget.
  2) Resize về bội số 8 và theo `maxWidthPx` phù hợp máy.
  3) Chuyển thành mảng BITMAP (đen/trắng) và gửi lệnh TSPL qua socket.

## Khắc phục sự cố

- Không kết nối được LAN: kiểm tra IP, cổng 9100, cùng mạng, tường lửa/router.
- In nhòe/mờ: tăng `pixelRatio` khi chụp widget, hoặc chỉnh contrast/brightness trong `printImageRaster`.
- Ảnh tem bị cắt: giảm `maxWidthPx` hoặc chỉnh kích thước widget; đảm bảo chiều rộng là bội số 8.
- USB không thấy thiết bị: kiểm tra hỗ trợ USB-OTG/USB Host, thử cáp khác, kiểm tra quyền thiết bị.

## Bản quyền

Dự án mẫu phục vụ mục đích demo. Các tên/thông tin hiển thị trong hóa đơn chỉ là ví dụ. Tham khảo thêm tài liệu Flutter tại [Flutter docs](https://docs.flutter.dev/).
