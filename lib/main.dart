import 'package:app/invoice.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'dart:ui' as ui;
import 'print_service.dart';
import 'usb_service.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

final sampleData = ReceiptData(
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
        attributes: [
          AttributeData(name: 'Thuoc tinh 1', price: 5000),
          AttributeData(name: 'Thuoc tinh 2', price: 3000),
        ],
        note: 'Ghi chu san pham nay rat dai va co nhieu thong tin chi tiet',
      ),
    ],
    totalMoney: 245000,
    totalDiscount: 0,
    totalShipping: null,
    tax: null,
    totalMoneyPayment: 245000,
    paymentMethod: 'CASH',
    paymentStatus: 'PAID',
    note: null,
    qrBank: 'DH-AOYX-4423',
  ),
);
final GlobalKey _keyPrint = GlobalKey();
void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        scaffoldBackgroundColor: Colors.grey[50],
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 44),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      home: const PrinterDemoPage(),
    );
  }
}

class PrinterDemoPage extends StatefulWidget {
  const PrinterDemoPage({super.key});

  @override
  State<PrinterDemoPage> createState() => _PrinterDemoPageState();
}

class _PrinterDemoPageState extends State<PrinterDemoPage> {
  final PrintService _service = PrintService();
  final UsbService _usbService = UsbService();
  final TextEditingController _lanIpController =
      TextEditingController(text: '192.168.10.50');

  String _status = '';
  final NumberFormat money =
      NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
  final GlobalKey previewContainerKey = GlobalKey();
  final GlobalKey labelPreviewKey = GlobalKey();

  Future<void> _connectLan() async {
    final ip = _lanIpController.text.trim();
    if (ip.isEmpty) {
      setState(() => _status = 'Vui lòng nhập IP LAN');
      return;
    }
    await _service.chooseLanAndLoadProfile(ip: ip);
    final err = await _service.connect(ip: ip);
    setState(() => _status =
        err == null ? 'LAN: kết nối thành công $ip' : 'LAN: lỗi kết nối: $err');
  }

  Future<void> _printTestLan() async {
    if (!_service.isConnected) {
      setState(() => _status = 'Chưa kết nối LAN');
      return;
    }
    await Future.delayed(const Duration(milliseconds: 100));
    final boundary = previewContainerKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      return;
    }
    // Đợi 1 chút để widget vẽ xong, tránh bị duplicate
    await Future.delayed(const Duration(milliseconds: 100));

    // Tăng pixelRatio để có ảnh to và nét hơn
    const double pixelRatio = 2.0;
    // Đợi lâu hơn để widget vẽ xong hoàn toàn, tránh phải bấm 2 lần
    await Future.delayed(const Duration(milliseconds: 200));
    final ui.Image renderedImage =
        await boundary.toImage(pixelRatio: pixelRatio);
    final ByteData? pngByteData =
        await renderedImage.toByteData(format: ui.ImageByteFormat.png);
    if (pngByteData == null) {
      setState(() => _status = 'Lỗi: Không thể tạo ảnh');
      return;
    }
    final Uint8List pngBytes = pngByteData.buffer.asUint8List();

    final img.Image? decodedImage = img.decodeImage(pngBytes);
    if (decodedImage == null) {
      setState(() => _status = 'Lỗi: Không thể decode ảnh');
      return;
    }

