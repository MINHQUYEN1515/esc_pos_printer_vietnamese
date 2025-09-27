import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

class Invoice extends StatefulWidget {
  final ReceiptData receiptData;
  final bool forPrint;

  const Invoice({Key? key, required this.receiptData, this.forPrint = false})
      : super(key: key);

  @override
  State<Invoice> createState() => _InvoiceState();
}

class _InvoiceState extends State<Invoice> {
  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(alignment: Alignment.center, child: _buildHeader()),
        Align(alignment: Alignment.center, child: _buildStoreInfo()),
        if (_shouldShowWifi()) _buildWifiInfo(),
        Align(alignment: Alignment.center, child: _buildOrderInfo()),
        _buildDateTimeInfo(),
        if (widget.receiptData.order.creator != null) _buildStaffInfo(),
        if (widget.receiptData.order.client != null) _buildCustomerInfo(),
        _buildDivider(),
        _buildProductHeader(),
        _buildProductList(),
        _buildDivider(),
        _buildTotals(),
        _buildPaymentInfo(),
        if (widget.receiptData.order.qrBank != null)
          Align(alignment: Alignment.center, child: _buildQRCode()),
        Align(alignment: Alignment.center, child: _buildFooter()),
      ],
    );

    return Container(
      width: double.infinity, // Use full available width (576px)
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: widget.forPrint
          ? Container(
              constraints: const BoxConstraints(minHeight: 0),
              child: content,
            )
          : SingleChildScrollView(
              child: Container(
                constraints: const BoxConstraints(minHeight: 0),
                child: content,
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.network(
            alignment: Alignment.center,
            width: 70,
            height: 70,
            color: Colors.black,
            "https://cdn-new.topcv.vn/unsafe/140x/https://static.topcv.vn/company_logos/0E6pkRSt8cpHLo4OXHPoWNpxIiPWAQN1_1751627313____057cf59a177e4cacee6bb8ad9319e08b.png"),
        // Header Section
        Text(
          widget.receiptData.isProvisional
              ? ' HÓA ĐƠN TẠM TÍNH'
              : 'HÓA ĐƠN THANH TOÁN',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        if (widget.receiptData.isReprint)
          const Text(
            '(In lại)',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }

  Widget _buildStoreInfo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Zami Solution FNB',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        if (widget.receiptData.order.branch?.address != null)
          Text(
            widget.receiptData.order.branch!.address!,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }

  Widget _buildWifiInfo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDivider(),
        const Text(
          'WIFI MIỄN PHÍ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          'Tên: ${widget.receiptData.wifiInfo!['name']!}',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
        Text(
          'Mật khẩu: ${widget.receiptData.wifiInfo!['password']!}',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
        _buildDivider(),
      ],
    );
  }

  Widget _buildOrderInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Mã đơn: ${widget.receiptData.order.code}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        if (widget.receiptData.order.table != null)
          Text(
            'Bàn: ${widget.receiptData.order.table!.name}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
        if (widget.receiptData.order.waitingCard != null)
          Text(
            'Thẻ: ${widget.receiptData.order.waitingCard}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
        _buildDivider(),
      ],
    );
  }

  Widget _buildDateTimeInfo() {
    final orderTimeGMT7 =
        widget.receiptData.order.createdAt.add(const Duration(hours: 7));
    final currentTimeGMT7 = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Thời gian tạo: ${DateFormat('dd/MM/yyyy HH:mm').format(orderTimeGMT7)}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        Text(
          'Thời gian in: ${DateFormat('dd/MM/yyyy HH:mm').format(currentTimeGMT7)}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildStaffInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Nhân viên: ${widget.receiptData.order.creator!.fullName}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Khách hàng: ${widget.receiptData.order.client!.name!}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        Text(
          'SDT: ${widget.receiptData.order.client!.phone}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        if (widget.receiptData.order.orderType == 'SHIPPING' &&
            widget.receiptData.order.shipping?.address != null)
          Text(
            'Địa chỉ: ${widget.receiptData.order.shipping!.address!}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
      ],
    );
  }

  Widget _buildProductHeader() {
    return Container(
      // padding: const EdgeInsets.symmetric(horizontal: 16),
      child: const Row(
        children: [
          Expanded(
            child: Text(
              'SL',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              textAlign: TextAlign.start,
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              'Sản phẩm',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Đơn giá',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Thành tiền',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    return Padding(
      padding: EdgeInsets.only(left: 5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: widget.receiptData.order.products
            .map((product) => _buildProductRow(product))
            .toList(),
      ),
    );
  }

  Widget _buildProductRow(ProductData product) {
    final productName = product.name;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main product row
        Container(
          // padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${product.quantity}',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.start,
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  productName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  _formatNumber(_calculateProductPrice(product)),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  _formatNumber(_calculateProductTotalPrice(product)),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),

        ...product.attributes
            .map((attr) => _buildAttributeRow(attr, product.quantity)),
        // Product note
        if (product.note != null && product.note!.isNotEmpty)
          _buildProductNote(product.note!),
        const SizedBox(
          height: 10,
        )
      ],
    );
  }

  Widget _buildAttributeRow(AttributeData attr, int quantity) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: const SizedBox(width: 50)),
          Expanded(
            flex: 4,
            child: Text(
              '+ ${attr.name}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _formatNumber(attr.price),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _formatNumber(attr.price * quantity),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductNote(String note) {
    return Container(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SizedBox(),
          ),
          Expanded(
            flex: 8,
            child: Text(
              '*Ghi chú: ${note}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotals() {
    return Padding(
      padding: EdgeInsets.only(left: 5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTotalRow('Thành tiền:', widget.receiptData.order.totalMoney),
          _buildDivider(),
          _buildTotalRow(
              'Tổng thanh toán:', widget.receiptData.order.totalMoneyPayment,
              bold: true, large: true),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount,
      {bool bold = false, bool large = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              fontSize: large ? 17 : 15,
            ),
          ),
          Text(
            '${_formatNumber(amount)} d',
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              fontSize: large ? 17 : 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfo() {
    return Padding(
      padding: const EdgeInsets.only(left: 5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildInfoRow('Phương thức thanh toán:',
              _getPaymentMethodName(widget.receiptData.order.paymentMethod)),
          _buildInfoRow('Trạng thái thanh toán:',
              _getPaymentStatusName(widget.receiptData.order.paymentStatus)),
          _buildInfoRow('Ghi chú:', widget.receiptData.order.note ?? ''),
        ],
      ),
    );
  }

  Widget _buildOrderNote() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _buildInfoRow('Ghi chú:', widget.receiptData.order.note!),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }

  Widget _buildQRCode() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        const Text(
          "Mã QR thanh toán",
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        Container(
            width: 120, // Increased size for better visibility
            height: 120,
            child: QrImageView(
              data: widget.receiptData.order.qrBank ?? "123",
            )),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Tra cứu hóa đơn điện tử tại',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
        const Text(
          'https://tracuuhddt.zamiapp.vn',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
        Text(
          'Mã tra cứu: ${widget.receiptData.order.code}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
        const Text(
          'Cảm ơn quý khách đã mua hàng!',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
        if (widget.receiptData.phone != null)
          Text(
            'Hotline: ${widget.receiptData.phone}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        const Text(
          'Powered by Zami Solution',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDivider() {
    int count = (MediaQuery.of(context).size.width / 3).floor();

    return Container(
        child: Row(
      children: List.generate(
        count,
        (index) => Expanded(
          child: Container(
            height: 1,
            width: 3,
            color: index % 2 == 0 ? Colors.black : Colors.transparent,
          ),
        ),
      ),
    ));
  }

  // Helper methods
  bool _shouldShowWifi() {
    return widget.receiptData.enableWifi &&
        widget.receiptData.wifiInfo != null &&
        widget.receiptData.wifiInfo!['name'] != null &&
        widget.receiptData.wifiInfo!['password'] != null;
  }

  String _formatNumber(double number) {
    return NumberFormat('#,###', 'vi_VN').format(number);
  }

  double _calculateProductPrice(ProductData product) {
    return product.price +
        product.attributes.fold(0.0, (sum, attr) => sum + attr.price);
  }

  double _calculateProductTotalPrice(ProductData product) {
    return _calculateProductPrice(product) * product.quantity;
  }

  String _getPaymentMethodName(String method) {
    const methods = {
      'CASH': 'Tien mat',
      'CARD': 'The',
      'TRANSFER': 'Chuyen khoan',
      'EWALLET': 'Vi dien tu',
    };
    return methods[method] ?? method;
  }

  String _getPaymentStatusName(String status) {
    const statuses = {
      'PAID': 'Da thanh toan',
      'PENDING': 'Chua thanh toan',
      'PARTIAL': 'Thanh toan mot phan',
    };
    return statuses[status] ?? status;
  }
}

// Data models
class ReceiptData {
  final bool isProvisional;
  final bool isReprint;
  final bool enableWifi;
  final Map<String, String>? wifiInfo;
  final OrderData order;
  final String? taxCode;
  final String? phone;

  ReceiptData({
    required this.isProvisional,
    required this.isReprint,
    required this.enableWifi,
    this.wifiInfo,
    required this.order,
    this.taxCode,
    this.phone,
  });
}

class OrderData {
  final String code;
  final BranchData? branch;
  final TableData? table;
  final String? waitingCard;
  final DateTime createdAt;
  final UserData? creator;
  final ClientData? client;
  final String orderType;
  final ShippingData? shipping;
  final List<ProductData> products;
  final double totalMoney;
  final double totalDiscount;
  final double? totalShipping;
  final double? tax;
  final double totalMoneyPayment;
  final String paymentMethod;
  final String paymentStatus;
  final String? note;
  final String? qrBank;

  OrderData({
    required this.code,
    this.branch,
    this.table,
    this.waitingCard,
    required this.createdAt,
    this.creator,
    this.client,
    required this.orderType,
    this.shipping,
    required this.products,
    required this.totalMoney,
    required this.totalDiscount,
    this.totalShipping,
    this.tax,
    required this.totalMoneyPayment,
    required this.paymentMethod,
    required this.paymentStatus,
    this.note,
    this.qrBank,
  });
}

class BranchData {
  final String name;
  final String? address;

  BranchData({required this.name, this.address});
}

class TableData {
  final String name;

  TableData({required this.name});
}

class UserData {
  final String fullName;

  UserData({required this.fullName});
}

class ClientData {
  final String? name;
  final String phone;

  ClientData({this.name, required this.phone});
}

class ShippingData {
  final String? address;

  ShippingData({this.address});
}

class ProductData {
  final String name;
  final int quantity;
  final double price;
  final List<AttributeData> attributes;
  final String? note;

  ProductData({
    required this.name,
    required this.quantity,
    required this.price,
    required this.attributes,
    this.note,
  });
}

class AttributeData {
  final String name;
  final double price;

  AttributeData({required this.name, required this.price});
}

// Example usage widget
class ReceiptExample extends StatelessWidget {
  final bool forPrint;

  const ReceiptExample({Key? key, this.forPrint = false}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final receipt = ReceiptData(
      isProvisional: false,
      isReprint: false,
      enableWifi: true,
      wifiInfo: {
        "name": "Zami_Free_Wifi",
        "password": "12345678",
      },
      taxCode: "0123456789",
      phone: "0937155085",
      order: OrderData(
        code: "DH-AOYX-4423",
        branch: BranchData(
          name: "Zami Solution FNB",
          address: "123 Lê Lợi, Quận 1, TP.HCM",
        ),
        table: TableData(
          name: "Bàn số 1",
        ),
        waitingCard: "WC-01",
        createdAt: DateTime.parse("2025-09-20 08:55:00"),
        creator: UserData(fullName: "Zami FnB"),
        client: ClientData(
          name: "Nguyễn Văn A",
          phone: "0912345678",
        ),
        orderType: "DINE_IN",
        shipping: ShippingData(
          address: "456 Nguyễn Huệ, Quận 1, TP.HCM",
        ),
        products: [
          ProductData(
            name: "Cà phê sữa đá size L",
            quantity: 1,
            price: 20000,
            attributes: [
              AttributeData(name: "Thêm sữa", price: 5000),
              AttributeData(name: "Ít đá", price: 0),
              AttributeData(name: "Không đường", price: 0),
            ],
            note: "Uống tại chỗ",
          ),
          ProductData(
            name: "Trà đào cam sả",
            quantity: 2,
            price: 45000,
            attributes: [
              AttributeData(name: "Thêm topping đào", price: 8000),
              AttributeData(name: "Ít ngọt", price: 0),
            ],
            note: "Để riêng đá",
          ),
          ProductData(
            name: "Bánh mì thịt nướng",
            quantity: 1,
            price: 30000,
            attributes: [
              AttributeData(name: "Thêm pate", price: 5000),
              AttributeData(name: "Không ớt", price: 0),
            ],
            note: "Mang về",
          ),
        ],
        totalMoney: 170000,
        totalDiscount: 10000,
        totalShipping: 15000,
        tax: 5000,
        totalMoneyPayment: 180000,
        paymentMethod: "CASH",
        paymentStatus: "PAID",
        note: "Hi tớ là Minh Quyền",
        qrBank: "DH-AOYX-4423",
      ),
    );

    return Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: Invoice(receiptData: receipt, forPrint: forPrint),
        ),
      ),
    );
  }
}