    setState(() => _status = 'Đang in...');
    final result = await _service.printImageRaster(decodedImage: decodedImage);
    setState(() => _status = 'Kết quả in: ${result.msg}');
  }

  Future<void> _connectUsb() async {
    setState(() => _status = 'Đang tìm máy in USB...');
    final devices = await _usbService.getDeviceList();
    if (devices.isEmpty) {
      setState(() => _status = 'Không tìm thấy thiết bị USB');
      return;
    }

    Map<String, dynamic> pick = devices.first;
    int? parseId(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is String) {
        final s = v.toLowerCase().replaceAll('0x', '');
        return int.tryParse(s, radix: 16) ?? int.tryParse(v);
      }
      return null;
    }

    final vendorId = parseId(pick['vendorId']);
    final productId = parseId(pick['productId']);
    if (vendorId == null || productId == null) {
      setState(() => _status = 'Thiếu vendorId/productId từ thiết bị USB');
      return;
    }

    final ok =
        await _usbService.connect(vendorId: vendorId, productId: productId);
    if (!ok) {
      setState(() => _status = 'Kết nối USB thất bại');
      return;
    }

    await _service.chooseUsbAndLoadProfile(
        vendorId: vendorId, productId: productId);
    await _service.connectUsb(sender: (bytes) async {
      await _usbService.write(bytes);
    });

    setState(() => _status = 'USB: kết nối thành công ($vendorId:$productId)');
  }

  showImage(Uint8List pngBytes) {
    showDialog(
      context: context,
      builder: (context) =>
          SizedBox(height: 200, width: 200, child: Image.memory(pngBytes)),
    );
  }

  Future<void> _printTestUsb() async {
    final result = await _service.printReceiptRaw(
      storeName: 'Cửa hàng Demo',
      invoiceNo: 'USB-TEST-001',
      items: const [
        ReceiptItem(name: 'SP USB', quantity: 1, totalPrice: 10000),
      ],
      total: 10000,
      footerText: 'Cảm ơn!',
    );
    setState(() =>
        _status = 'Kết quả in USB: ${result.msg} (cần plugin để gửi bytes)');
  }

  Future<void> _printLabelXPrinter() async {
    final ip = _lanIpController.text.trim();
    if (ip.isEmpty) {
      setState(() => _status = 'Vui lòng nhập IP LAN');
      return;
    }

    final boundary = labelPreviewKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      setState(() => _status = 'Không tìm thấy vùng xem trước nhãn');
      return;
    }

    const double pixelRatio = 2.0;
    await Future.delayed(const Duration(milliseconds: 120));
    final ui.Image renderedImage =
        await boundary.toImage(pixelRatio: pixelRatio);
    final ByteData? pngBytes =
        await renderedImage.toByteData(format: ui.ImageByteFormat.png);
    if (pngBytes == null) {
      setState(() => _status = 'Lỗi chuyển đổi ảnh nhãn');
      return;
    }

    setState(() => _status = 'Đang gửi nhãn tới máy in...');
    try {
      await _service.printImageTSPLFromBytes(
        imageData: pngBytes.buffer.asUint8List(),
        printerIp: ip,
        x: 20,
        y: 20,
        maxWidthPx: 576,
      );
      setState(() => _status = 'In tem thành công');
    } catch (e) {
      setState(() => _status = 'Lỗi in tem: $e');
    }
  }

  @override
  void dispose() {
    _lanIpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer Demo'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // LAN Card
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.router_outlined),
                          SizedBox(width: 8),
                          Text(
                            'Kết nối LAN',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _lanIpController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'IP máy in LAN',
                          hintText: 'VD: 192.168.1.100',
                          prefixIcon: Icon(Icons.lan_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _connectLan,
                              icon: const Icon(Icons.link),
                              label: const Text('Kết nối LAN'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _service.printInvoice(sampleData, context);
                              },
                              icon: const Icon(Icons.print_outlined),
                              label: const Text('In thử LAN'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // LABEL (TEM) Card
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.local_offer_outlined),
                          SizedBox(width: 8),
                          Text(
                            'In tem (XPrinter)',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildLabelWidget(),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ElevatedButton.icon(
                          onPressed: _printLabelXPrinter,
                          icon: const Icon(Icons.print),
                          label: const Text('In tem'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // USB Card
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.usb_outlined),
                          SizedBox(width: 8),
                          Text(
                            'Kết nối USB',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _connectUsb,
                              icon: const Icon(Icons.cable_outlined),
                              label: const Text('Kết nối USB'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _printTestLan, // giữ nguyên logic gọi
                              icon: const Icon(Icons.print),
                              label: const Text('In thử USB'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // PDF Card
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.picture_as_pdf_outlined),
                          SizedBox(width: 8),
                          Text(
                            'In PDF',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            _showPreviewDialog();
                          },
                          icon: const Icon(Icons.print_rounded),
                          label: const Text('IN'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Status Card
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.info_outline),
                          SizedBox(width: 8),
                          Text(
                            'Trạng thái',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _status.isEmpty ? 'Chưa có trạng thái' : _status,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPreviewDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: RepaintBoundary(
            key: previewContainerKey,
            child: Container(
                width:
                    380, // Chiều rộng hóa đơn (tương đương khổ giấy in mm80 ~ 576px)
                height:
                    600, // Chiều cao tạm fix, bạn có thể thay đổi theo nhu cầu
                color: Colors.white,
                child: Column(
                  children: [
                    _buildInvoiceWidget(),
                    ElevatedButton(onPressed: _printTestLan, child: Text("IN"))
                  ],
                )),
          ),
        ),
      ),
    );
  }

  // Widget hoá đơn — tùy chỉnh theo mẫu của bạn
  Widget _buildInvoiceWidget({PaperSize paperSize = PaperSize.mm80}) {
    final items = [
      {
        'name':
            'Ten san pham dai th iet dai dai dai dai dai dai dai dai da i dai dai dai dai',
        'qty': 1,
        'price': 20000
      },
    ];
    final total = items.fold<int>(
        0, (s, it) => s + (it['qty'] as int) * (it['price'] as int));

    final double maxWidth = (paperSize == PaperSize.mm58) ? 384 : 576;

    return Material(
      color: Colors.white,
      child: SizedBox(
        width: maxWidth,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),

              Image.network(
                  width: 70,
                  height: 70,
                  color: Colors.black,
                  "https://cdn-new.topcv.vn/unsafe/140x/https://static.topcv.vn/company_logos/0E6pkRSt8cpHLo4OXHPoWNpxIiPWAQN1_1751627313____057cf59a177e4cacee6bb8ad9319e08b.png"),
              // Header Section
              const Center(
                child: Text(
                  'HÓA ĐƠN THANH TOÁN',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const Center(
                child: Text(
                  'Zami Solution FNB',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
              const Center(
                child: Text(
                  'Mã đơn:DH-AOYX-4423',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w500,
                    fontSize: 10,
                  ),
                ),
              ),

              // Order Details
              _buildOrderDetail('Thời gian tạo:', '20/09/2025 08:55'),
              _buildOrderDetail('Thời gian in:', '20/09/2025 08:55'),
              _buildOrderDetail('Nhân viên:', 'Zami FnB', isBold: true),

              _buildDashedLine(),

              // Item List Header
              Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(
                      'SL',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Sản phẩm',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      'Đơn giá',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      'Thành tiền',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),

              // Items
              ...items.map((it) {
                final name = it['name'] as String;
                final qty = it['qty'] as int;
                final price = it['price'] as int;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 40,
                        child: Text(
                          qty.toString(),
                          style: TextStyle(
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.w500,
                              fontSize: 12),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.w500,
                              fontSize: 12),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: Text(
                          money.format(price).replaceAll('₫', ''),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.w500,
                              fontSize: 12),
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: Text(
                          money.format(qty * price).replaceAll('₫', ''),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.w500,
                              fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),

              _buildDashedLine(),

              // Summary Section
              _buildSummaryRow('Thành tiền:',
                  money.format(total).replaceAll('₫', '') + ' d'),
              _buildDashedLine(),
              _buildSummaryRow('Tổng thành tiền:',
                  money.format(total).replaceAll('₫', '') + ' d'),
              _buildSummaryRow('Phương thức thanh toán:', 'Tiền mặt'),
              _buildSummaryRow('Trạng thái thanh toán:', 'Đã thanh toán'),
              _buildSummaryRow('Ghi chú:', ''),

              // QR Code Section
              const Align(
                alignment: Alignment.center,
                child: Text(
                  'Mã QR thanh toán',
                  style: TextStyle(
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w500,
                      fontSize: 12),
                ),
              ),
              Center(
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: Center(
                    child: QrImageView(
                      data: '1234567890',
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                  ),
                ),
              ),

              // Footer Section
              Align(
                alignment: Alignment.center,
                child: Text(
                  'Tra cứu hóa đơn điện tử tại',
                  style: TextStyle(
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w500,
                      fontSize: 12),
                ),
              ),
              Center(
                child: Text(
                  'https://tracuuhddt.zamiapp.vn',
                  style: TextStyle(
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w500,
                      fontSize: 12),
                ),
              ),
              Center(
                child: Text(
                  'Mã tra cứu: DH-AOYX-4423',
                  style: TextStyle(
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w500,
                      fontSize: 12),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'Cảm ơn quý khách đã mua hàng!',
                  style: TextStyle(
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w500,
                      fontSize: 12),
                ),
              ),
              Center(
                child: Text(
                  'Hotline: 0937155085',
                  style: TextStyle(
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w500,
                      fontSize: 12),
                ),
              ),
              Center(
                child: Text(
                  'Powered by Zami Solution',
                  style: TextStyle(
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w500,
                      fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabelWidget() {
    return RepaintBoundary(
      key: labelPreviewKey,
      child: Container(
        padding: EdgeInsets.all(8),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Zami Solution',
              style: TextStyle(
                fontSize: 13, // vừa đủ nổi bật
                fontFamily: 'Roboto',
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 1),
            SizedBox(
              width: 200, // chừa chỗ QR
              child: const Text(
                'Mã SP: ZM-001\nTên: Sản phẩm demo siêu dài siêu hay',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Roboto',
                ),
                softWrap: true,
              ),
            ),
            const SizedBox(height: 1),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Giá: 25.000 đ',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // SizedBox(
                    //   width: 40, // nhỏ lại để nhường chỗ text
                    //   height: 40,
                    //   child: QrImageView(
                    //     data: 'ZM-001',
                    //     version: QrVersions.auto,
                    //   ),
                    // ),
                  ],
                ),
                Row(
                  children: [
                    const Text(
                      'HSD: 31/12/2025',
                      style: TextStyle(
                        fontSize: 9,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '*ZM-001*',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'RobotoMono', // mono font cho barcode text
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderDetail(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildDashedLine() {
    return Container(
      height: 1,
      child: CustomPaint(
        painter: DashedLinePainter(),
        size: Size.infinite,
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w500,
                  fontSize: 12),
            ),
          ),
          Text(
            value,
            style: TextStyle(
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w500,
                fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashSpace = 3.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
